import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';

/// Edit name, username, bio, avatar URL, and timezone.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _bio = TextEditingController();
  final _avatar = TextEditingController();
  String? _timezone;
  bool _saving = false;

  static const _timezones = <String>[
    'UTC',
    'America/New_York',
    'America/Chicago',
    'America/Denver',
    'America/Los_Angeles',
    'America/Sao_Paulo',
    'Europe/London',
    'Europe/Paris',
    'Europe/Berlin',
    'Europe/Madrid',
    'Africa/Lagos',
    'Africa/Nairobi',
    'Asia/Dubai',
    'Asia/Karachi',
    'Asia/Kolkata',
    'Asia/Dhaka',
    'Asia/Shanghai',
    'Asia/Tokyo',
    'Australia/Sydney',
    'Pacific/Auckland',
  ];

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    _avatar.dispose();
    super.dispose();
  }

  void _seed(User user) {
    if (_name.text.isEmpty) {
      _name.text = user.name;
      _username.text = user.username;
      _bio.text = user.bio ?? '';
      _avatar.text = user.avatarUrl ?? '';
      _timezone ??= _timezones.contains(user.timezone) ? user.timezone : 'UTC';
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.updateProfile({
        'name': _name.text.trim(),
        'username': _username.text.trim(),
        if (_bio.text.trim().isNotEmpty) 'bio': _bio.text.trim(),
        if (_avatar.text.trim().isNotEmpty) 'avatarUrl': _avatar.text.trim(),
        'timezone': _timezone,
      });
      // Refresh the cached user.
      ref.invalidate(authControllerProvider);
      if (mounted) {
        toast(context, 'Profile updated');
        context.pop();
      }
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (_) {
      if (mounted) toast(context, 'Could not save. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncUser = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Edit profile'),
      ),
      body: asyncUser.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => OEmptyState(
          icon: Icons.error_outline,
          title: 'Could not load profile',
          subtitle: e.toString(),
        ),
        data: (user) {
          if (user == null) {
            return const OEmptyState(icon: Icons.person_off_outlined, title: 'Not signed in');
          }
          _seed(user);
          return _form(context, user);
        },
      ),
    );
  }

  Widget _form(BuildContext context, User user) {
    final cs = Theme.of(context).colorScheme;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            OrdoSpacing.lg, OrdoSpacing.lg, OrdoSpacing.lg, OrdoSpacing.xxl),
        children: [
          Center(
            child: Stack(
              children: [
                OAvatar(name: user.name, imageUrl: user.avatarUrl, radius: 48),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.edit, size: 14, color: cs.onPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: OrdoSpacing.xl),

          OField(
            label: 'Name',
            child: TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
              decoration: const InputDecoration(hintText: 'Your name'),
            ),
          ),
          const SizedBox(height: OrdoSpacing.md),

          OField(
            label: 'Username',
            child: TextFormField(
              controller: _username,
              textInputAction: TextInputAction.next,
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'Enter a username';
                // Must match the backend DTO (@Matches /^[a-z0-9_]{3,20}$/) —
                // lowercase only, otherwise the server 400s after submit.
                if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(t)) {
                  return '3-20 lowercase letters, numbers, or underscores';
                }
                return null;
              },
              decoration: const InputDecoration(hintText: 'username', prefixText: '@'),
            ),
          ),
          const SizedBox(height: OrdoSpacing.md),

          OField(
            label: 'Bio',
            child: TextFormField(
              controller: _bio,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(hintText: 'A short bio'),
            ),
          ),
          const SizedBox(height: OrdoSpacing.md),

          OField(
            label: 'Avatar URL',
            child: TextFormField(
              controller: _avatar,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'https://...'),
            ),
          ),
          const SizedBox(height: OrdoSpacing.md),

          OField(
            label: 'Timezone',
            child: DropdownButtonFormField<String>(
              initialValue: _timezone,
              decoration: const InputDecoration(hintText: 'Select timezone'),
              items: [
                for (final tz in _timezones) DropdownMenuItem(value: tz, child: Text(tz)),
              ],
              onChanged: (v) => setState(() => _timezone = v),
            ),
          ),
          const SizedBox(height: OrdoSpacing.xl),

          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save changes'),
          ),
        ],
      ),
    );
  }
}
