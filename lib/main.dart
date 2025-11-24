import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'views/login_page.dart';
import 'views/orders/orders_page.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'controllers/auth_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
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
    return GetMaterialApp(
      title: 'TMDT Shipper',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: home,
    );
  }
}
