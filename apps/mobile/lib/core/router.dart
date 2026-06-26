import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_page.dart';
import '../features/auth/otp_page.dart';
import '../features/auth/register_page.dart';
import '../features/ai/ai_assistant_page.dart';
import '../features/availability/find_slot_page.dart';
import '../features/chat/group_chat_page.dart';
import '../features/groups/announcements_page.dart';
import '../features/groups/create_group_page.dart';
import '../features/groups/group_home_page.dart';
import '../features/groups/group_more_page.dart';
import '../features/groups/group_settings_page.dart';
import '../features/groups/groups_page.dart';
import '../features/groups/polls_page.dart';
import '../features/inbox/dm_thread_page.dart';
import '../features/inbox/inbox_page.dart';
import '../features/inbox/new_dm_page.dart';
import '../features/location/location_page.dart';
import '../features/media/files_page.dart';
import '../features/profile/edit_profile_page.dart';
import '../features/profile/profile_page.dart';
import '../features/profile/settings_page.dart';
import '../features/search/search_page.dart';
import '../features/shell/app_shell.dart';
import '../features/tasks/task_detail_page.dart';
import '../features/timeline/timeline_page.dart';
import '../features/todos/todos_page.dart';
import '../features/today/today_page.dart';
import 'auth_controller.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthListenable(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/today',
    refreshListenable: notifier,
    redirect: (context, state) {
      final user = notifier.value;
      final loggedIn = user != null;
      final isAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/register';
      if (!loggedIn && !isAuthRoute) return '/login';
      if (loggedIn && isAuthRoute) return '/today';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/today', builder: (_, __) => const TodayPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/groups',
              builder: (_, __) => const GroupsPage(),
              routes: [
                GoRoute(path: 'create', builder: (_, __) => const CreateGroupPage()),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/timeline',
              builder: (_, __) => const TimelinePage(),
              routes: [
                GoRoute(path: 'todos', builder: (_, __) => const TodosPage()),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/inbox', builder: (_, __) => const InboxPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (_, __) => const ProfilePage(),
              routes: [
                GoRoute(path: 'settings', builder: (_, __) => const SettingsPage()),
                GoRoute(path: 'edit', builder: (_, __) => const EditProfilePage()),
              ],
            ),
          ]),
        ],
      ),

      GoRoute(path: '/groups/:id', builder: (_, s) => GroupHomePage(groupId: s.pathParameters['id']!)),
      GoRoute(path: '/groups/:id/chat', builder: (_, s) => GroupChatPage(groupId: s.pathParameters['id']!)),
      GoRoute(path: '/groups/:id/settings', builder: (_, s) => GroupSettingsPage(groupId: s.pathParameters['id']!)),
      GoRoute(path: '/groups/:id/more', builder: (_, s) => GroupMorePage(groupId: s.pathParameters['id']!)),
      GoRoute(path: '/groups/:id/polls', builder: (_, s) => PollsPage(groupId: s.pathParameters['id']!)),
      GoRoute(path: '/groups/:id/announcements', builder: (_, s) => AnnouncementsPage(groupId: s.pathParameters['id']!)),
      GoRoute(path: '/groups/:id/files', builder: (_, s) => FilesPage(groupId: s.pathParameters['id']!)),
      GoRoute(path: '/groups/:id/location', builder: (_, s) => LocationPage(groupId: s.pathParameters['id']!)),
      GoRoute(path: '/find-slot', builder: (_, s) {
        final groupId = s.uri.queryParameters['groupId'];
        return FindSlotPage(groupId: groupId);
      }),
      GoRoute(path: '/tasks/:id', builder: (_, s) => TaskDetailPage(taskId: s.pathParameters['id']!)),
      GoRoute(path: '/search', builder: (_, __) => const SearchPage()),
      GoRoute(path: '/assistant', builder: (_, s) => AiAssistantPage(groupId: s.uri.queryParameters['groupId'])),
      GoRoute(path: '/inbox/new-dm', builder: (_, __) => const NewDmPage()),
      GoRoute(path: '/inbox/dm/:id', builder: (_, s) => DmThreadPage(threadId: s.pathParameters['id']!)),
      GoRoute(path: '/otp', builder: (_, s) => OtpPage(
        target: s.uri.queryParameters['target'] ?? 'email',
        value: s.uri.queryParameters['value'] ?? '',
        purpose: s.uri.queryParameters['purpose'] ?? 'signup',
      )),
    ],
  );
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._ref) {
    _sub = _ref.listen<AsyncValue<dynamic>>(authControllerProvider, (_, next) {
      value = next.valueOrNull;
    }, fireImmediately: true);
  }
  final Ref _ref;
  late final ProviderSubscription<AsyncValue<dynamic>> _sub;
  dynamic value;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
