import 'dart:convert';
import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/billing.dart';

enum PaymentKind { wave, pearls }

sealed class PaymentResult {
  const PaymentResult();
}

class PaymentSuccess extends PaymentResult {
  const PaymentSuccess();
}

class PaymentFailed extends PaymentResult {
  final String? message;
  const PaymentFailed(this.message);
}

// Номер заказа как на сайте: W-/P- + 9 символов Crockford Base32 + контрольный символ (mod 37).
// Сервер Mioko, судя по коду сайта, проверяет контрольный символ.
const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
const _checkAlphabet = '$_alphabet*~\$=';

String _checkSymbol(String body) {
  var t = 0;
  for (final ch in body.split('')) {
    t = (32 * t + _alphabet.indexOf(ch)) % 37;
  }
  return _checkAlphabet[t];
}

String newOrderNumber(PaymentKind kind) {
  final prefix = kind == PaymentKind.wave ? 'W' : 'P';
  final rnd = Random.secure();
  // Как и сайт, перебираем, пока контрольный символ не попадёт в основной алфавит
  while (true) {
    final body = List.generate(
      9,
      (_) => _alphabet[rnd.nextInt(_alphabet.length)],
    ).join();
    final check = _checkSymbol(body);
    if (_alphabet.contains(check)) return '$prefix-$body$check';
  }
}

Future<PaymentResult?> openCloudPayments(
  BuildContext context, {
  required PaymentKind kind,
  required BillingOption option,
  required String publicId,
  required String accountId,
  String? email,
}) {
  final order = newOrderNumber(kind);
  final mail = (email ?? '').trim();
  final receipt = {
    'Items': [
      {
        'label': option.label,
        'price': option.amount,
        'quantity': 1,
        'amount': option.amount,
        'vat': null,
        'method': 4,
        'object': 4,
      },
    ],
    'email': mail,
    'amounts': {'electronic': option.amount},
  };
  // Ровно те же параметры, что передаёт сайт в cp.CloudPayments().pay("charge", …)
  final params = {
    'publicId': publicId,
    'description': option.label,
    'amount': option.amount,
    'currency': 'RUB',
    'invoiceId': order,
    'accountId': accountId,
    if (mail.isNotEmpty) 'email': mail,
    'data': {
      'kind': kind == PaymentKind.wave ? 'wave' : 'pearls',
      'itemId': option.id,
      'orderNumber': order,
      'cloudPayments': {'CustomerReceipt': receipt},
    },
    'skin': 'mini',
  };

  return Navigator.of(context).push<PaymentResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _CloudPaymentsPage(params: params),
    ),
  );
}

class _CloudPaymentsPage extends StatefulWidget {
  const _CloudPaymentsPage({required this.params});
  final Map<String, Object?> params;

  @override
  State<_CloudPaymentsPage> createState() => _CloudPaymentsPageState();
}

class _CloudPaymentsPageState extends State<_CloudPaymentsPage> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel('MiokoPay', onMessageReceived: _onMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: _onNavigation,
        ),
      )
      // baseUrl — страница тарифов сайта: виджет видит тот же адрес, что и при оплате на mioko.ai
      ..loadHtmlString(
        _html(widget.params),
        baseUrl: 'https://mioko.ai/mioko-pearls',
      );
  }

  // СБП, T-Pay и deep link'и банков должны открываться в приложении банка, а не в WebView
  Future<NavigationDecision> _onNavigation(NavigationRequest request) async {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    final isWeb = uri.scheme == 'http' || uri.scheme == 'https';
    final isBankLink =
        uri.host == 'qr.nspk.ru' || uri.host.endsWith('.nspk.ru');
    if (isWeb && !isBankLink) return NavigationDecision.navigate;

    var target = uri;
    // intent://… — Android-ссылка на приложение; берём запасной https-адрес, если он есть
    if (uri.scheme == 'intent') {
      final fallback = RegExp(r'S\.browser_fallback_url=([^;]+)')
          .firstMatch(request.url);
      if (fallback != null) {
        target = Uri.parse(Uri.decodeComponent(fallback.group(1)!));
      }
    }
    final ok = await launchUrl(target, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть приложение банка')),
      );
    }
    return NavigationDecision.prevent;
  }

  void _onMessage(JavaScriptMessage message) {
    if (_done || !mounted) return;
    final msg = jsonDecode(message.message) as Map<String, dynamic>;
    final PaymentResult? result = switch (msg['t']) {
      'success' => const PaymentSuccess(),
      'fail' => PaymentFailed(msg['m'] as String?),
      'error' => PaymentFailed(
        msg['m'] as String? ?? 'Виджет оплаты не загрузился',
      ),
      _ => null, // 'hide' — пользователь закрыл виджет
    };
    _done = true;
    Navigator.of(context).pop(result);
  }

  static String _html(Map<String, Object?> params) {
    // "</" внутри JSON закрыл бы тег <script>
    final json = jsonEncode(params).replaceAll('</', '<\\/');
    return '''
<!doctype html>
<html><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
<style>html,body{margin:0;height:100%;background:transparent}</style>
<script src="https://widget.cloudpayments.ru/bundles/cloudpayments.js"></script>
</head><body>
<script>
function send(m){ MiokoPay.postMessage(JSON.stringify(m)); }
window.addEventListener('load', function () {
  try {
    if (!window.cp || !cp.CloudPayments) { send({t:'error', m:'Скрипт оплаты не загрузился'}); return; }
    var w = new cp.CloudPayments();
    w.pay('charge', $json, {
      onSuccess: function () { send({t:'success'}); },
      onFail: function (r) { send({t:'fail', m: r ? String(r) : null}); },
      onComplete: function () {}
    });
    var hide = w.onHide;
    w.onHide = function () { send({t:'hide'}); if (hide) hide.apply(w, arguments); };
  } catch (e) { send({t:'error', m: String(e)}); }
});
</script>
</body></html>''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Оплата'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
