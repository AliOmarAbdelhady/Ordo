import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../core/settings.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';

/// Profile hub: identity, appearance, and entry points to other settings.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final settings = ref.watch(settingsProvider);

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(title: Text('Profile'), pinned: true),
          SliverList(
            delegate: SliverChildListDelegate(_content(context, ref, user, settings)),
          ),
        ],
      ),
    );
  }

  List<Widget> _content(
      BuildContext context, WidgetRef ref, User user, SettingsState settings) {
    final cs = Theme.of(context).colorScheme;
    return [
      const SizedBox(height: OrdoSpacing.lg),
      _ProfileHeader(user: user),
      const SizedBox(height: OrdoSpacing.xl),

      // ── Appearance ──────────────────────────────────────────────────────
      const OSectionHeader(title: 'Appearance'),
      OCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Theme',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSecondary)),
            const SizedBox(height: OrdoSpacing.sm),
            OSegmented<ThemeMode>(
              segments: const [ThemeMode.light, ThemeMode.dark, ThemeMode.system],
              value: settings.themeMode,
              label: (m) =>
                  const {ThemeMode.light: 'Light', ThemeMode.dark: 'Dark', ThemeMode.system: 'System'}[m]!,
              onChanged: (m) => ref.read(settingsProvider.notifier).setThemeMode(m),
            ),
            const SizedBox(height: OrdoSpacing.lg),
            Text('Accent color',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSecondary)),
            const SizedBox(height: OrdoSpacing.sm),
            _AccentRow(
              current: settings.accentName,
              onPick: (name) => ref.read(settingsProvider.notifier).setAccent(name),
            ),
          ],
        ),
      ),
      const SizedBox(height: OrdoSpacing.xl),

      // ── Account ────────────────────────────────────────────────────────
      const OSectionHeader(title: 'Account'),
      OCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _MenuTile(
              icon: Icons.schedule_outlined,
              title: 'Availability hours',
              subtitle: 'Work & sleep schedule',
              onTap: () => _editAvailability(context, ref),
            ),
            const Divider(height: 1, indent: OrdoSpacing.lg),
            _MenuTile(
              icon: Icons.devices_outlined,
              title: 'Sessions',
              subtitle: 'Coming soon',
              trailing: const OBadge(label: 'Soon'),
              onTap: () => toast(context, 'Session management is coming soon.'),
            ),
            const Divider(height: 1, indent: OrdoSpacing.lg),
            _MenuTile(
              icon: Icons.settings_outlined,
              title: 'Settings',
              onTap: () => context.push('/profile/settings'),
            ),
          ],
        ),
      ),
      const SizedBox(height: OrdoSpacing.xl),

      // ── About ──────────────────────────────────────────────────────────
      const OSectionHeader(title: 'About'),
      OCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _MenuTile(
              icon: Icons.help_outline,
              title: 'Help',
              onTap: () => toast(context, 'Help center coming soon.'),
            ),
            const Divider(height: 1, indent: OrdoSpacing.lg),
            _MenuTile(
              icon: Icons.info_outline,
              title: 'About Ordo',
              subtitle: 'Time-first coordination',
              onTap: () => toast(context, 'Ordo · v0.1.0'),
            ),
          ],
        ),
      ),
      const SizedBox(height: OrdoSpacing.xl),

      // ── Sign out ───────────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: cs.error,
            side: BorderSide(color: cs.error),
          ),
          onPressed: () async {
            final ok = await confirm(
              context,
              title: 'Sign out?',
              message: 'You will need to sign in again.',
              confirmText: 'Sign out',
              danger: true,
            );
            if (ok) {
              await ref.read(authControllerProvider.notifier).logout();
            }
          },
          child: const Text('Sign out'),
        ),
      ),
      const SizedBox(height: OrdoSpacing.xxl),
    ];
  }

  Future<void> _editAvailability(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AvailabilitySheet(ref: ref),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final User user;
  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg),
      child: OCard(
        child: Column(
          children: [
            OAvatar(name: user.name, imageUrl: user.avatarUrl, radius: 44),
            const SizedBox(height: OrdoSpacing.md),
            Text(user.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 2),
            Text('@${user.username}',
                style: TextStyle(color: cs.onSecondary, fontSize: 14)),
            if (user.bio != null && user.bio!.isNotEmpty) ...[
              const SizedBox(height: OrdoSpacing.sm),
              Text(user.bio!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurface, fontSize: 14, height: 1.4)),
            ],
            const SizedBox(height: OrdoSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () => context.push('/profile/edit'),
                child: const Text('Edit profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccentRow extends StatelessWidget {
  final String current;
  final void Function(String name) onPick;
  const _AccentRow({required this.current, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: OrdoAccent.all.length,
        separatorBuilder: (_, _) => const SizedBox(width: OrdoSpacing.sm),
        itemBuilder: (_, i) {
          final a = OrdoAccent.all[i];
          final selected = a.name == current;
          return GestureDetector(
            onTap: () => onPick(a.name),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: a.primary(isDark),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
                  width: 3,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _MenuTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: cs.onSecondary),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: TextStyle(fontSize: 12, color: cs.onSecondary))
          : null,
      trailing: trailing ?? Icon(Icons.chevron_right, color: cs.onSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg, vertical: OrdoSpacing.xs),
    );
  }
}

class _AvailabilitySheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _AvailabilitySheet({required this.ref});

  @override
  ConsumerState<_AvailabilitySheet> createState() => _AvailabilitySheetState();
}

class _AvailabilitySheetState extends ConsumerState<_AvailabilitySheet> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  late TimeOfDay _workStart;
  late TimeOfDay _workEnd;
  late TimeOfDay _sleepStart;
  late TimeOfDay _sleepEnd;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await widget.ref.read(apiClientProvider).getAvailability();
      if (!mounted) return;
      setState(() {
        _workStart = _parse(prefs.workStart);
        _workEnd = _parse(prefs.workEnd);
        _sleepStart = _parse(prefs.sleepStart);
        _sleepEnd = _parse(prefs.sleepEnd);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load availability.';
        _loading = false;
      });
    }
  }

  TimeOfDay _parse(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pick(TimeOfDay current, void Function(TimeOfDay) set) async {
    final t = await showTimePicker(context: context, initialTime: current);
    if (t != null) set(t);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.ref.read(apiClientProvider).updateAvailability({
        'workStart': _fmt(_workStart),
        'workEnd': _fmt(_workEnd),
        'sleepStart': _fmt(_sleepStart),
        'sleepEnd': _fmt(_sleepEnd),
      });
      if (mounted) {
        toast(context, 'Availability updated');
        Navigator.pop(context);
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
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(OrdoSpacing.xl, 0, OrdoSpacing.xl, OrdoSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Availability hours', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: OrdoSpacing.sm),
            Text('Used to suggest good meeting times.',
                style: TextStyle(color: cs.onSecondary, fontSize: 13)),
            const SizedBox(height: OrdoSpacing.lg),
            if (_loading)
              const Padding(padding: EdgeInsets.all(OrdoSpacing.xl), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(OrdoSpacing.lg),
                child: Text(_error!, style: TextStyle(color: cs.error)),
              )
            else
              _TimeRow(
                label: 'Work starts',
                time: _workStart,
                onTap: () => _pick(_workStart, (t) => setState(() => _workStart = t)),
              ),
            if (!_loading && _error == null) ...[
              _TimeRow(
                label: 'Work ends',
                time: _workEnd,
                onTap: () => _pick(_workEnd, (t) => setState(() => _workEnd = t)),
              ),
              const Divider(),
              _TimeRow(
                label: 'Sleep starts',
                time: _sleepStart,
                onTap: () => _pick(_sleepStart, (t) => setState(() => _sleepStart = t)),
              ),
              _TimeRow(
                label: 'Sleep ends',
                time: _sleepEnd,
                onTap: () => _pick(_sleepEnd, (t) => setState(() => _sleepEnd = t)),
              ),
              const SizedBox(height: OrdoSpacing.lg),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;
  const _TimeRow({required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(time.format(context), style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}
