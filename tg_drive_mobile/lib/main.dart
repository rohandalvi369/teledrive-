import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
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

  await NotificationService().init();

  await Workmanager().initialize(
    backupCallbackDispatcher,
    isInDebugMode: false,
  );

  runApp(_AppWrapper());
}

class _AppWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TelegramService()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(
          create: (ctx) => FileService(ctx.read<TelegramService>()),
        ),
        Provider(create: (_) => ApiService()),
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
    final themeService = context.watch<ThemeService>();
    final telegram = context.watch<TelegramService>();

    return MaterialApp(
      title: 'TeleDrive',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: themeService.themeMode,
      home: telegram.isAuthenticated
          ? const DashboardPage()
          : const AuthFlow(),
    );
  }
}
