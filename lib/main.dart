import 'package:flutter/foundation.dart';
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
import 'core/providers/locale_provider.dart';
import 'core/providers/connectivity_provider.dart';
import 'core/services/offline_service.dart';
import 'core/services/thermal_printer_service.dart';
import 'core/theme/app_theme.dart';
import 'features/sales/services/offline_sales_queue.dart';
import 'features/accounting/providers/accounting_provider.dart';
import 'features/hr/providers/hr_provider.dart';
import 'firebase_options.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // App Check: require proper configuration in release builds. Allow debug providers only in non-release.
  try {
    const recaptchaKey = String.fromEnvironment(
      'RECAPTCHA_SITE_KEY',
      defaultValue: '',
    );
    // In release mode require a valid recaptcha key and fail fast if missing so production cannot run without App Check
    if (kReleaseMode) {
      if (recaptchaKey.isEmpty) {
        // Fail startup in production to avoid running without App Check
        throw FlutterError('RECAPTCHA_SITE_KEY must be provided in production for App Check to be enabled.');
      }
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.appAttest,
        webProvider: ReCaptchaV3Provider(recaptchaKey),
      );
    } else {
      // Non-release (dev/test) - use debug providers to avoid developer friction
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
        webProvider: ReCaptchaV3Provider('6Ldb7qspAAAAAMj6Q5tU6tE-6-88888888888888'), // debug fallback
      );
    }
  } catch (e) {
    // In non-release builds, warn but continue. In release builds the above throws and prevents startup.
    debugPrint('App Check initialization warning: $e');
  }

  await Hive.initFlutter();
  await OfflineService.init();
  await ThermalPrinterService.init();
  final themeProvider = await ThemeProvider.create();
  runApp(HardwareOSApp(themeProvider: themeProvider));
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
        ChangeNotifierProxyProvider<AuthProvider, AccountingProvider>(
          create: (_) => AccountingProvider(businessId: ''),
          update: (_, auth, acc) {
            if (auth.businessId != null && auth.businessId != acc?.businessId) {
              return AccountingProvider(businessId: auth.businessId!);
            }
            return acc ?? AccountingProvider(businessId: '');
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, HrProvider>(
          create: (_) => HrProvider(businessId: ''),
          update: (_, auth, hr) {
            if (auth.businessId != null && auth.businessId != hr?.businessId) {
              return HrProvider(businessId: auth.businessId!);
            }
            return hr ?? HrProvider(businessId: '');
          },
        ),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => OfflineSalesQueue()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: Builder(
        builder: (context) {
          _router ??= AppRouter.createRouter(context);
          return Consumer2<ThemeProvider, LocaleProvider>(
            builder: (context, themeProvider, localeProvider, child) {
              return MaterialApp.router(
                title: 'HardwareOS',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeProvider.themeMode,
                locale: localeProvider.locale,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [
                  Locale('en'), // English
                  Locale('sw'), // Swahili
                  Locale('sw', 'KE'), // Sheng
                ],
                routerConfig: _router!,
              );
            },
          );
        },
      ),
    );
  }
}
