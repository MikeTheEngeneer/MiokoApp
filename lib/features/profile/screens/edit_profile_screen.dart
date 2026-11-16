import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/image_upload.dart';
import '../../../core/api/api_error.dart';
import '../../../shared/widgets/error_view.dart';
import '../providers/profile_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _bioCtrl;

  File? _pickedImage;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(profileProvider).valueOrNull;
    _nameCtrl = TextEditingController(text: user?.displayName ?? '');
    _usernameCtrl = TextEditingController(text: user?.username ?? '');
    _bioCtrl = TextEditingController(text: user?.bio ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context); // закрываем bottom sheet выбора
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 800,
    );
    if (xfile != null) {
      setState(() => _pickedImage = File(xfile.path));
    }
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Галерея'),
                onTap: () => _pickImage(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Камера'),
                onTap: () => _pickImage(ImageSource.camera),
              ),
              if (_pickedImage != null ||
                  ref.read(profileProvider).valueOrNull?.avatarUrl != null)
                ListTile(
                  iconColor: Theme.of(context).colorScheme.error,
                  textColor: Theme.of(context).colorScheme.error,
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Удалить фото'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _pickedImage = null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final dio = ref.read(apiClientProvider);

      // Если выбрано новое фото — конвертируем в base64 и загружаем
      String? avatarUrl = ref.read(profileProvider).valueOrNull?.avatarUrl;
      if (_pickedImage != null) {
        avatarUrl = await uploadImage(dio, _pickedImage!);
      }

      await dio.put(
        '/api/auth/me',
        data: {
          'display_name': _nameCtrl.text.trim(),
          'username': _usernameCtrl.text.trim(),
          'bio': _bioCtrl.text.trim(),
          'avatar_url': avatarUrl,
        },
      );

      ref.invalidate(profileProvider);

      if (!mounted) return;
      context.pop();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = apiErrorMessage(e, 'Не удалось сохранить. Проверьте данные.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final top = MediaQuery.of(context).padding.top;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            ErrorView(error: e, onRetry: () => ref.invalidate(profileProvider)),
        data: (user) => Form(
          key: _formKey,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(4, top + 4, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => context.pop(),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Редактировать профиль',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      _saving
                          ? const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : TextButton(
                              onPressed: _save,
                              child: const Text(
                                'Сохранить',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Аватар ───────────────────────────────
                    Center(
                      child: GestureDetector(
                        onTap: _showImagePicker,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundColor: scheme.surfaceContainerHighest,
                              child: ClipOval(
                                child: SizedBox(
                                  width: 96,
                                  height: 96,
                                  child: _pickedImage != null
                                      // Новое выбранное фото
                                      ? Image.file(
                                          _pickedImage!,
                                          fit: BoxFit.cover,
                                        )
                                      : user.avatarUrl != null
                                      // Текущее фото с сервера
                                      ? Image.network(
                                          user.avatarUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              _AvatarPlaceholder(
                                                user.displayName,
                                              ),
                                        )
                                      : _AvatarPlaceholder(user.displayName),
                                ),
                              ),
                            ),
                            // Иконка камеры
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: scheme.surface,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                size: 14,
                                color: scheme.onPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_pickedImage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Center(
                          child: Text(
                            'Фото выбрано — сохрани для применения',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 28),

                    // ── Ошибка ───────────────────────────────
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: scheme.onErrorContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // ── Поля ─────────────────────────────────
                    _Field(
                      label: 'Имя',
                      controller: _nameCtrl,
                      validator: (v) =>
                          (v?.trim().isEmpty ?? true) ? 'Введите имя' : null,
                    ),
                    const SizedBox(height: 14),
                    _Field(
                      label: 'Имя пользователя',
                      controller: _usernameCtrl,
                      prefix: '@',
                      validator: (v) => (v?.trim().isEmpty ?? true)
                          ? 'Введите username'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    _Field(label: 'О себе', controller: _bioCtrl, maxLines: 3),
                    const SizedBox(height: 14),
                    _Field(
                      label: 'Email',
                      initialValue: user.email,
                      enabled: false,
                    ),

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Сохранить',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder(this.name);
  final String name;

  @override
  Widget build(BuildContext context) => Container(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    alignment: Alignment.center,
    child: Text(
      name.isNotEmpty ? name[0] : '?',
      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    this.controller,
    this.initialValue,
    this.maxLines = 1,
    this.enabled = true,
    this.prefix,
    this.validator,
  });

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final int maxLines;
  final bool enabled;
  final String? prefix;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      enabled: enabled,
      maxLines: maxLines,
      validator: validator,
      // Рамки и заливка берутся из inputDecorationTheme
      decoration: InputDecoration(labelText: label, prefixText: prefix),
    );
  }
}
