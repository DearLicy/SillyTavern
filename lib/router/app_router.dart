import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ui/screens/about_page.dart';
import '../ui/screens/backup_page.dart';
import '../ui/screens/character_detail_page.dart';
import '../ui/screens/character_cards_page.dart';
import '../ui/screens/character_editor_page.dart';
import '../ui/screens/chat_page.dart';
import '../ui/screens/chat_data_page.dart';
import '../ui/screens/chat_history_page.dart';
import '../ui/screens/consent_page.dart';
import '../ui/screens/contacts_page.dart';
import '../ui/screens/director_page.dart';
import '../ui/screens/memory_page.dart';
import '../ui/screens/messages_page.dart';
import '../ui/screens/moments_page.dart';
import '../ui/screens/persona_editor_page.dart';
import '../ui/screens/personas_page.dart';
import '../ui/screens/profile_edit_page.dart';
import '../ui/screens/prompt_rules_page.dart';
import '../ui/screens/provider_page.dart';
import '../ui/screens/safety_page.dart';
import '../ui/screens/scene_page.dart';
import '../ui/screens/settings_page.dart';
import '../ui/screens/tool_settings_page.dart';
import '../ui/screens/world_books_page.dart';
import '../ui/shell/root_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/messages',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            RootShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/messages',
                builder: (context, state) => const MessagesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/contacts',
                builder: (context, state) => const ContactsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/moments',
                builder: (context, state) => const MomentsPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/chat/:threadId',
        builder: (context, state) =>
            ChatPage(threadId: state.pathParameters['threadId']!),
      ),
      GoRoute(
        path: '/chat-data/:threadId',
        builder: (context, state) =>
            ChatDataPage(threadId: state.pathParameters['threadId']!),
      ),
      GoRoute(
        path: '/chat-history/:threadId',
        builder: (context, state) =>
            ChatHistoryPage(threadId: state.pathParameters['threadId']!),
      ),
      GoRoute(
        path: '/character-cards',
        builder: (context, state) => const CharacterCardsPage(),
      ),
      GoRoute(
        path: '/character/new',
        builder: (context, state) =>
            const CharacterEditorPage(characterId: 'new'),
      ),
      GoRoute(
        path: '/character-editor/:characterId',
        builder: (context, state) => CharacterEditorPage(
          characterId: state.pathParameters['characterId']!,
        ),
      ),
      GoRoute(
        path: '/character/:characterId',
        builder: (context, state) => CharacterDetailPage(
          characterId: state.pathParameters['characterId']!,
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileEditPage(),
      ),
      GoRoute(
        path: '/personas',
        builder: (context, state) => const PersonasPage(),
      ),
      GoRoute(
        path: '/persona/:personaId',
        builder: (context, state) =>
            PersonaEditorPage(personaId: state.pathParameters['personaId']!),
      ),
      GoRoute(
        path: '/memory/:relationshipId',
        builder: (context, state) =>
            MemoryPage(relationshipId: state.pathParameters['relationshipId']!),
      ),
      GoRoute(
        path: '/director/:relationshipId',
        builder: (context, state) => DirectorPage(
          relationshipId: state.pathParameters['relationshipId']!,
        ),
      ),
      GoRoute(
        path: '/consent/:relationshipId',
        builder: (context, state) => ConsentPage(
          relationshipId: state.pathParameters['relationshipId']!,
        ),
      ),
      GoRoute(
        path: '/scene/:relationshipId',
        builder: (context, state) =>
            ScenePage(relationshipId: state.pathParameters['relationshipId']!),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/provider',
        builder: (context, state) => const ProviderPage(),
      ),
      GoRoute(
        path: '/prompts',
        builder: (context, state) => const PromptRulesPage(),
      ),
      GoRoute(
        path: '/tools',
        builder: (context, state) => const ToolSettingsPage(),
      ),
      GoRoute(
        path: '/world-books',
        builder: (context, state) => const WorldBooksPage(),
      ),
      GoRoute(
        path: '/world-book/:bookId',
        builder: (context, state) =>
            WorldBookEditorPage(bookId: state.pathParameters['bookId']!),
      ),
      GoRoute(
        path: '/world-info/:entryId',
        builder: (context, state) =>
            WorldInfoEditorPage(entryId: state.pathParameters['entryId']!),
      ),
      GoRoute(path: '/safety', builder: (context, state) => const SafetyPage()),
      GoRoute(path: '/backup', builder: (context, state) => const BackupPage()),
      GoRoute(path: '/about', builder: (context, state) => const AboutPage()),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('页面不存在')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off_outlined, size: 48),
              const SizedBox(height: 14),
              Text('找不到页面：${state.uri.path}', textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => context.go('/messages'),
                child: const Text('回到消息'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
});
