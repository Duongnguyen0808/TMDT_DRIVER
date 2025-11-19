import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

// Use same base as api_config; adjust for environment (emulator vs device)
import '../config/api_config.dart';

const String appBaseUrl =
    apiBaseUrl; // previously hardcoded localhost:3000 causing connection refused

class DriverOrdersController extends GetxController {
  final box = GetStorage();
  RxList<Map<String, dynamic>> orders = <Map<String, dynamic>>[].obs;
  RxList<Map<String, dynamic>> availableOrders = <Map<String, dynamic>>[].obs;
  RxBool loading = false.obs;
  RxBool loadingAvailable = false.obs;
  DateTime? lastFetch;
  DateTime? lastAvailableFetch;
  Timer? _locationTimer;
  String? _activeDeliveringOrderId;

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

  Future<void> fetchAvailableOrders({bool force = false}) async {
    if (!force && lastAvailableFetch != null) {
      final age = DateTime.now().difference(lastAvailableFetch!);
      if (age < const Duration(seconds: 15) && availableOrders.isNotEmpty) {
        return;
      }
    }
    loadingAvailable.value = true;
    final url = Uri.parse('$appBaseUrl/api/drivers/available/orders');
    final res = await http.get(url, headers: _headers());
    loadingAvailable.value = false;
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body)['data'] ?? [];
      availableOrders.assignAll(data.map((e) => Map<String, dynamic>.from(e)));
      lastAvailableFetch = DateTime.now();
    }
  }

  Future<bool> claimOrder(String orderId) async {
    final url = Uri.parse('$appBaseUrl/api/drivers/orders/$orderId/claim');
    final res = await http.post(url, headers: _headers());
    if (kDebugMode)
      print(
        '[ClaimOrder] id=$orderId status=${res.statusCode} body=${_safeBody(res.body)}',
      );
    if (res.statusCode == 200) {
      // refresh both lists
      await fetchMyOrders(force: true);
      await fetchAvailableOrders(force: true);
      return true;
    }
    return false;
  }

  Future<bool> markDelivered(String orderId) async {
    final ok = await updateOrderStatus(orderId, 'Delivered');
    if (ok) {
      await fetchMyOrders(force: true);
      _stopLocationUpdates(orderIdIfMatches: orderId);
    }
    return ok;
  }

  Future<void> startLocationUpdates(String orderId) async {
    // If already tracking another order, stop it
    _stopLocationUpdates();
    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) return;
    _activeDeliveringOrderId = orderId;
    _locationTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        await updateDriverLocation(orderId, pos.latitude, pos.longitude);
      } catch (_) {}
    });
  }

  void _stopLocationUpdates({String? orderIdIfMatches}) {
    if (orderIdIfMatches != null &&
        _activeDeliveringOrderId != orderIdIfMatches)
      return;
    _locationTimer?.cancel();
    _locationTimer = null;
    _activeDeliveringOrderId = null;
  }

  Future<bool> updateDriverLocation(
    String orderId,
    double lat,
    double lng,
  ) async {
    final url = Uri.parse('$appBaseUrl/api/drivers/orders/$orderId/location');
    final res = await http.patch(
      url,
      headers: _headers(),
      body: jsonEncode({'latitude': lat, 'longitude': lng}),
    );
    return res.statusCode == 200;
  }

  Future<bool> _ensureLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  @override
  void onClose() {
    _stopLocationUpdates();
    super.onClose();
  }

  Future<bool> updateOrderStatus(String orderId, String status) async {
    final url = Uri.parse('$appBaseUrl/api/drivers/my/orders/$orderId/status');
    final res = await http.patch(
      url,
      headers: _headers(),
      body: jsonEncode({'status': status}),
    );
    if (kDebugMode)
      print(
        '[UpdateOrderStatus] id=$orderId status=$status http=${res.statusCode} body=${_safeBody(res.body)}',
      );
    if (res.statusCode == 200 && status == 'Delivering') {
      // start tracking when delivery begins
      startLocationUpdates(orderId);
    }
    return res.statusCode == 200;
  }

  String _safeBody(String body, {int max = 160}) {
    if (body.length <= max) return body;
    return body.substring(0, max) + '...';
  }
}
