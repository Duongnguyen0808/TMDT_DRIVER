import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../controllers/auth_controller.dart';
import 'orders/orders_page.dart';
import 'widgets/shipper_appbar.dart';
import 'registration/shipper_registration_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final auth = Get.put(AuthController());
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    GetStorage.init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ShipperAppBar(title: 'Đăng nhập tài xế'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Quick access to shipper registration without login
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Get.to(() => const ShipperRegistrationPage()),
                icon: const Icon(Icons.motorcycle),
                label: const Text('Đăng ký Shipper'),
              ),
            ),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passCtrl,
              decoration: const InputDecoration(labelText: 'Mật khẩu'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            Obx(
              () => ElevatedButton(
                onPressed: auth.loading.value
                    ? null
                    : () async {
                        final ok = await auth.login(
                          emailCtrl.text.trim(),
                          passCtrl.text.trim(),
                        );
                        if (ok) {
                          Get.offAll(() => const OrdersPage());
                        } else {
                          Get.snackbar('Lỗi', 'Đăng nhập thất bại');
                        }
                      },
                child: auth.loading.value
                    ? const CircularProgressIndicator()
                    : const Text('Đăng nhập'),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      // Removed bottom nag requiring prior login; registration open publicly.
    );
  }
}
