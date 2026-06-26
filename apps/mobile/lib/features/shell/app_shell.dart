import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../timeline/add_block_sheet.dart';

class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'Today'),
          const NavigationDestination(icon: Icon(Icons.groups_2_outlined), selectedIcon: Icon(Icons.groups_2), label: 'Groups'),
          const NavigationDestination(icon: Icon(Icons.calendar_view_week_outlined), selectedIcon: Icon(Icons.calendar_view_week), label: 'Timeline'),
          NavigationDestination(
            icon: Badge(isLabelVisible: unread > 0, label: Text(unread > 9 ? '9+' : '$unread'), child: const Icon(Icons.inbox_outlined)),
            selectedIcon: Badge(isLabelVisible: unread > 0, label: Text(unread > 9 ? '9+' : '$unread'), child: const Icon(Icons.inbox)),
            label: 'Inbox',
          ),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        elevation: 2,
        onPressed: () => _showCommandMenu(context, ref),
        child: const Icon(Icons.add, size: 26),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  void _showCommandMenu(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: OrdoSpacing.sm, right: OrdoSpacing.sm, bottom: OrdoSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: OrdoSpacing.md, bottom: OrdoSpacing.sm),
                  child: Text('Quick add', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSecondary, letterSpacing: 0.3)),
                ),
                _CommandTile(
                  icon: Icons.schedule_outlined,
                  color: OrdoAccent.blue.light,
                  title: 'Timeline block',
                  subtitle: 'Add to your self timeline',
                  onTap: () {
                    Navigator.pop(ctx);
                    showAddBlockSheet(context, ref, groupId: null);
                  },
                ),
                _CommandTile(
                  icon: Icons.check_circle_outline,
                  color: OrdoAccent.emerald.light,
                  title: 'To-do',
                  subtitle: 'A quick personal item',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go('/timeline/todos');
                  },
                ),
                _CommandTile(
                  icon: Icons.groups_2_outlined,
                  color: OrdoAccent.violet.light,
                  title: 'New group',
                  subtitle: 'Create a shared space',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go('/groups/create');
                  },
                ),
                _CommandTile(
                  icon: Icons.search,
                  color: OrdoAccent.amber.light,
                  title: 'Find free time',
                  subtitle: 'Discover when everyone is free',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/find-slot');
                  },
                ),
                _CommandTile(
                  icon: Icons.manage_search,
                  color: OrdoAccent.cyan.light,
                  title: 'Search',
                  subtitle: 'Groups, tasks, to-dos, messages',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/search');
                  },
                ),
                _CommandTile(
                  icon: Icons.auto_awesome_outlined,
                  color: OrdoAccent.violet.light,
                  title: 'Ordo Copilot',
                  subtitle: 'Plan with AI — review before applying',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/assistant');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CommandTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _CommandTile({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrdoRadius.md)),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(OrdoRadius.md)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
    );
  }
}
