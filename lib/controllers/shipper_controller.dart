import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/api_config.dart';

class ShipperController extends GetxController {
  final box = GetStorage();
  final loading = false.obs;

  String? get token => box.read('token');

  Future<String?> uploadImage(
    File file, {
    String folder = 'shipper_docs',
  }) async {
    final t = token;
    if (t == null || t.isEmpty) return null;
    final url = Uri.parse('$apiBaseUrl/api/upload/image');
    final request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer $t'
      ..fields['folder'] = folder
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final resp = await request.send();
    final body = await resp.stream.bytesToString();
    if (resp.statusCode == 200) {
      final data = jsonDecode(body);
      return data['secure_url'] ?? data['url'];
    }
    return null;
  }

  // Public upload (no auth token needed)
  Future<String?> uploadPublicImage(File file) async {
    final url = Uri.parse('$apiBaseUrl/api/upload/public/shipper-doc');
    final request = http.MultipartRequest('POST', url)
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final resp = await request.send();
    final body = await resp.stream.bytesToString();
    if (resp.statusCode == 200) {
      final data = jsonDecode(body);
      return data['secure_url'] ?? data['url'];
    } else {
      try {
        final data = jsonDecode(body);
        Get.snackbar(
          'Upload lỗi',
          data['message']?.toString() ?? 'Không rõ nguyên nhân',
        );
      } catch (_) {
        Get.snackbar('Upload lỗi', 'Status ${resp.statusCode}');
      }
      return null;
    }
  }

  // Public combined application (create user + application)
  Future<bool> publicApply({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String vehicleType,
    required String vehiclePlate,
    required String idFrontUrl,
    required String idBackUrl,
    required String driverLicenseUrl,
    required String vehicleRegUrl,
    required String selfieUrl,
    required String recaptchaToken,
  }) async {
    loading.value = true;
    final url = Uri.parse('$apiBaseUrl/api/shippers/public/apply');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'fullName': fullName,
        'phone': phone,
        'vehicleType': vehicleType,
        'vehiclePlate': vehiclePlate,
        'idFrontUrl': idFrontUrl,
        'idBackUrl': idBackUrl,
        'driverLicenseUrl': driverLicenseUrl,
        'vehicleRegUrl': vehicleRegUrl,
        'selfieUrl': selfieUrl,
        'recaptchaToken': recaptchaToken,
      }),
    );
    loading.value = false;
    if (res.statusCode == 201) {
      // Do NOT auto-login: store provisional signup token separately
      final data = jsonDecode(res.body);
      final t = data['token'];
      if (t is String && t.isNotEmpty) {
        box.write('signupToken', t); // user must perform explicit login
      }
      return true;
    } else {
      try {
        final data = jsonDecode(res.body);
        Get.snackbar(
          'Gửi hồ sơ lỗi',
          data['message']?.toString() ?? 'Không rõ nguyên nhân',
        );
      } catch (_) {
        Get.snackbar('Gửi hồ sơ lỗi', 'Status ${res.statusCode}');
      }
      return false;
    }
  }

  Future<bool> submitApplication({
    required String fullName,
    required String phone,
    required String vehicleType,
    required String vehiclePlate,
    required String idFrontUrl,
    required String idBackUrl,
    required String driverLicenseUrl,
    required String vehicleRegUrl,
    required String selfieUrl,
  }) async {
    final t = token;
    if (t == null || t.isEmpty) return false;
    loading.value = true;
    final url = Uri.parse('$apiBaseUrl/api/shippers/apply');
    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $t',
      },
      body: jsonEncode({
        'fullName': fullName,
        'phone': phone,
        'vehicleType': vehicleType,
        'vehiclePlate': vehiclePlate,
        'idFrontUrl': idFrontUrl,
        'idBackUrl': idBackUrl,
        'driverLicenseUrl': driverLicenseUrl,
        'vehicleRegUrl': vehicleRegUrl,
        'selfieUrl': selfieUrl,
      }),
    );
    loading.value = false;
    if (res.statusCode == 201 || res.statusCode == 200) {
      return true;
    } else {
      try {
        final data = jsonDecode(res.body);
        Get.snackbar(
          'Gửi hồ sơ lỗi',
          data['message']?.toString() ?? 'Không rõ nguyên nhân',
        );
      } catch (_) {
        Get.snackbar('Gửi hồ sơ lỗi', 'Status ${res.statusCode}');
      }
      return false;
    }
  }

  Future<Map<String, dynamic>?> getMyApplication() async {
    final t = token;
    if (t == null || t.isEmpty) return null;
    final url = Uri.parse('$apiBaseUrl/api/shippers/me/application');
    final res = await http.get(url, headers: {'Authorization': 'Bearer $t'});
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['data'] as Map<String, dynamic>;
    }
    return null;
  }

  final ImagePicker _picker = ImagePicker();
  Future<File?> pickImage(ImageSource source) async {
    final x = await _picker.pickImage(source: source, imageQuality: 80);
    if (x == null) return null;
    return File(x.path);
  }
}
