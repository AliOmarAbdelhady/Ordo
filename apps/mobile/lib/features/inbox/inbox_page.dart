import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';

IconData _iconForType(String type) {
  switch (type) {
    case 'TASK_ASSIGNED':
      return Icons.assignment_ind_outlined;
    case 'MESSAGE_MENTION':
      return Icons.alternate_email;
    case 'EVENT_SOON':
    case 'REMINDER':
      return Icons.notifications_active_outlined;
    case 'GROUP_INVITE':
      return Icons.group_add_outlined;
    default:
      return Icons.info_outline;
  }
}

class InboxPage extends ConsumerWidget {
  const InboxPage({super.key});

  Future<void> _markRead(WidgetRef ref, BuildContext context, OrdoNotification n) async {
    // Optimistically refresh: mark then invalidate.
    try {
      await ref.read(apiClientProvider).markNotificationRead(n.id);
    } catch (_) {
      // best-effort
    }
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
  }

  Future<void> _markAllRead(WidgetRef ref) async {
    try {
      await ref.read(apiClientProvider).markNotificationRead(null);
    } catch (_) {}
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
  }

  void _open(WidgetRef ref, BuildContext context, OrdoNotification n) {
    _markRead(ref, context, n);
    final data = n.data;
    if (n.type == 'TASK_ASSIGNED' && data['taskId'] is String) {
      context.push('/tasks/${data['taskId']}');
    } else if (n.type == 'MESSAGE_MENTION' && data['groupId'] is String) {
      context.push('/groups/${data['groupId']}/chat');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNotifs = ref.watch(notificationsProvider);
    final asyncDms = ref.watch(dmThreadsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'New message',
            onPressed: () => context.push('/inbox/new-dm'),
          ),
          asyncNotifs.maybeWhen(
            data: (list) => list.any((n) => !n.read)
                ? TextButton(
                    onPressed: () => _markAllRead(ref),
                    child: const Text('Mark all read'),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(notificationsProvider);
            ref.invalidate(unreadCountProvider);
          },
          child: asyncNotifs.when(
            loading: () => OSkeletonBox(
              ListView(
                padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg),
                children: const [
                  SizedBox(height: OrdoSpacing.md),
                  OSkeleton(height: 64),
                  SizedBox(height: OrdoSpacing.sm),
                  OSkeleton(height: 64),
                  SizedBox(height: OrdoSpacing.sm),
                  OSkeleton(height: 64),
                ],
              ),
            ),
            error: (e, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: OrdoSpacing.xxl),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(OrdoSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off_outlined, color: cs.error, size: 34),
                        const SizedBox(height: OrdoSpacing.sm),
                        Text(
                          e is ApiException ? e.message : 'Could not load notifications.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSecondary),
                        ),
                        const SizedBox(height: OrdoSpacing.md),
                        OutlinedButton.icon(
                          onPressed: () {
                            ref.invalidate(notificationsProvider);
                            ref.invalidate(unreadCountProvider);
                          },
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            data: (notifs) {
              final dms = asyncDms.valueOrNull ?? [];
              if (notifs.isEmpty && dms.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: OrdoSpacing.xxl),
                    OEmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: "You're all caught up",
                      subtitle: 'New notifications and messages will appear here.',
                    ),
                  ],
                );
              }
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg, vertical: OrdoSpacing.sm),
                children: [
                  if (dms.isNotEmpty) ...[
                    const OSectionHeader(title: 'Direct messages'),
                    for (final t in dms)
                      Padding(
                        padding: const EdgeInsets.only(bottom: OrdoSpacing.sm),
                        child: OCard(
                          onTap: () => context.push('/inbox/dm/${t.id}'),
                          child: Row(children: [
                            CircleAvatar(child: Text(t.otherName != null && t.otherName!.isNotEmpty ? t.otherName![0] : '?')),
                            const SizedBox(width: OrdoSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.otherName ?? 'Direct message', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  if (t.lastBody != null) Text(t.lastBody!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: cs.onSecondary)),
                                ],
                              ),
                            ),
                            if (t.unreadCount > 0) OBadge(label: '${t.unreadCount}', color: cs.primary),
                          ]),
                        ),
                      ),
                    const SizedBox(height: OrdoSpacing.sm),
                  ],
                  if (notifs.isNotEmpty) const OSectionHeader(title: 'Activity'),
                  for (final n in notifs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: OrdoSpacing.sm),
                      child: _NotificationTile(notification: n, onTap: () => _open(ref, context, n)),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final OrdoNotification notification;
  final VoidCallback onTap;
  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final n = notification;
    final unread = !n.read;

    return OCard(
      onTap: onTap,
      color: unread ? cs.primary.withValues(alpha: 0.05) : null,
      bordered: !unread,
      padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.md, vertical: OrdoSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(_iconForType(n.type), size: 20, color: unread ? cs.primary : cs.onSecondary),
          ),
          const SizedBox(width: OrdoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (unread) ...[
                      ODot(cs.primary, size: 8),
                      const SizedBox(width: OrdoSpacing.xs),
                    ],
                    Expanded(
                      child: Text(
                        n.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                          color: cs.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (n.body != null && n.body!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    n.body!,
                    style: TextStyle(fontSize: 13, color: cs.onSecondary, height: 1.4),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  fmtRelative(n.createdAt),
                  style: TextStyle(fontSize: 11, color: cs.onSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
