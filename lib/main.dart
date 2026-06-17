import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/router/app_router.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/business_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/connectivity_provider.dart';
import 'core/services/offline_service.dart';
import 'core/services/failed_sync_service.dart';
import 'core/theme/app_theme.dart';
import 'features/sales/services/offline_sales_queue.dart';
import 'firebase_options.dart';

/// Set this to your Sentry DSN before release.
/// For development, leave null to disable Sentry.
const String? _sentryDsn = null;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Sentry for crash/error monitoring
  if (_sentryDsn != null) {
    // In production, use the sentry_flutter package instead of manual HTTP.
    // For now, we forward unhandled errors to console for awareness.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      // Log to Sentry via Cloud Function or direct HTTP
      _reportErrorToSentry(details.exception, details.stack);
    };
    ui.PlatformDispatcher.instance.onError = (error, stack) {
      _reportErrorToSentry(error, stack);
      return true;
    };
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable Firebase App Check for abuse protection
  // In production, use:
  //   Android: AndroidProvider.playIntegrity (requires Play Integrity API)
  //   iOS:     AppleProvider.deviceCheck or AppleProvider.appAttest
  //   Web:     ReCaptchaV3Provider('your-recaptcha-site-key')
  // For development, debug provider allows emulator traffic:
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
    webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
  );

  await Hive.initFlutter();
  await OfflineService.init();
  await FailedSyncService.init();
  final themeProvider = await ThemeProvider.create();
  runApp(HardwareOSApp(themeProvider: themeProvider));
}

/// Forwards crash reports to Sentry via HTTP (lightweight without native SDK).
/// Replace with sentry_flutter SDK when DSN is configured.
void _reportErrorToSentry(Object error, StackTrace? stack) {
  if (_sentryDsn == null) return;
  // Minimal HTTP transport — or use sentry_flutter package directly.
  // This is a placeholder that avoids adding the heavy native Sentry SDK
  // until the DSN is actually configured.
  debugPrint('[Sentry] Error: $error');
  debugPrint('[Sentry] Stack: $stack');
}

class HardwareOSApp extends StatefulWidget {
  final ThemeProvider themeProvider;
  const HardwareOSApp({required this.themeProvider, super.key});

  @override
  State<HardwareOSApp> createState() => _HardwareOSAppState();
}

class _HardwareOSAppState extends State<HardwareOSApp> {
  GoRouter? _router;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.themeProvider),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, BusinessProvider>(
          create: (_) => BusinessProvider(),
          update: (_, auth, biz) => biz!..updateFromAuth(auth),
        ),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => FailedSyncService()),
        ChangeNotifierProvider(create: (_) => OfflineSalesQueue()),
      ],
      child: Builder(
        builder: (context) {
          _router ??= AppRouter.createRouter(context);
          return Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return MaterialApp.router(
                title: 'HardwareOS',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeProvider.themeMode,
                routerConfig: _router!,
              );
            },
          );
        },
      ),
    );
  }
}
