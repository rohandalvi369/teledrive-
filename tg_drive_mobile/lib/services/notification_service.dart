import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'backup_progress';
  static const String _channelName = 'Backup Progress';
  static const String _channelDesc = 'Shows auto-backup progress';

  static const int progressNotificationId = 1;
  static const int completionNotificationId = 2;
  static const int errorNotificationId = 3;

  Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(initSettings);
  }

  Future<void> _createChannel() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.low,
        ),
      );
    }
  }

  Future<void> showProgress({
    required int current,
    required int total,
    String currentFile = '',
    String folderName = '',
  }) async {
    await _createChannel();
    final maxProgress = total > 0 ? total : 1;
    final progress = total > 0 ? current : 0;

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: maxProgress,
      progress: progress,
      indeterminate: total == 0,
      ongoing: true,
      autoCancel: false,
    );
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final title = folderName.isNotEmpty ? 'Backing up $folderName' : 'Backup';
    final body = total > 0
        ? '$current / $total files'
        : 'Preparing...';

    await _plugin.show(
      progressNotificationId,
      title,
      currentFile.isNotEmpty ? '$body - $currentFile' : body,
      details,
    );
  }

  Future<void> showComplete({
    required int totalFiles,
    required int totalFolders,
  }) async {
    await _cancelProgress();
    const androidDetails = AndroidNotificationDetails(
      'backup_complete',
      'Backup Complete',
      channelDescription: 'Backup completed successfully',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _plugin.show(
      completionNotificationId,
      'Backup Complete',
      '$totalFiles files backed up across $totalFolders folder(s)',
      details,
    );
  }

  Future<void> showError(String error) async {
    await _cancelProgress();
    const androidDetails = AndroidNotificationDetails(
      'backup_error',
      'Backup Error',
      channelDescription: 'Backup encountered an error',
      importance: Importance.defaultImportance,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _plugin.show(
      errorNotificationId,
      'Backup Failed',
      error.length > 200 ? '${error.substring(0, 200)}...' : error,
      details,
    );
  }

  Future<void> _cancelProgress() async {
    await _plugin.cancel(progressNotificationId);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
