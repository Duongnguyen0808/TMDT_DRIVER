import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:jwt_decode/jwt_decode.dart';

import 'controllers/auth_controller.dart';
import 'firebase_options.dart';
import 'services/push_notification_service.dart';
import 'views/login_page.dart';
import 'views/orders/orders_page.dart';

bool _backgroundHandlerRegistered = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!_backgroundHandlerRegistered) {
    FirebaseMessaging.onBackgroundMessage(
      shipperFirebaseMessagingBackgroundHandler,
    );
    _backgroundHandlerRegistered = true;
  }
  await GetStorage.init();
  await PushNotificationService.init();
  // Đăng ký AuthController sớm để mọi màn hình (kể cả khi bỏ qua login) đều có thể dùng
  Get.put(AuthController(), permanent: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final box = GetStorage();
    final token = box.read('token');
    Widget home = const LoginPage();
    if (token is String && token.isNotEmpty) {
      try {
        final decoded = Jwt.parseJwt(token);
        final userType = decoded['userType'];
        if (userType == 'Driver') {
          home = const OrdersPage();
        } else {
          // Not a driver yet -> force login flow
          home = const LoginPage();
        }
      } catch (_) {
        home = const LoginPage();
      }
    }
    final baseScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF005DFF),
      brightness: Brightness.light,
    );
    final baseTextTheme = ThemeData.light().textTheme;

    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TMDT Shipper',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: baseScheme,
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        textTheme: baseTextTheme.apply(
          fontFamily: 'Roboto',
          bodyColor: const Color(0xFF1C1F26),
          displayColor: const Color(0xFF1C1F26),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: baseScheme.primary,
          centerTitle: false,
          titleTextStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF121418),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            backgroundColor: baseScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: Colors.white,
          selectedColor: baseScheme.primaryContainer,
          secondarySelectedColor: baseScheme.primary,
          labelStyle: const TextStyle(
            color: Color(0xFF1C1F26),
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: baseScheme.primary, width: 1.5),
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
        splashFactory: InkSparkle.splashFactory,
      ),
      home: home,
    );
  }
}
