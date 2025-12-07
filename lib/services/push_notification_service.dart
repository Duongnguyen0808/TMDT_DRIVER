import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../firebase_options.dart';

final FlutterLocalNotificationsPlugin shipperLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _shipperAndroidChannel =
    AndroidNotificationChannel(
      'shipper_high_importance',
      'Thông báo shipper',
      description: 'Kênh hiển thị thông báo đơn hàng/thu nhập quan trọng.',
      importance: Importance.max,
    );

@pragma('vm:entry-point')
Future<void> shipperFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Khi app ở trạng thái background, FCM tự hiển thị notification nếu payload
  // có trường `notification`. Không cần xử lý thêm ở đây.
}

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final GetStorage _box = GetStorage();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _configureLocalNotifications();
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    await _requestPermissions();
    await _cacheInitialToken();

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
    _messaging.onTokenRefresh.listen((token) async {
      await _persistToken(token);
    });

    _box.listenKey('token', (_) {
      syncTokenWithBackend();
    });
  }

  static Future<void> _configureLocalNotifications() async {
    if (!kIsWeb) {
      await shipperLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_shipperAndroidChannel);
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await shipperLocalNotificationsPlugin.initialize(initializationSettings);
  }

  static Future<void> _requestPermissions() async {
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
    } catch (_) {
      // Người dùng có thể từ chối, tiếp tục chạy app bình thường.
    }
  }

  static Future<void> _cacheInitialToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _persistToken(token);
      }
    } catch (_) {}
  }

  static Future<void> _persistToken(String token) async {
    final current = _box.read('fcmToken');
    if (current != token) {
      await _box.write('fcmToken', token);
    }
    await syncTokenWithBackend();
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'Thông báo';
    final body = notification?.body ?? message.data['body'] ?? '';

    if (!kIsWeb) {
      final androidDetails = AndroidNotificationDetails(
        _shipperAndroidChannel.id,
        _shipperAndroidChannel.name,
        channelDescription: _shipperAndroidChannel.description,
        importance: Importance.max,
        priority: Priority.high,
        icon: notification?.android?.smallIcon ?? '@mipmap/ic_launcher',
      );
      const iosDetails = DarwinNotificationDetails();
      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      await shipperLocalNotificationsPlugin.show(
        notification.hashCode,
        title,
        body,
        details,
        payload: jsonEncode(message.data),
      );
    }
  }

  static void _handleOpenedMessage(RemoteMessage message) {
    // TODO: Có thể điều hướng đến trang chi tiết đơn hàng nếu cần.
  }

  static Future<void> syncTokenWithBackend() async {
    final authToken = _box.read('token');
    final fcmToken = _box.read('fcmToken');
    if (authToken is! String || authToken.isEmpty) return;
    if (fcmToken is! String || fcmToken.isEmpty) return;

    final projectId = Firebase.apps.isNotEmpty
        ? Firebase.app().options.projectId ??
              DefaultFirebaseOptions.currentPlatform.projectId
        : DefaultFirebaseOptions.currentPlatform.projectId;

    final payload = jsonEncode({'fcmToken': fcmToken, 'projectId': projectId});

    try {
      await http.post(
        Uri.parse('$apiBaseUrl/api/users/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: payload,
      );
      await _box.write('fcmSyncedAt', DateTime.now().toIso8601String());
    } catch (_) {
      // Giữ im lặng, sẽ thử lại ở lần kế tiếp.
    }
  }
}
