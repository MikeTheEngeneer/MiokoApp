import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../shared/widgets/error_view.dart';
import '../models/persona.dart';
import '../providers/personas_provider.dart';

class PersonasScreen extends ConsumerStatefulWidget {
  const PersonasScreen({super.key});

  @override
  ConsumerState<PersonasScreen> createState() => _PersonasScreenState();
}

class _PersonasScreenState extends ConsumerState<PersonasScreen> {
  // Dismissible must leave the tree immediately, before the refetch returns
  final _removed = <String>{};

  @override
  Widget build(BuildContext context) {
    final personasAsync = ref
        .watch(personasProvider)
        .whenData(
          (d) => PersonasData(
            personas: d.personas
                .where((p) => !_removed.contains(p.publicId))
                .toList(),
            limit: d.limit,
          ),
        );
    final scheme = Theme.of(context).colorScheme;
    final data = personasAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Персоны'),
        actions: [
          if (data != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${data.personas.length} / ${data.limit}',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: data == null || data.isFull
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/personas/new'),
              icon: const Icon(Icons.add),
              label: const Text('Новая персона'),
            ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: personasAsync.when(
          loading: () => const Center(
            key: ValueKey('loading'),
            child: CircularProgressIndicator(),
          ),
          error: (e, _) => ErrorView(
            key: const ValueKey('error'),
            error: e,
            onRetry: () => ref.invalidate(personasProvider),
          ),
          data: (data) => RefreshIndicator(
            key: const ValueKey('data'),
            onRefresh: () => ref.refresh(personasProvider.future),
            child: data.personas.isEmpty
                ? ListView(
                    children: const [SizedBox(height: 120), _EmptyState()],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: data.personas.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final persona = data.personas[i];
                      return Dismissible(
                        key: ValueKey(persona.publicId),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) =>
                            _confirmDelete(context, ref, persona),
                        onDismissed: (_) {
                          setState(() => _removed.add(persona.publicId));
                          ref.invalidate(personasProvider);
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.delete_outline,
                            color: scheme.onErrorContainer,
                          ),
                        ),
                        child: _PersonaCard(persona: persona),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

Future<bool> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  Persona persona,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Удалить персону?'),
      content: Text(
        '«${persona.name}» будет удалена без возможности восстановления.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
            foregroundColor: Theme.of(ctx).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Удалить'),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;

  try {
    await ref
        .read(apiClientProvider)
        .delete('/api/personas/${persona.publicId}');
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось удалить персону')),
      );
    }
    return false;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Icon(Icons.face_retouching_natural, size: 56, color: scheme.primary),
          const SizedBox(height: 16),
          const Text(
            'Пока нет персон',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Персона — это то, кем ты представляешься персонажам в чате',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _PersonaCard extends StatelessWidget {
  const _PersonaCard({required this.persona});
  final Persona persona;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = persona.name.isNotEmpty ? persona.name[0] : '?';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: persona.isDefault
            ? Border.all(color: scheme.primary.withValues(alpha: 0.6))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: scheme.surfaceContainerHighest,
            backgroundImage: persona.avatarUrl != null
                ? NetworkImage(persona.avatarUrl!)
                : null,
            child: persona.avatarUrl == null
                ? Text(initial, style: const TextStyle(fontSize: 20))
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        persona.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (persona.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'По умолчанию',
                          style: TextStyle(color: scheme.primary, fontSize: 11),
                        ),
                      ),
                    ],
                  ],
                ),
                if (persona.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    persona.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
