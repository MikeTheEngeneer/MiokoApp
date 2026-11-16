import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_error.dart';
import '../../../shared/widgets/error_view.dart';
import '../models/lorebook.dart';
import '../providers/lorebooks_provider.dart';
import 'lorebook_tile.dart';

// Строка в карточке персоны: «Лорбук: …» или «Подключить лорбук»
class PersonaLorebookRow extends ConsumerWidget {
  const PersonaLorebookRow({super.key, required this.personaId});
  final String personaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final place = ref.watch(lorebookPlaceProvider(personaPlace(personaId)));
    final current = place.valueOrNull?.lorebooks.firstOrNull;

    final text = switch (place) {
      AsyncData() when current != null => current.title,
      AsyncData() => 'Подключить лорбук',
      AsyncError() => 'Лорбук не загрузился',
      _ => 'Лорбук…',
    };

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => showPersonaLorebookSheet(context, personaId),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              current != null ? Icons.menu_book_rounded : Icons.add_rounded,
              size: 18,
              color: scheme.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: current != null ? scheme.onSurface : scheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showPersonaLorebookSheet(BuildContext context, String personaId) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, controller) =>
            _PersonaLorebookSheet(personaId: personaId, controller: controller),
      ),
    );

class _PersonaLorebookSheet extends ConsumerStatefulWidget {
  const _PersonaLorebookSheet({
    required this.personaId,
    required this.controller,
  });

  final String personaId;
  final ScrollController controller;

  @override
  ConsumerState<_PersonaLorebookSheet> createState() =>
      _PersonaLorebookSheetState();
}

class _PersonaLorebookSheetState extends ConsumerState<_PersonaLorebookSheet> {
  String? _busy;

  LorePlace get _place => personaPlace(widget.personaId);

  Future<void> _set(LorebookSummary lb, bool connect) async {
    setState(() => _busy = lb.publicId);
    try {
      await ref
          .read(lorebookActionsProvider)
          .setConnected(
            place: _place,
            lorebookId: lb.publicId,
            connect: connect,
          );
      await ref.read(lorebookPlaceProvider(_place).future);
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

  void _open(LorebookSummary lb) {
    Navigator.of(context).pop();
    context.push('/lorebook/${lb.publicId}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final placeAsync = ref.watch(lorebookPlaceProvider(_place));
    final mine = ref.watch(myLorebooksProvider).valueOrNull;
    final current = placeAsync.valueOrNull?.lorebooks.firstOrNull;

    Widget pick(LorebookSummary lb) => ConnectButton(
      connected: false,
      label: current == null ? 'Выбрать' : 'Заменить',
      busy: _busy == lb.publicId,
      onPressed: _busy != null || placeAsync.valueOrNull == null
          ? null
          : () => _set(lb, true),
    );

    final header = theme.textTheme.labelLarge?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    return ListView(
      controller: widget.controller,
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Text(
          'Лорбук персоны',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Работает во всех твоих чатах с этой персоной — история и мир твоего '
          'героя. Один на персону — новый заменит прежний.',
          style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
        ),
        const SizedBox(height: 16),

        placeAsync.when(
          skipLoadingOnRefresh: true,
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => ErrorView(
            error: e,
            compact: true,
            onRetry: () => ref.invalidate(lorebookPlaceProvider(_place)),
          ),
          data: (_) => current == null
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Подключён', style: header),
                    const SizedBox(height: 8),
                    LorebookTile(
                      lorebook: current,
                      onTap: () => _open(current),
                      trailing: ConnectButton(
                        connected: true,
                        connectedLabel: 'Отключить',
                        busy: _busy == current.publicId,
                        onPressed: _busy != null
                            ? null
                            : () => _set(current, false),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
        ),

        if (mine != null &&
            mine.lorebooks.any((l) => l.publicId != current?.publicId)) ...[
          Text('Мои лорбуки', style: header),
          const SizedBox(height: 8),
          for (final lb in mine.lorebooks)
            if (lb.publicId != current?.publicId)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: LorebookTile(
                  lorebook: lb,
                  showAuthor: false,
                  onTap: () => _open(lb),
                  trailing: pick(lb),
                ),
              ),
          const SizedBox(height: 12),
        ],

        Text('Опубликованные', style: header),
        const SizedBox(height: 8),
        PublicLorebookSearch(
          onOpen: _open,
          trailingBuilder: pick,
          exclude: {
            ?current?.publicId,
            ...?mine?.lorebooks.map((e) => e.publicId),
          },
        ),
      ],
    );
  }
}
