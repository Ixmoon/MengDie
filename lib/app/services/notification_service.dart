import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 为通知服务创建 Riverpod Provider
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Android 初始化设置
    // 注意：'@mipmap/ic_launcher' 是安卓项目中的默认图标路径。
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Windows 初始化设置
    const WindowsInitializationSettings initializationSettingsWindows =
        WindowsInitializationSettings(
      appName: 'Meng-Die',
      appUserModelId: 'Meng-Die',
      guid: 'a2b2a7d2-3e7f-4f1a-a8a0-a0b1a2a3a4a5',
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      windows: initializationSettingsWindows,
    );

    // 初始化插件
    await _notificationsPlugin.initialize(initializationSettings);

    // 为 Android 创建一个通知渠道。这是 Android 8.0+ 的要求。
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // 渠道 ID
      'High Importance Notifications', // 渠道名称
      description: 'This channel is used for important notifications.', // 渠道描述
      importance: Importance.max,
    );

    // 注册渠道
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// 如果是 Android 平台，则请求通知权限
  Future<void> requestAndroidPermission() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }
    }
  }

  /// 显示一个系统通知
  ///
  /// [title] - 通知标题
  /// [body] - 通知正文
  /// [largeIconBase64] - (可选) 用于在通知左侧显示大图标的 Base64 字符串
  Future<void> showNotification(
    String title,
    String body, {
    String? largeIconBase64,
  }) async {
    // Android 平台特定的通知详情
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true, // 显示通知时间戳
      largeIcon: largeIconBase64 != null
          ? ByteArrayAndroidBitmap.fromBase64String(largeIconBase64)
          : null,
    );

    // Windows 平台特定的通知详情
    const WindowsNotificationDetails windowsPlatformChannelSpecifics =
        WindowsNotificationDetails();

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      windows: windowsPlatformChannelSpecifics,
    );

    // 显示通知
    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.toSigned(31), // 使用时间戳作为唯一ID
      title,
      body,
      platformChannelSpecifics,
    );
  }
}