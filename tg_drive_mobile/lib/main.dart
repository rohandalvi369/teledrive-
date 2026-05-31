import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'services/telegram_service.dart';
import 'services/file_service.dart';
import 'services/theme_service.dart';
import 'services/api_service.dart';
import 'services/backup_service.dart';
import 'services/trash_service.dart';
import 'services/favorites_service.dart';
import 'services/notification_service.dart';
import 'services/backup_worker.dart';
import 'theme/app_theme.dart';
import 'pages/auth/auth_flow.dart';
import 'pages/dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Unhandled error: $error\n$stack');
    return true;
  };

  ErrorWidget.builder = (details) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Error: ${details.exception}',
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  };

  try {
    await dotenv.load(fileName: '.env');
    debugPrint('DOTENV: loaded, API_ID=${dotenv.env['API_ID']}');
  } catch (e) {
    debugPrint('DOTENV: load failed: $e');
  }

  await NotificationService().init();

  await Workmanager().initialize(
    backupCallbackDispatcher,
    isInDebugMode: false,
  );

  final prefs = await SharedPreferences.getInstance();
  final savedUrl = prefs.getString('backup_api_url');

  runApp(_AppWrapper(savedApiUrl: savedUrl));
}

class _AppWrapper extends StatelessWidget {
  final String? savedApiUrl;
  const _AppWrapper({this.savedApiUrl});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TelegramService()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(
          create: (ctx) => FileService(ctx.read<TelegramService>()),
        ),
        Provider(create: (_) => ApiService(baseUrl: savedApiUrl ?? 'http://192.168.1.100:3000')),
        ChangeNotifierProvider(
          create: (ctx) => BackupService(ctx.read<ApiService>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => TrashService(ctx.read<ApiService>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => FavoritesService(ctx.read<ApiService>()),
        ),
      ],
      child: const TeleDriveApp(),
    );
  }
}

class TeleDriveApp extends StatelessWidget {
  const TeleDriveApp({super.key});

  @override
  Widget build(BuildContext context) {
    final telegram = context.watch<TelegramService>();

    return MaterialApp(
      title: 'TeleDrive',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: telegram.isAuthenticated
          ? const DashboardPage()
          : const AuthFlow(),
    );
  }
}
