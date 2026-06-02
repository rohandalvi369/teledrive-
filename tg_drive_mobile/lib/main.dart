import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'services/telegram_service.dart';
import 'services/file_service.dart';
import 'services/theme_service.dart';
import 'services/api_service.dart';
import 'services/backup_service.dart';
import 'services/trash_service.dart';
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

  if (Platform.isAndroid) {
    try {
      await NotificationService().init();
    } catch (e) {
      debugPrint('Failed to init notifications: $e');
    }

    try {
      await Workmanager().initialize(
        backupCallbackDispatcher,
        isInDebugMode: false,
      );
    } catch (e) {
      debugPrint('Failed to init workmanager: $e');
    }
  }

  final prefs = await SharedPreferences.getInstance();
  final savedUrl = prefs.getString('backup_api_url');

  runApp(_AppWrapper(savedApiUrl: savedUrl));
}

class _AppWrapper extends StatelessWidget {
  final String? savedApiUrl;
  const _AppWrapper({super.key, this.savedApiUrl});

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
      ],
      child: const TeleDriveApp(),
    );
  }
}

class TeleDriveApp extends StatefulWidget {
  const TeleDriveApp({super.key});

  @override
  State<TeleDriveApp> createState() => _TeleDriveAppState();
}

class _TeleDriveAppState extends State<TeleDriveApp> {
  @override
  Widget build(BuildContext context) {
    final telegram = context.watch<TelegramService>();
    final themeService = context.watch<ThemeService>();

    return MaterialApp(
      title: 'TeleDrive',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeService.themeMode,
      home: telegram.isAuthenticated
          ? const DashboardPage()
          : const AuthFlow(),
    );
  }}
