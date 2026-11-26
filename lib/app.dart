import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/app_controller.dart';
import 'domain/models.dart';
import 'router/app_router.dart';
import 'ui/screens/age_gate_page.dart';
import 'ui/theme/dt_theme.dart';

class SillyTavernApp extends ConsumerWidget {
  const SillyTavernApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Capture the platform entry route before the temporary loading app can
    // consume/reset the browser URL. Keep the same router for the full session.
    final router = ref.watch(appRouterProvider);
    final state = ref.watch(appControllerProvider);
    final themeMode = switch (state.data.settings.themeMode) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'SillyTavern APP',
      routerConfig: router,
      theme: DtTheme.light(),
      darkTheme: DtTheme.dark(),
      themeMode: themeMode,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      localizationsDelegates: const [
        FLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final page = state.loading
            ? const _LoadingPage()
            : !state.data.settings.ageConfirmed
            ? Navigator(
                initialRoute: '/',
                onGenerateRoute: (settings) => MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => const AgeGatePage(),
                ),
              )
            : child;
        final content = MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.15,
            ),
          ),
          child: _foruiBuilder(context, page),
        );
        if (!kIsWeb || media.size.width < 720) return content;

        final dark = Theme.of(context).brightness == Brightness.dark;
        final width = media.size.width.clamp(440, 560).toDouble();
        final verticalInset = media.size.height >= 760 ? 18.0 : 0.0;
        final appHeight = media.size.height - verticalInset * 2;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [Color(0xFF111318), Color(0xFF191C23)]
                  : const [Color(0xFFE9EBF0), Color(0xFFF5F6F9)],
            ),
          ),
          child: Center(
            child: SizedBox(
              width: width,
              height: appHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    verticalInset == 0 ? 0 : 12,
                  ),
                  boxShadow: DtShadows.floating(dark),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    verticalInset == 0 ? 0 : 12,
                  ),
                  child: MediaQuery(
                    data: media.copyWith(
                      size: Size(width, appHeight),
                      textScaler: media.textScaler.clamp(
                        minScaleFactor: 0.9,
                        maxScaleFactor: 1.15,
                      ),
                    ),
                    child: _foruiBuilder(context, page),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Widget _foruiBuilder(BuildContext context, Widget? child) => FTheme(
  data: Theme.of(context).brightness == Brightness.dark
      ? FThemes.zinc.dark
      : FThemes.zinc.light,
  child: child ?? const SizedBox.shrink(),
);

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? const [DtColors.darkElevated, DtColors.darkBg]
                : const [DtColors.canvasSoft, DtColors.canvas],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 54,
                height: 54,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(height: 18),
              Text('正在进入梦境', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
