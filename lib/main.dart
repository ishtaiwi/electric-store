import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';

import 'core/di/injection_container.dart' as di;
import 'core/theme/app_theme.dart';
import 'core/services/localization_service.dart';
import 'core/database/database_helper.dart';
import 'core/database/test_database_generator.dart';
import 'core/utils/keyboard_error_handler.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/dashboard/presentation/pages/dashboard_page.dart';

/// Set to true to use test database instead of production d.db
const bool useTestDatabase = bool.fromEnvironment('USE_TEST_DB', defaultValue: false);

/// Set to true to generate test data on startup
const bool generateTestData = bool.fromEnvironment('GENERATE_TEST_DATA', defaultValue: false);

void main() async {
  // Catch all uncaught errors to prevent crashes
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Set global error handler for Flutter framework errors
    FlutterError.onError = handleFlutterFrameworkError;

    // Initialize FFI for desktop
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // Generate test data if requested
    if (generateTestData) {
      debugPrint('Generating test database...');
      final generator = TestDatabaseGenerator();
      final path = await generator.generateTestDatabase(Directory.current.path);
      debugPrint('Test database generated at: $path');
      debugPrint('Run with --dart-define=USE_TEST_DB=true to use it');
    }

    // Use test database if flag is set
    if (useTestDatabase) {
      debugPrint('Using test database mode');
      DatabaseHelper.useTestDatabase = true;
    }

    // Initialize dependencies
    await di.init();
    
    // Pre-warm database connection in background (don't await - let it happen while UI loads)
    _prewarmDatabase();

    runApp(const ElectricalStoreApp());
  }, (error, stackTrace) {
    // Global error handler — catches all uncaught async errors
    debugPrint('Uncaught error: $error');
    debugPrint('Stack trace: $stackTrace');
  });
}

/// Pre-warm the database connection so it's ready when user logs in
void _prewarmDatabase() {
  // Fire and forget - this runs in background while login screen shows
  di.sl<DatabaseHelper>().database.then((_) {
    debugPrint('Database connection pre-warmed');
  }).catchError((e) {
    debugPrint('Database prewarm error: $e');
  });
}

class ElectricalStoreApp extends StatefulWidget {
  const ElectricalStoreApp({super.key});

  @override
  State<ElectricalStoreApp> createState() => _ElectricalStoreAppState();
}

class _ElectricalStoreAppState extends State<ElectricalStoreApp>
    with WidgetsBindingObserver {
  final _localizationService = LocalizationService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _localizationService.addListener(_onLocaleChange);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _localizationService.removeListener(_onLocaleChange);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      HardwareKeyboard.instance.syncKeyboardState();
    }
  }

  void _onLocaleChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => di.sl<AuthBloc>()),
      ],
      child: MaterialApp(
        title: _localizationService.get('appName'),
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        locale: _localizationService.locale,
        supportedLocales: const [
          Locale('en'),
          Locale('ar'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          return Directionality(
            textDirection: _localizationService.textDirection,
            child: child!,
          );
        },
        home: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is AuthAuthenticated) {
              return const DashboardPage();
            }
            return const LoginPage();
          },
        ),
      ),
    );
  }
}
