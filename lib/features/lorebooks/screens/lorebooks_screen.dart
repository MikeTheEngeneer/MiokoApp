import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_error.dart';
import '../../../shared/widgets/error_view.dart';
import '../models/lorebook.dart';
import '../providers/lorebooks_provider.dart';
import '../widgets/lorebook_tile.dart';

// «Настройки → Лорбуки»: лорбуки для всех чатов, свои и поиск опубликованных
class LorebooksScreen extends ConsumerStatefulWidget {
  const LorebooksScreen({super.key});

  @override
  ConsumerState<LorebooksScreen> createState() => _LorebooksScreenState();
}

class _LorebooksScreenState extends ConsumerState<LorebooksScreen> {
  // Лорбук, который сейчас подключается/отключается
  String? _busy;

  Future<void> _toggle(LorebookSummary lb, bool connect) async {
    setState(() => _busy = lb.publicId);
    try {
      await ref
          .read(lorebookActionsProvider)
          .setConnected(
            place: allChatsPlace,
            lorebookId: lb.publicId,
            connect: connect,
          );
      // Ждём новый список, чтобы кнопка не «прыгала» назад
      await ref.read(lorebookPlaceProvider(allChatsPlace).future);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(
              e,
              connect ? 'Не удалось подключить' : 'Не удалось отключить',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final placeAsync = ref.watch(lorebookPlaceProvider(allChatsPlace));
    final mineAsync = ref.watch(myLorebooksProvider);
    final place = placeAsync.valueOrNull;

    void open(LorebookSummary lb) => context.push('/lorebook/${lb.publicId}');

    Widget toggleFor(LorebookSummary lb) {
      final on = place?.has(lb.publicId) ?? false;
      return ConnectButton(
        connected: on,
        busy: _busy == lb.publicId,
        onPressed: place == null || (!on && place.isFull)
            ? null
            : () => _toggle(lb, !on),
      );
    }

    final hint = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      height: 1.4,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Лорбуки')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(lorebookPlaceProvider(allChatsPlace));
          ref.invalidate(myLorebooksProvider);
          await ref.read(lorebookPlaceProvider(allChatsPlace).future);
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Text(
              'Лорбуки для всех чатов: персонаж узнает о месте или герое из '
              'лорбука в любом твоём чате — с каким угодно персонажем и '
              'историей. Автор карточки их не видит.',
              style: hint,
            ),

            _Section(
              title: 'Для всех чатов',
              counter: place == null
                  ? null
                  : '${place.lorebooks.length} из ${place.limit}',
            ),
            placeAsync.when(
              skipLoadingOnRefresh: true,
              loading: () => const _Loading(),
              error: (e, _) => ErrorView(
                error: e,
                compact: true,
                onRetry: () =>
                    ref.invalidate(lorebookPlaceProvider(allChatsPlace)),
              ),
              data: (p) => p.lorebooks.isEmpty
                  ? Text(
                      'Пока ничего не подключено — выбери лорбук ниже',
                      style: hint,
                    )
                  : Column(
                      children: [
                        for (final lb in p.lorebooks)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: LorebookTile(
                              lorebook: lb,
                              onTap: () => open(lb),
                              trailing: toggleFor(lb),
                            ),
                          ),
                      ],
                    ),
            ),

            _Section(
              title: 'Мои лорбуки',
              counter: switch (mineAsync.valueOrNull) {
                final m? => '${m.lorebooks.length} из ${m.limit}',
                null => null,
              },
            ),
            mineAsync.when(
              skipLoadingOnRefresh: true,
              loading: () => const _Loading(),
              error: (e, _) => ErrorView(
                error: e,
                compact: true,
                onRetry: () => ref.invalidate(myLorebooksProvider),
              ),
              data: (m) {
                // Подключённые уже показаны выше
                final rest = m.lorebooks
                    .where((lb) => !(place?.has(lb.publicId) ?? false))
                    .toList();
                if (m.lorebooks.isEmpty) {
                  return Text(
                    'У тебя пока нет лорбуков. Создать лорбук пока можно '
                    'только на сайте mioko.ai',
                    style: hint,
                  );
                }
                return Column(
                  children: [
                    for (final lb in rest)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: LorebookTile(
                          lorebook: lb,
                          showAuthor: false,
                          onTap: () => open(lb),
                          trailing: toggleFor(lb),
                        ),
                      ),
                  ],
                );
              },
            ),

            const _Section(title: 'Опубликованные'),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Лорбуки других авторов — подключаются как есть, править их нельзя',
                style: hint,
              ),
            ),
            PublicLorebookSearch(
              onOpen: open,
              trailingBuilder: toggleFor,
              exclude: {
                ...?place?.lorebooks.map((e) => e.publicId),
                ...?mineAsync.valueOrNull?.lorebooks.map((e) => e.publicId),
              },
            ),

            const SizedBox(height: 20),
            Text(
              'К персоне лорбук подключают в «Настройки → Персоны» '
              'или кнопкой «Подключить» на странице лорбука.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, this.counter});

  final String title;
  final String? counter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (counter != null)
            Text(
              counter!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(16),
    child: Center(child: CircularProgressIndicator()),
  );
}
