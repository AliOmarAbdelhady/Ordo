import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../core/settings.dart';
import '../../shared/widgets.dart';

/// Full settings list: appearance, notifications, privacy, data, danger zone.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  // Local-only notification preferences (UI demo for MVP).
  bool _notifTasks = true;
  bool _notifChat = true;
  bool _notifReminders = true;
  bool _notifDigest = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            OrdoSpacing.lg, OrdoSpacing.lg, OrdoSpacing.lg, OrdoSpacing.xxl),
        children: [
          // ── Appearance ──────────────────────────────────────────────────
          const _GroupLabel('Appearance'),
          OCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FieldLabel('Theme'),
                OSegmented<ThemeMode>(
                  segments: const [ThemeMode.light, ThemeMode.dark, ThemeMode.system],
                  value: settings.themeMode,
                  label: (m) => const {
                    ThemeMode.light: 'Light',
                    ThemeMode.dark: 'Dark',
                    ThemeMode.system: 'System',
                  }[m]!,
                  onChanged: (m) => ref.read(settingsProvider.notifier).setThemeMode(m),
                ),
                const SizedBox(height: OrdoSpacing.lg),
                const _FieldLabel('Accent color'),
                _AccentRow(
                  current: settings.accentName,
                  onPick: (name) => ref.read(settingsProvider.notifier).setAccent(name),
                ),
              ],
            ),
          ),
          const SizedBox(height: OrdoSpacing.xl),

          // ── Notifications ───────────────────────────────────────────────
          const _GroupLabel('Notifications'),
          OCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SwitchTile(
                  icon: Icons.task_alt,
                  title: 'Task assignments',
                  value: _notifTasks,
                  onChanged: (v) => setState(() => _notifTasks = v),
                ),
                const Divider(height: 1, indent: OrdoSpacing.lg),
                _SwitchTile(
                  icon: Icons.chat_bubble_outline,
                  title: 'Chat messages',
                  value: _notifChat,
                  onChanged: (v) => setState(() => _notifChat = v),
                ),
                const Divider(height: 1, indent: OrdoSpacing.lg),
                _SwitchTile(
                  icon: Icons.notifications_active_outlined,
                  title: 'Reminders',
                  value: _notifReminders,
                  onChanged: (v) => setState(() => _notifReminders = v),
                ),
                const Divider(height: 1, indent: OrdoSpacing.lg),
                _SwitchTile(
                  icon: Icons.mail_outline,
                  title: 'Weekly digest',
                  value: _notifDigest,
                  onChanged: (v) => setState(() => _notifDigest = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: OrdoSpacing.xl),

          // ── Privacy ─────────────────────────────────────────────────────
          const _GroupLabel('Privacy defaults'),
          OCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: const [
                _InfoTile(
                  icon: Icons.visibility_outlined,
                  title: 'Default visibility',
                  subtitle: 'Busy only — groups see your availability, not details.',
                ),
                Divider(height: 1, indent: OrdoSpacing.lg),
                _InfoTile(
                  icon: Icons.lock_outline,
                  title: 'Sync controls',
                  subtitle: 'You approve every block shared with a group.',
                ),
                Divider(height: 1, indent: OrdoSpacing.lg),
                _InfoTile(
                  icon: Icons.schedule_outlined,
                  title: 'Availability sharing',
                  subtitle: 'Only shared with groups you belong to.',
                ),
              ],
            ),
          ),
          const SizedBox(height: OrdoSpacing.xl),

          // ── Data ────────────────────────────────────────────────────────
          const _GroupLabel('Data'),
          OCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ActionTile(
                  icon: Icons.download_outlined,
                  title: 'Export my data',
                  onTap: () => toast(context, 'Data export is coming soon.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: OrdoSpacing.xl),

          // ── Danger zone ─────────────────────────────────────────────────
          const _GroupLabel('Account'),
          OCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ActionTile(
                  icon: Icons.logout,
                  title: 'Sign out',
                  color: Theme.of(context).colorScheme.error,
                  onTap: () => _signOut(context, ref),
                ),
                const Divider(height: 1, indent: OrdoSpacing.lg),
                _ActionTile(
                  icon: Icons.delete_forever_outlined,
                  title: 'Delete account',
                  color: Theme.of(context).colorScheme.error,
                  onTap: () => _deleteAccount(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: OrdoSpacing.xl),
          Center(
            child: Text('Ordo · v0.1.0',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondary, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
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
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final ok = await confirm(
      context,
      title: 'Delete account?',
      message:
          'Account deletion is not available in this build. Contact support to remove your data.',
      confirmText: 'Got it',
      danger: true,
    );
    if (ok && context.mounted) {
      toast(context, 'Account deletion is not implemented in this build.');
    }
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(OrdoSpacing.sm, 0, OrdoSpacing.sm, OrdoSpacing.sm),
      child: Text(text,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSecondary, letterSpacing: 0.4)),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(text,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSecondary)),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final void Function(bool) onChanged;
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SwitchListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg, vertical: OrdoSpacing.xs),
      secondary: Icon(icon, color: cs.onSecondary),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _InfoTile({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg, vertical: OrdoSpacing.xs),
      leading: Icon(icon, color: cs.onSecondary),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSecondary, height: 1.35)),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.title, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurface;
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg, vertical: OrdoSpacing.xs),
      leading: Icon(icon, color: c),
      title: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c)),
      trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSecondary),
      onTap: onTap,
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
              child: selected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
            ),
          );
        },
      ),
    );
  }
}
