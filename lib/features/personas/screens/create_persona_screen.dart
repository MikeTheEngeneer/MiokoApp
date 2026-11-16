import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../../../core/api/image_upload.dart';
import '../providers/personas_provider.dart';

class CreatePersonaScreen extends ConsumerStatefulWidget {
  const CreatePersonaScreen({super.key});

  @override
  ConsumerState<CreatePersonaScreen> createState() =>
      _CreatePersonaScreenState();
}

class _CreatePersonaScreenState extends ConsumerState<CreatePersonaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  File? _image;
  bool _isDefault = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context);
    final xfile = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 800,
    );
    if (xfile != null) setState(() => _image = File(xfile.path));
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
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
            if (_image != null)
              ListTile(
                iconColor: Theme.of(context).colorScheme.error,
                textColor: Theme.of(context).colorScheme.error,
                leading: const Icon(Icons.delete_outline),
                title: const Text('Убрать фото'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _image = null);
                },
              ),
            const SizedBox(height: 8),
          ],
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
      final avatarUrl = _image != null ? await uploadImage(dio, _image!) : null;

      await dio.post(
        '/api/personas',
        data: {
          'name': _nameCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'avatar_url': avatarUrl,
          'is_default': _isDefault,
        },
      );

      ref.invalidate(personasProvider);
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = apiErrorMessage(e, 'Не удалось создать персону');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = _nameCtrl.text.isNotEmpty ? _nameCtrl.text[0] : '?';

    return Scaffold(
      appBar: AppBar(title: const Text('Новая персона')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: GestureDetector(
                onTap: _showImagePicker,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: scheme.surfaceContainerHighest,
                      backgroundImage: _image != null
                          ? FileImage(_image!)
                          : null,
                      child: _image == null
                          ? Text(initial, style: const TextStyle(fontSize: 32))
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surface, width: 2),
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
            const SizedBox(height: 28),

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

            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Имя'),
              onChanged: (_) => setState(() {}),
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'Введите имя' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descCtrl,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Описание',
                hintText: 'Внешность, характер, предыстория…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Использовать по умолчанию'),
              subtitle: const Text('Будет выбрана в новых чатах'),
              value: _isDefault,
              onChanged: (v) => setState(() => _isDefault = v),
            ),
            const SizedBox(height: 20),
            FilledButton(
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
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Создать',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
