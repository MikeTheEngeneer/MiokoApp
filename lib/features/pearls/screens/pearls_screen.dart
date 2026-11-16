import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/mioko_icons.dart';
import '../../profile/providers/profile_provider.dart';
import '../models/billing.dart';
import '../payment/cloudpayments_page.dart';

enum BillingTab { plans, packs }

class PearlsScreen extends ConsumerStatefulWidget {
  const PearlsScreen({super.key, this.initialTab = BillingTab.plans});
  final BillingTab initialTab;

  @override
  ConsumerState<PearlsScreen> createState() => _PearlsScreenState();
}

class _PearlsScreenState extends ConsumerState<PearlsScreen> {
  late BillingTab _tab = widget.initialTab;
  // Как на сайте: по умолчанию выбран месяц Wave и самый маленький пакет
  String _planId = '1m';
  String _packId = '200';

  bool _paying = false;

  Future<void> _pay(BillingOption option) async {
    final config = ref.read(billingConfigProvider).valueOrNull;
    final user = ref.read(profileProvider).valueOrNull;
    final messenger = ScaffoldMessenger.of(context);
    if (config?.publicId == null || user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Оплата сейчас недоступна, обнови экран')),
      );
      return;
    }
    final isWave = _tab == BillingTab.plans;
    final before = ref.read(paymentProvider).valueOrNull;

    setState(() => _paying = true);
    final result = await openCloudPayments(
      context,
      kind: isWave ? PaymentKind.wave : PaymentKind.pearls,
      option: option,
      publicId: config!.publicId!,
      accountId: user.id,
      email: user.email,
    );
    if (!mounted) return;

    switch (result) {
      case PaymentSuccess():
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              isWave
                  ? 'Оплата прошла — Mioko Wave скоро активируется'
                  : 'Оплата прошла — жемчужины скоро придут',
            ),
          ),
        );
        await _waitForCredit(before);
      case PaymentFailed(:final message):
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Оплата не прошла${message != null ? ': $message' : ''}',
            ),
          ),
        );
      case null:
        break; // закрыл окно оплаты
    }
    if (mounted) setState(() => _paying = false);
  }

  // Mioko начисляет покупку по уведомлению от CloudPayments — это может занять несколько секунд
  Future<void> _waitForCredit(PaymentInfo? before) async {
    for (var i = 0; i < 6 && mounted; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      ref.invalidate(paymentProvider);
      final now = await ref
          .read(paymentProvider.future)
          .catchError((_) => before!);
      if (before == null ||
          now.pearls != before.pearls ||
          now.waveUntil != before.waveUntil) {
        return;
      }
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(paymentProvider);
    ref.invalidate(billingConfigProvider);
    await ref.read(paymentProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final payment = ref.watch(paymentProvider);
    final config = ref.watch(billingConfigProvider);
    final top = MediaQuery.paddingOf(context).top;

    final options = config.valueOrNull == null
        ? const <BillingOption>[]
        : (_tab == BillingTab.plans
              ? config.value!.plans
              : config.value!.packs);
    final selectedId = _tab == BillingTab.plans ? _planId : _packId;
    final selected =
        options.where((o) => o.id == selectedId).firstOrNull ??
        options.firstOrNull;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        edgeOffset: top,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(4, top + 4, 16, 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Тарифы и жемчужины',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _StatusCard(payment: payment.valueOrNull),
                  const SizedBox(height: 16),
                  _TabSwitch(
                    tab: _tab,
                    onChanged: (t) {
                      HapticFeedback.selectionClick();
                      setState(() => _tab = t);
                    },
                  ),
                  const SizedBox(height: 20),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: KeyedSubtree(
                      key: ValueKey(_tab),
                      child: _TabIntro(tab: _tab),
                    ),
                  ),
                  const SizedBox(height: 16),
                  config.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => ErrorView(
                      error: e,
                      compact: true,
                      onRetry: () => ref.invalidate(billingConfigProvider),
                    ),
                    data: (_) => Column(
                      children: [
                        for (final o in options)
                          _OptionTile(
                            option: o,
                            selected: o.id == selected?.id,
                            isPack: _tab == BillingTab.packs,
                            popular: _tab == BillingTab.plans && o.id == '7d',
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(
                                () => _tab == BillingTab.plans
                                    ? _planId = o.id
                                    : _packId = o.id,
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: selected == null
          ? null
          : _BuyBar(
              text: _tab == BillingTab.plans
                  ? 'Приобрести M.Wave за ${formatRub(selected.amount)}'
                  : 'Купить жемчужины за ${formatRub(selected.amount)}',
              busy: _paying,
              onPressed: () => _pay(selected),
            ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.payment});
  final PaymentInfo? payment;

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 12);
    final hasWave = payment?.hasWave ?? false;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Текущий доступ', style: muted),
                    const SizedBox(height: 4),
                    Text(
                      hasWave ? 'Mioko Wave' : 'Mioko Tide',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: scheme.primary),
                      ),
                      child: Text(
                        hasWave
                            ? 'до ${_date(payment!.waveUntil!)}'
                            : 'Бесплатный',
                        style: TextStyle(color: scheme.primary, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            VerticalDivider(width: 1, color: scheme.outlineVariant),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const PearlIcon(size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Баланс жемчужин', style: muted),
                          const SizedBox(height: 2),
                          Text(
                            payment == null ? '—' : '${payment!.pearls}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabSwitch extends StatelessWidget {
  const _TabSwitch({required this.tab, required this.onChanged});
  final BillingTab tab;
  final ValueChanged<BillingTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget item(BillingTab t, String label) {
      final active = t == tab;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? scheme.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: active
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          item(BillingTab.plans, 'Тарифы'),
          item(BillingTab.packs, 'Жемчужины'),
        ],
      ),
    );
  }
}

class _TabIntro extends StatelessWidget {
  const _TabIntro({required this.tab});
  final BillingTab tab;

  static const _waveFeatures = [
    (Icons.all_inclusive, 'Общайся без лимита сообщений'),
    (
      Icons.auto_fix_high_outlined,
      'Создавай персонажей и истории без ограничений',
    ),
    (Icons.psychology_outlined, 'Память хранит важное даже спустя месяцы'),
    (Icons.theater_comedy_outlined, 'Делай Roleplay живее и атмосфернее'),
  ];

  static const _pearlFeatures = [
    (Icons.add_photo_alternate_outlined, 'Создавай яркие аватары и обложки'),
    (Icons.auto_fix_high_outlined, 'Создавай персонажей и истории вместе с AI'),
    (Icons.graphic_eq, 'Оживляй сообщения голосом'),
    (Icons.theater_comedy_outlined, 'Открывай новые способы оживлять Roleplay'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isPlans = tab == BillingTab.plans;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            isPlans ? const WaveLogo(size: 52) : const PearlShell(size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPlans ? 'Открой Mioko Wave' : 'Пакеты жемчужин',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    isPlans ? 'Поймай свою волну' : 'Жемчужины открывают генерации, озвучку и другие премиум-функции',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (final (icon, text) in isPlans ? _waveFeatures : _pearlFeatures)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Icon(icon, size: 20, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(text, style: const TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.selected,
    required this.isPack,
    required this.popular,
    required this.onTap,
  });

  final BillingOption option;
  final bool selected;
  final bool isPack;
  final bool popular;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? scheme.primary : scheme.outline,
                      width: selected ? 6 : 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                if (isPack) ...[
                  const PearlIcon(size: 22),
                  const SizedBox(width: 10),
                ],
                // Expanded забирает всё свободное место — цена всегда у правого края
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          isPack ? option.label : option.shortLabel,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (popular) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: scheme.primary),
                          ),
                          child: Text(
                            'Популярно',
                            style: TextStyle(
                              color: scheme.primary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  formatRub(option.amount),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BuyBar extends StatelessWidget {
  const _BuyBar({
    required this.text,
    required this.busy,
    required this.onPressed,
  });
  final String text;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: busy ? null : onPressed,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: busy
                        ? const SizedBox(
                            key: ValueKey('busy'),
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Text(text, key: ValueKey(text)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Разовый платёж без автопродления. Оплата через CloudPayments — платёжный сервис Mioko',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
