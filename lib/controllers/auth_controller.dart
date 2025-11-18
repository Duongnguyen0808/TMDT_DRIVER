import 'dart:convert';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;

const String appBaseUrl = 'http://localhost:3000';

class AuthController extends GetxController {
  final box = GetStorage();
  RxBool loading = false.obs;

  String? get token => box.read('token');

  Future<bool> login(String email, String password) async {
    loading.value = true;
    final url = Uri.parse('$appBaseUrl/login');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    loading.value = false;
    if (res.statusCode == 200 || res.statusCode == 201) {
      final data = jsonDecode(res.body);
      final t = data['token'] ?? data['accessToken'] ?? '';
      if (t is String && t.isNotEmpty) {
        box.write('token', t);
        return true;
      }
    }
    return false;
  }

  void logout() {
    box.remove('token');
  }
}
