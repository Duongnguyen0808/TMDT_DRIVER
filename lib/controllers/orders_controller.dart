import 'dart:convert';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;

const String appBaseUrl = 'http://localhost:3000';

class DriverOrdersController extends GetxController {
  final box = GetStorage();
  RxList<Map<String, dynamic>> orders = <Map<String, dynamic>>[].obs;
  RxBool loading = false.obs;
  DateTime? lastFetch;

  String? get token => box.read('token');

  Map<String, String> _headers() => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  @override
  void onInit() {
    super.onInit();
    _loadCached();
  }

  void _loadCached() {
    final cached = box.read('driver.orders.cache');
    if (cached is String && cached.isNotEmpty) {
      try {
        final list = jsonDecode(cached) as List;
        orders.assignAll(list.map((e) => Map<String, dynamic>.from(e)));
      } catch (_) {}
    }
  }

  void _cacheCurrent() {
    try {
      box.write('driver.orders.cache', jsonEncode(orders));
      lastFetch = DateTime.now();
    } catch (_) {}
  }

  Future<void> fetchMyOrders({bool force = false}) async {
    if (!force && lastFetch != null) {
      final age = DateTime.now().difference(lastFetch!);
      if (age < const Duration(seconds: 20) && orders.isNotEmpty) {
        return; // Throttle frequent refreshes
      }
    }
    loading.value = true;
    final url = Uri.parse('$appBaseUrl/api/drivers/my/orders');
    final res = await http.get(url, headers: _headers());
    loading.value = false;
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body)['data'] ?? [];
      orders.assignAll(data.map((e) => Map<String, dynamic>.from(e)));
      _cacheCurrent();
    }
  }

  Future<bool> updateOrderStatus(String orderId, String status) async {
    final url = Uri.parse('$appBaseUrl/api/drivers/my/orders/$orderId/status');
    final res = await http.patch(
      url,
      headers: _headers(),
      body: jsonEncode({'status': status}),
    );
    return res.statusCode == 200;
  }
}
