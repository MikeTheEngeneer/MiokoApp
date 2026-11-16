import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class Links {
  static const telegram = 'https://t.me/mioko_ai';
  static const vk = 'https://vk.ru/mioko_ai';
  static const developerGithub = 'https://github.com/MikeTheEngeneer';
  static const privacy = 'https://mioko.ai/privacy';
  static const terms = 'https://mioko.ai/terms';
  static const rules = 'https://mioko.ai/rules';
}

Future<void> openUrl(BuildContext context, String url) async {
  final ok = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Не удалось открыть ссылку')));
  }
}
