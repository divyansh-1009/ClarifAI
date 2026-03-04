import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'services/auth_provider.dart';
import 'services/api_service.dart';
import 'widgets/app_theme.dart';
import 'pages/splash_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait orientations for a consistent mobile experience
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Transparent status bar with dark icons (adapts to theme)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light, // iOS
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ClarifAIApp());
}

class ClarifAIApp extends StatelessWidget {
  const ClarifAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Core API service — single instance shared across the app
        Provider<ApiService>(
          create: (_) => ApiService(),
        ),

        // Auth state — depends on ApiService
        ChangeNotifierProxyProvider<ApiService, AuthProvider>(
          create: (ctx) => AuthProvider(
            apiService: ctx.read<ApiService>(),
          ),
          update: (ctx, api, previous) =>
              previous ?? AuthProvider(apiService: api),
        ),
      ],
      child: const _AppView(),
    );
  }
}

class _AppView extends StatefulWidget {
  const _AppView();

  @override
  State<_AppView> createState() => _AppViewState();
}

class _AppViewState extends State<_AppView> with WidgetsBindingObserver {
  // Track system brightness for status bar icon adaptation
  late Brightness _brightness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    final newBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    if (newBrightness != _brightness) {
      setState(() => _brightness = newBrightness);
      _updateSystemUI(newBrightness);
    }
  }

  void _updateSystemUI(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor:
            isDark ? AppColors.darkSurface : AppColors.surface,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // ── App metadata ─────────────────────────────
      title: 'ClarifAI',
      debugShowCheckedModeBanner: false,

      // ── Themes ───────────────────────────────────
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,

      // ── Entry point ──────────────────────────────
      home: const SplashPage(),

      // ── Global builder: applies safe-area background ─
      builder: (context, child) {
        // Ensure text scale factor doesn't go beyond readable limits
        final mediaQuery = MediaQuery.of(context);
        final clampedTextScale =
            mediaQuery.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.15);
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: clampedTextScale),
          child: child ?? const SizedBox.shrink(),
        );
      },

      // ── Scroll behaviour ──────────────────────────
      scrollBehavior: const _AppScrollBehaviour(),
    );
  }
}

// ─────────────────────────────────────────────
//  Custom scroll behaviour
//  • Keeps default glow on Android
//  • Removes overscroll glow on iOS for a native feel
// ─────────────────────────────────────────────

class _AppScrollBehaviour extends ScrollBehavior {
  const _AppScrollBehaviour();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    switch (getPlatform(context)) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const BouncingScrollPhysics();
      default:
        return const ClampingScrollPhysics();
    }
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Use stretching overscroll on Android 12+ (Material You)
    switch (getPlatform(context)) {
      case TargetPlatform.android:
        return StretchingOverscrollIndicator(
          axisDirection: details.direction,
          child: child,
        );
      default:
        return child;
    }
  }
}
