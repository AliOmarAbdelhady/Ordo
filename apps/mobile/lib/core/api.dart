import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/models.dart';
import 'config.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, [this.status]);
  @override
  String toString() => message;
}

class MemberRef {
  final String id;
  final String name;
  final String? avatarUrl;
  MemberRef({required this.id, required this.name, this.avatarUrl});
  factory MemberRef.fromJson(Map<String, dynamic> j) =>
      MemberRef(id: j['id'], name: j['name'] ?? '', avatarUrl: j['avatarUrl']);
}

class LoginResult {
  final User user;
  final String accessToken;
  final String refreshToken;
  LoginResult(this.user, this.accessToken, this.refreshToken);
}

/// Persists access/refresh tokens in secure storage, mirrored in memory.
class TokenStore {
  final FlutterSecureStorage _s;
  TokenStore(this._s);

  String? access;
  String? refresh;

  Future<void> load() async {
    access = await _s.read(key: 'ordo_access');
    refresh = await _s.read(key: 'ordo_refresh');
  }

  Future<void> save(String a, String r) async {
    access = a;
    refresh = r;
    await _s.write(key: 'ordo_access', value: a);
    await _s.write(key: 'ordo_refresh', value: r);
  }

  Future<void> clear() async {
    access = null;
    refresh = null;
    await _s.delete(key: 'ordo_access');
    await _s.delete(key: 'ordo_refresh');
  }
}

final tokenStoreProvider = Provider<TokenStore>((ref) {
  return TokenStore(const FlutterSecureStorage());
});

final _refreshDioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(baseUrl: apiBaseUrl, connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 20)));
});

/// Dio with auth header injection + transparent refresh-on-401.
final dioProvider = Provider<Dio>((ref) {
  final tokens = ref.read(tokenStoreProvider);
  final refreshDio = ref.read(_refreshDioProvider);
  final dio = Dio(BaseOptions(
    baseUrl: apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    sendTimeout: const Duration(seconds: 20),
  ));

  // Single-flight refresh: when many requests fail with 401 at once (very common
  // on app foreground — timeline, tasks, groups, notifications all fire), they
  // all share ONE refresh instead of each posting /auth/refresh. Refresh-token
  // rotation means un-serialized concurrent refreshes would log the user out.
  Future<bool>? refreshInFlight;

  Future<bool> performRefresh() async {
    final rt = tokens.refresh;
    if (rt == null) return false;
    try {
      final res = await refreshDio.post('/api/auth/refresh', data: {'refreshToken': rt});
      await tokens.save(res.data['accessToken'] as String, res.data['refreshToken'] as String);
      // Notify the realtime layer so the socket reconnects with the fresh token.
      ref.read(authRefreshProvider)?.call(tokens.access!);
      return true;
    } catch (_) {
      await tokens.clear();
      // Force the auth controller back to logged-out.
      ref.read(authLogoutProvider)?.call();
      return false;
    }
  }

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      final a = tokens.access;
      if (a != null && !options.path.contains('/auth/refresh')) {
        options.headers['Authorization'] = 'Bearer $a';
      }
      handler.next(options);
    },
    onError: (e, handler) async {
      final status = e.response?.statusCode;
      final isAuthCall = e.requestOptions.path.startsWith('/api/auth/');
      if (status == 401 && !isAuthCall) {
        final fut = refreshInFlight ??= performRefresh();
        final ok = await fut;
        refreshInFlight = null;
        if (ok) {
          e.requestOptions.headers['Authorization'] = 'Bearer ${tokens.access}';
          return handler.resolve(await dio.fetch(e.requestOptions));
        }
      }
      handler.next(e);
    },
  ));

  return dio;
});

/// The auth controller registers a logout callback here so the Dio interceptor
/// (which lives below it in the provider graph) can trigger a forced logout.
final authLogoutProvider = StateProvider<void Function()?>((ref) => null);

/// The auth controller registers a refresh callback here so the Dio interceptor
/// can notify it when the access token is rotated on a 401 — the realtime socket
/// must reconnect with the fresh token (socket_io_client freezes the handshake
/// auth at build time, so it would otherwise keep using the stale, expired one).
final authRefreshProvider = StateProvider<void Function(String newAccessToken)?>((ref) => null);

class ApiClient {
  final Dio dio;
  ApiClient(this.dio);

  Future<T> _run<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on DioException catch (e) {
      final data = e.response?.data;
      var msg = 'Something went wrong';
      if (data is Map) {
        final err = data['error'];
        if (err is Map) msg = err['message']?.toString() ?? msg;
        if (err is String) msg = err;
      }
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        msg = 'Network timeout. Check your connection.';
      } else if (e.type == DioExceptionType.connectionError) {
        msg = 'Cannot reach the server.';
      }
      throw ApiException(msg, e.response?.statusCode);
    }
  }

  // ── Auth ──────────────────────────────────────────────────────────────────
  Future<User> me() => _run(() async {
        final r = await dio.get('/api/me');
        return User.fromJson(r.data);
      });

  Future<LoginResult> login(String email, String password) => _run(() async {
        final r = await dio.post('/api/auth/login', data: {'email': email, 'password': password});
        return LoginResult(User.fromJson(r.data['user']), r.data['accessToken'], r.data['refreshToken']);
      });

  Future<LoginResult> register(String name, String email, String username, String password) => _run(() async {
        final r = await dio.post('/api/auth/register',
            data: {'name': name, 'email': email, 'username': username, 'password': password});
        return LoginResult(User.fromJson(r.data['user']), r.data['accessToken'], r.data['refreshToken']);
      });

  Future<void> logout(String? refreshToken) => _run(() async {
        await dio.post('/api/auth/logout', data: {'refreshToken': refreshToken});
      });

  // ── Groups ────────────────────────────────────────────────────────────────
  Future<List<Group>> groups() => _run(() async {
        final r = await dio.get('/api/groups');
        return (r.data as List).map((e) => Group.fromJson(e)).toList();
      });

  Future<GroupDetail> group(String id) => _run(() async {
        final r = await dio.get('/api/groups/$id');
        return GroupDetail.fromJson(r.data);
      });

  Future<List<TemplateInfo>> templates() => _run(() async {
        final r = await dio.get('/api/groups/templates');
        return ((r.data['templates'] as List)).map((e) => TemplateInfo.fromJson(e)).toList();
      });

  Future<Group> createGroup(Map<String, dynamic> body) => _run(() async {
        final r = await dio.post('/api/groups', data: body);
        return Group.fromJson(r.data);
      });

  Future<Group> updateGroup(String id, Map<String, dynamic> body) => _run(() async {
        final r = await dio.patch('/api/groups/$id', data: body);
        return Group.fromJson(r.data);
      });

  Future<void> deleteGroup(String id) => _run(() => dio.delete('/api/groups/$id'));

  Future<String> invite(String groupId) => _run(() async {
        final r = await dio.post('/api/groups/$groupId/invite');
        return r.data['code'] as String;
      });

  Future<String> joinByCode(String code) => _run(() async {
        final r = await dio.post('/api/groups/join', data: {'code': code});
        return r.data['groupId'] as String;
      });

  Future<List<GroupMember>> members(String groupId) => _run(() async {
        final r = await dio.get('/api/groups/$groupId/members');
        return ((r.data['members'] as List)).map((e) => GroupMember.fromJson(e)).toList();
      });

  Future<void> leaveGroup(String groupId) => _run(() => dio.post('/api/groups/$groupId/leave'));

  Future<void> removeMember(String groupId, String memberId) =>
      _run(() => dio.delete('/api/groups/$groupId/members/$memberId'));

  Future<void> updateMemberRole(String groupId, String memberId, String role) =>
      _run(() => dio.patch('/api/groups/$groupId/members/$memberId', data: {'role': role}));

  Future<void> setPinned(String groupId, bool pinned) =>
      _run(() => dio.patch('/api/groups/$groupId/pin', data: {'pinned': pinned}));

  // ── Timeline ──────────────────────────────────────────────────────────────
  Future<List<TimelineItem>> selfTimeline(DateTime from, DateTime to) => _run(() async {
        final r = await dio.get('/api/timeline/me', queryParameters: {'from': from.toIso8601String(), 'to': to.toIso8601String()});
        return ((r.data['items'] as List)).map((e) => TimelineItem.fromJson(e)).toList();
      });

  Future<({List<TimelineItem> items, List<MemberRef> members})> groupTimeline(String groupId, DateTime from, DateTime to) =>
      _run(() async {
        final r = await dio.get('/api/timeline/group/$groupId',
            queryParameters: {'from': from.toIso8601String(), 'to': to.toIso8601String()});
        final items = ((r.data['items'] as List)).map((e) => TimelineItem.fromJson(e)).toList();
        final members = ((r.data['members'] as List)).map((e) => MemberRef.fromJson(e)).toList();
        return (items: items, members: members);
      });

  Future<BlockDetail> createBlock(Map<String, dynamic> body) => _run(() async {
        final r = await dio.post('/api/timeline/blocks', data: body);
        return BlockDetail.fromJson(r.data);
      });

  Future<BlockDetail> updateBlock(String id, Map<String, dynamic> body) => _run(() async {
        final r = await dio.patch('/api/timeline/blocks/$id', data: body);
        return BlockDetail.fromJson(r.data);
      });

  Future<void> deleteBlock(String id) => _run(() => dio.delete('/api/timeline/blocks/$id'));

  Future<List<SyncEntry>> syncs(String blockId) => _run(() async {
        final r = await dio.get('/api/timeline/blocks/$blockId/sync');
        return ((r.data['syncs'] as List))
            .map((e) => SyncEntry(groupId: e['groupId'], visibility: e['visibility']))
            .toList();
      });

  Future<List<SyncEntry>> setSyncs(String blockId, List<SyncEntry> entries) => _run(() async {
        final r = await dio.post('/api/timeline/blocks/$blockId/sync',
            data: {'syncs': entries.map((e) => e.toJson()).toList()});
        return ((r.data['syncs'] as List))
            .map((e) => SyncEntry(groupId: e['groupId'], visibility: e['visibility']))
            .toList();
      });

  Future<void> removeSync(String blockId, String groupId) =>
      _run(() => dio.delete('/api/timeline/blocks/$blockId/sync/$groupId'));

  // ── Availability ──────────────────────────────────────────────────────────
  Future<({List<SlotResult> slots, List<MemberRef> members, int totalMembers})> findSlots(
          String groupId, DateTime start, DateTime end, int durationMinutes,
          {List<String>? required, int? minimum, List<String>? windows}) =>
      _run(() async {
        final r = await dio.post('/api/availability/find-slots', data: {
          'groupId': groupId,
          'dateRangeStart': start.toIso8601String(),
          'dateRangeEnd': end.toIso8601String(),
          'durationMinutes': durationMinutes,
          'requiredMemberIds': ?required,
          'minimumAvailableCount': ?minimum,
          'preferredTimeWindows': ?windows,
        });
        final slots = ((r.data['slots'] as List)).map((e) => SlotResult.fromJson(e)).toList();
        final members = ((r.data['members'] as List)).map((e) => MemberRef.fromJson(e)).toList();
        return (slots: slots, members: members, totalMembers: r.data['totalMembers'] as int);
      });

  Future<List<StripMember>> strip(String groupId, DateTime from, DateTime to) => _run(() async {
        final r = await dio.get('/api/availability/groups/$groupId',
            queryParameters: {'from': from.toIso8601String(), 'to': to.toIso8601String()});
        return ((r.data['members'] as List)).map((e) => StripMember.fromJson(e)).toList();
      });

  // ── Tasks ─────────────────────────────────────────────────────────────────
  Future<List<Task>> tasks(String groupId, String tab) => _run(() async {
        final r = await dio.get('/api/tasks', queryParameters: {'groupId': groupId, 'tab': tab});
        return ((r.data['tasks'] as List)).map((e) => Task.fromJson(e)).toList();
      });

  /// Cross-group "mine": every task assigned to me across all my groups.
  Future<List<Task>> tasksMine() => _run(() async {
        final r = await dio.get('/api/tasks/mine');
        return ((r.data['tasks'] as List)).map((e) => Task.fromJson(e)).toList();
      });

  Future<({Task task, List<TaskComment> comments})> taskDetail(String id) => _run(() async {
        final r = await dio.get('/api/tasks/$id');
        return (
          task: Task.fromJson(r.data),
          comments: ((r.data['comments'] as List?) ?? []).map((e) => TaskComment.fromJson(e)).toList(),
        );
      });

  Future<Task> createTask(Map<String, dynamic> body) => _run(() async {
        final r = await dio.post('/api/tasks', data: body);
        return Task.fromJson(r.data);
      });

  Future<Task> updateTask(String id, Map<String, dynamic> body) => _run(() async {
        final r = await dio.patch('/api/tasks/$id', data: body);
        return Task.fromJson(r.data);
      });

  Future<void> deleteTask(String id) => _run(() => dio.delete('/api/tasks/$id'));

  Future<TaskComment> addComment(String taskId, String body) => _run(() async {
        final r = await dio.post('/api/tasks/$taskId/comments', data: {'body': body});
        return TaskComment.fromJson(r.data);
      });

  // ── Todos ─────────────────────────────────────────────────────────────────
  Future<List<Todo>> todos(String? groupId, String tab) => _run(() async {
        final r = await dio.get('/api/todos', queryParameters: {
          'groupId': ?groupId,
          'tab': tab,
        });
        return ((r.data['todos'] as List)).map((e) => Todo.fromJson(e)).toList();
      });

  /// Cross-group "mine": my personal to-dos + to-dos in every group I belong to.
  Future<List<Todo>> todosMine(String tab) => _run(() async {
        final r = await dio.get('/api/todos/mine', queryParameters: {'tab': tab});
        return ((r.data['todos'] as List)).map((e) => Todo.fromJson(e)).toList();
      });

  Future<Todo> createTodo(Map<String, dynamic> body) => _run(() async {
        final r = await dio.post('/api/todos', data: body);
        return Todo.fromJson(r.data);
      });

  Future<Todo> updateTodo(String id, Map<String, dynamic> body) => _run(() async {
        final r = await dio.patch('/api/todos/$id', data: body);
        return Todo.fromJson(r.data);
      });

  Future<void> deleteTodo(String id) => _run(() => dio.delete('/api/todos/$id'));

  // ── Chat ──────────────────────────────────────────────────────────────────
  Future<({List<ChatMessage> messages, bool hasMore})> messages(String groupId, {DateTime? before, int limit = 40}) =>
      _run(() async {
        final r = await dio.get('/api/groups/$groupId/messages',
            queryParameters: {'before': ?before?.toIso8601String(), 'limit': limit});
        final list = ((r.data['messages'] as List)).map((e) => ChatMessage.fromJson(e)).toList();
        return (messages: list, hasMore: (r.data['hasMore'] as bool?) ?? false);
      });

  Future<ChatMessage> sendMessage(String groupId, String body, {String? replyToId}) => _run(() async {
        final r = await dio.post('/api/groups/$groupId/messages', data: {'body': body, 'replyToId': ?replyToId});
        return ChatMessage.fromJson(r.data);
      });

  Future<ChatMessage> editMessage(String id, String body) => _run(() async {
        final r = await dio.patch('/api/messages/$id', data: {'body': body});
        return ChatMessage.fromJson(r.data);
      });

  Future<void> deleteMessage(String id) => _run(() => dio.delete('/api/messages/$id'));

  Future<void> reactMessage(String id, String emoji) =>
      _run(() => dio.post('/api/messages/$id/reactions', data: {'emoji': emoji}));

  Future<void> markRead(String groupId) => _run(() => dio.post('/api/groups/$groupId/read'));

  // ── Notifications ─────────────────────────────────────────────────────────
  Future<List<OrdoNotification>> notifications({bool unreadOnly = false}) => _run(() async {
        final r = await dio.get('/api/notifications', queryParameters: {'unreadOnly': unreadOnly.toString()});
        return ((r.data['notifications'] as List)).map((e) => OrdoNotification.fromJson(e)).toList();
      });

  Future<int> unreadCount() => _run(() async {
        final r = await dio.get('/api/notifications/unread-count');
        return r.data['count'] as int;
      });

  Future<void> markNotificationRead([String? id]) => _run(() => dio.post('/api/notifications/read', data: {'id': id}));

  // ── Profile ───────────────────────────────────────────────────────────────
  Future<User> updateProfile(Map<String, dynamic> body) => _run(() async {
        final r = await dio.patch('/api/me/profile', data: body);
        return User.fromJson(r.data);
      });

  Future<User> updatePreferences(Map<String, dynamic> body) => _run(() async {
        final r = await dio.patch('/api/me/preferences', data: body);
        return User.fromJson(r.data);
      });

  Future<AvailabilityPrefs> getAvailability() => _run(() async {
        final r = await dio.get('/api/me/availability');
        return AvailabilityPrefs.fromJson(r.data);
      });

  Future<AvailabilityPrefs> updateAvailability(Map<String, dynamic> body) => _run(() async {
        final r = await dio.patch('/api/me/availability', data: body);
        return AvailabilityPrefs.fromJson(r.data);
      });

  // ── Account ───────────────────────────────────────────────────────────────
  Future<void> deleteAccount() => _run(() => dio.delete('/api/me'));

  Future<Map<String, dynamic>> exportData() => _run(() async {
        final r = await dio.get('/api/me/export');
        return r.data as Map<String, dynamic>;
      });

  Future<void> revokeSession(String id) => _run(() => dio.delete('/api/auth/sessions/$id'));

  Future<List<Map<String, dynamic>>> sessions() => _run(() async {
        final r = await dio.get('/api/auth/sessions');
        return (r.data['sessions'] as List).map((e) => e as Map<String, dynamic>).toList();
      });

  // ── OTP ───────────────────────────────────────────────────────────────────
  Future<String> requestOtp(String target, String value, [String purpose = 'signup']) => _run(() async {
        final r = await dio.post('/api/auth/request-otp', data: {'target': target, 'value': value, 'purpose': purpose});
        // Only surface the dev OTP code in debug builds — in profile/release the
        // backend omits it and we must not assume it is present.
        return kDebugMode ? ((r.data['devCode'] as String?) ?? '') : '';
      });

  Future<bool> verifyOtp(String target, String value, String code, [String purpose = 'signup']) => _run(() async {
        final r = await dio.post('/api/auth/verify-otp', data: {'target': target, 'value': value, 'code': code, 'purpose': purpose});
        return r.data['verified'] == true;
      });

  /// Authenticated verification: validates the code AND marks the caller's
  /// phone/email as verified server-side. Use this from the in-app verify flow;
  /// the public verifyOtp only checks the code without persisting verification.
  Future<bool> verifyContact(String target, String value, String code, [String? purpose]) =>
      _run(() async {
        final p = purpose ?? (target == 'phone' ? 'verify_phone' : 'verify_email');
        final endpoint = target == 'phone' ? '/api/auth/verify-phone' : '/api/auth/verify-email';
        await dio.post(endpoint, data: {'target': target, 'value': value, 'code': code, 'purpose': p});
        return true;
      });

  // ── Search ────────────────────────────────────────────────────────────────
  Future<SearchResult> search(String q) => _run(() async {
        final r = await dio.get('/api/search', queryParameters: {'q': q});
        return SearchResult.fromJson(r.data);
      });

  // ── Polls ─────────────────────────────────────────────────────────────────
  Future<List<Poll>> polls(String groupId) => _run(() async {
        final r = await dio.get('/api/groups/$groupId/polls');
        return ((r.data['polls'] as List)).map((e) => Poll.fromJson(e)).toList();
      });

  Future<Poll> createPoll(String groupId, String question, List<String> options, {bool multiple = false}) => _run(() async {
        final r = await dio.post('/api/groups/$groupId/polls', data: {
          'question': question,
          'options': options.map((t) => {'text': t}).toList(),
          'multiple': multiple,
        });
        return Poll.fromJson(r.data);
      });

  Future<Poll> votePoll(String pollId, List<String> optionIds) => _run(() async {
        final r = await dio.post('/api/polls/$pollId/vote', data: {'optionIds': optionIds});
        return Poll.fromJson(r.data);
      });

  Future<void> deletePoll(String pollId) => _run(() => dio.delete('/api/polls/$pollId'));

  // ── Announcements ─────────────────────────────────────────────────────────
  Future<List<Announcement>> announcements(String groupId) => _run(() async {
        final r = await dio.get('/api/groups/$groupId/announcements');
        return ((r.data['announcements'] as List)).map((e) => Announcement.fromJson(e)).toList();
      });

  Future<Announcement> createAnnouncement(String groupId, String title, String body) => _run(() async {
        final r = await dio.post('/api/groups/$groupId/announcements', data: {'title': title, 'body': body});
        return Announcement.fromJson(r.data);
      });

  Future<void> deleteAnnouncement(String id) => _run(() => dio.delete('/api/announcements/$id'));

  // ── Inbox / DMs ───────────────────────────────────────────────────────────
  Future<List<DmThread>> dmThreads() => _run(() async {
        final r = await dio.get('/api/inbox/threads');
        return ((r.data['threads'] as List)).map((e) => DmThread.fromJson(e)).toList();
      });

  Future<String> startDm(String otherUserId) => _run(() async {
        final r = await dio.post('/api/inbox/threads', data: {'otherUserId': otherUserId});
        return r.data['threadId'] as String;
      });

  Future<({List<DmMessage> messages, bool hasMore})> dmMessages(String threadId, {DateTime? before}) => _run(() async {
        final r = await dio.get('/api/inbox/threads/$threadId/messages',
            queryParameters: {'before': ?before?.toIso8601String()});
        final list = ((r.data['messages'] as List)).map((e) => DmMessage.fromJson(e)).toList();
        return (messages: list, hasMore: (r.data['hasMore'] as bool?) ?? false);
      });

  Future<DmMessage> sendDm(String threadId, String body) => _run(() async {
        final r = await dio.post('/api/inbox/threads/$threadId/messages', data: {'body': body});
        return DmMessage.fromJson(r.data);
      });

  Future<void> markDmRead(String threadId) => _run(() => dio.post('/api/inbox/threads/$threadId/read'));

  // ── Media / Files ─────────────────────────────────────────────────────────
  Future<List<MediaFile>> media({String? groupId}) => _run(() async {
        final r = await dio.get('/api/media', queryParameters: {'groupId': ?groupId});
        return ((r.data['files'] as List)).map((e) => MediaFile.fromJson(e)).toList();
      });

  Future<MediaFile> uploadMedia(String path, String filename, {String? groupId}) => _run(() async {
        // The server infers the MIME from the filename extension, so we don't
        // need to set a precise part content-type (mobile pickers are unreliable).
        final form = FormData.fromMap({
          'file': await MultipartFile.fromFile(path, filename: filename),
        });
        final r = await dio.post('/api/media', data: form, queryParameters: {'groupId': ?groupId});
        return MediaFile.fromJson(r.data);
      });

  Future<void> deleteMedia(String id) => _run(() => dio.delete('/api/media/$id'));

  // ── Location ──────────────────────────────────────────────────────────────
  Future<List<LocationMember>> locations(String groupId) => _run(() async {
        final r = await dio.get('/api/groups/$groupId/location');
        return ((r.data['locations'] as List)).map((e) => LocationMember.fromJson(e)).toList();
      });

  Future<void> setLocationShare(String groupId, String mode) => _run(() async {
        await dio.post('/api/groups/$groupId/location', data: {'mode': mode});
      });

  Future<void> pushLocation(String groupId, double lat, double lng) => _run(() async {
        await dio.post('/api/groups/$groupId/location/point', data: {'lat': lat, 'lng': lng});
      });

  Future<void> stopLocation(String groupId) => _run(() => dio.delete('/api/groups/$groupId/location'));

  // ── Categories ────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> categories({String? groupId}) => _run(() async {
        final r = await dio.get('/api/timeline/categories', queryParameters: {'groupId': ?groupId});
        return ((r.data['categories'] as List)).map((e) => e as Map<String, dynamic>).toList();
      });

  // ── Events / RSVP ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> rsvp(String blockId, String status) => _run(() async {
        final r = await dio.post('/api/events/$blockId/rsvp', data: {'status': status});
        return r.data;
      });

  // ── AI ────────────────────────────────────────────────────────────────────
  Future<AiSuggestion> aiParse(String text, {String? groupId}) => _run(() async {
        final r = await dio.post('/api/ai/parse-command', data: {'text': text, 'groupId': ?groupId});
        return AiSuggestion(r.data['suggestion'] as Map<String, dynamic>);
      });

  Future<List<AiSuggestion>> aiExtractTasks(List<String> messages, {String? groupId}) => _run(() async {
        final r = await dio.post('/api/ai/extract-tasks', data: {'messages': messages, 'groupId': ?groupId});
        return ((r.data['suggestions'] as List)).map((e) => AiSuggestion(e as Map<String, dynamic>)).toList();
      });

  Future<Map<String, dynamic>> aiSummarize(String groupId) => _run(() async {
        final r = await dio.post('/api/ai/summarize-group', data: {'groupId': groupId});
        return r.data;
      });

  Future<Map<String, dynamic>> aiPlanDay() => _run(() async {
        final r = await dio.get('/api/ai/plan-day');
        return r.data;
      });

  Future<Map<String, dynamic>> aiApply(Map<String, dynamic> suggestion, {String? groupId}) => _run(() async {
        final r = await dio.post('/api/ai/apply-suggestion', data: {'suggestion': suggestion, 'groupId': ?groupId});
        return r.data;
      });
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref.watch(dioProvider)));
