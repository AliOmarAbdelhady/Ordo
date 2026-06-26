import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'api.dart';
import 'auth_controller.dart';

typedef DateRange = ({DateTime from, DateTime to});
typedef GroupRange = ({String groupId, DateTime from, DateTime to});

DateRange rangeFor(DateTime from, DateTime to) => (from: from, to: to);

// ── Groups ───────────────────────────────────────────────────────────────────
final groupsProvider = FutureProvider<List<Group>>((ref) async {
  ref.watch(authControllerProvider);
  return ref.read(apiClientProvider).groups();
});

final templatesProvider = FutureProvider<List<TemplateInfo>>((ref) async {
  return ref.read(apiClientProvider).templates();
});

final groupDetailProvider = FutureProvider.family<GroupDetail, String>((ref, id) async {
  ref.watch(authControllerProvider);
  return ref.read(apiClientProvider).group(id);
});

final groupMembersProvider = FutureProvider.family<List<GroupMember>, String>((ref, id) async {
  ref.watch(authControllerProvider);
  return ref.read(apiClientProvider).members(id);
});

// ── Timeline ─────────────────────────────────────────────────────────────────
final selfTimelineProvider = FutureProvider.family<List<TimelineItem>, DateRange>((ref, r) async {
  ref.watch(authControllerProvider);
  return ref.read(apiClientProvider).selfTimeline(r.from, r.to);
});

final groupTimelineProvider = FutureProvider.family<({List<TimelineItem> items, List<MemberRef> members}), GroupRange>((ref, r) async {
  ref.watch(authControllerProvider);
  return ref.read(apiClientProvider).groupTimeline(r.groupId, r.from, r.to);
});

final blockSyncsProvider = FutureProvider.family<List<SyncEntry>, String>((ref, blockId) async {
  ref.watch(authControllerProvider);
  return ref.read(apiClientProvider).syncs(blockId);
});

// ── Availability ─────────────────────────────────────────────────────────────
final availabilityStripProvider = FutureProvider.family<List<StripMember>, GroupRange>((ref, r) async {
  ref.watch(authControllerProvider);
  return ref.read(apiClientProvider).strip(r.groupId, r.from, r.to);
});

// ── Tasks ────────────────────────────────────────────────────────────────────
typedef TaskQuery = ({String groupId, String tab});
final tasksProvider = FutureProvider.family<List<Task>, TaskQuery>((ref, q) async {
  ref.watch(authControllerProvider);
  return ref.read(apiClientProvider).tasks(q.groupId, q.tab);
});

final taskDetailProvider = FutureProvider.family<({Task task, List<TaskComment> comments}), String>((ref, id) async {
  ref.watch(authControllerProvider);
  return ref.read(apiClientProvider).taskDetail(id);
});

// ── Todos ────────────────────────────────────────────────────────────────────
typedef TodoQuery = ({String? groupId, String tab});
final todosProvider = FutureProvider.family<List<Todo>, TodoQuery>((ref, q) async {
  ref.watch(authControllerProvider);
  return ref.read(apiClientProvider).todos(q.groupId, q.tab);
});

// ── Notifications ────────────────────────────────────────────────────────────
final notificationsProvider = FutureProvider<List<OrdoNotification>>((ref) async {
  ref.watch(authControllerProvider);
  return ref.read(apiClientProvider).notifications();
});

final unreadCountProvider = FutureProvider<int>((ref) async {
  ref.watch(authControllerProvider);
  return ref.read(apiClientProvider).unreadCount();
});
