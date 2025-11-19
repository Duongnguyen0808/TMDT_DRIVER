import 'dart:convert';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AuthController extends GetxController {
  final box = GetStorage();
  RxBool loading = false.obs;

  String? get token => box.read('token');

  Future<bool> login(String email, String password) async {
    final emailNorm = email.trim().toLowerCase();
    loading.value = true;
    // Backend mounts AuthRoute at root ('/'), so login endpoint is '/login'
    // Try primary path then fallback to /api/auth/login if ever remounted.
    final primaryUrl = Uri.parse('$apiBaseUrl/login');
    final fallbackUrl = Uri.parse('$apiBaseUrl/api/auth/login');
    late http.Response res;
    try {
      res = await http.post(
        primaryUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': emailNorm, 'password': password}),
      );
      if (res.statusCode == 404) {
        // Attempt fallback path automatically
        res = await http.post(
          fallbackUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': emailNorm, 'password': password}),
        );
      }
    } catch (e) {
      loading.value = false;
      Get.snackbar('Lỗi mạng', e.toString());
      return false;
    }
    loading.value = false;
    try {
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data is Map) {
        final t =
            data['userToken'] ?? data['token'] ?? data['accessToken'] ?? '';
        if (t is String && t.isNotEmpty) {
          box.write('token', t);
          return true;
        } else {
          Get.snackbar('Thiếu token', 'Phản hồi không có userToken');
        }
      } else {
        final msg =
            (data is Map ? data['message'] : null) ?? 'Đăng nhập thất bại';
        Get.snackbar('Lỗi', msg.toString());
      }
    } catch (_) {
      Get.snackbar('Lỗi', 'Không phân tích được phản hồi (${res.statusCode})');
    }
    return false;
  }

  void logout() {
    box.remove('token');
  }
}
