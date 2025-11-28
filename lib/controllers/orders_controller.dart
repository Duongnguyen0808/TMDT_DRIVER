import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

// Use same base as api_config; adjust for environment (emulator vs device)
import '../config/api_config.dart';

const String appBaseUrl =
    apiBaseUrl; // previously hardcoded localhost:3000 causing connection refused

class ClaimOrderResult {
  const ClaimOrderResult({
    required this.success,
    required this.statusCode,
    this.message,
    this.requiredCommission,
  });

  final bool success;
  final int statusCode;
  final String? message;
  final num? requiredCommission;
}

class DriverOrdersController extends GetxController {
  static const Set<String> _busyStatuses = {
    'WaitingShipper',
    'PickedUp',
    'Delivering',
  };
  final box = GetStorage();
  RxList<Map<String, dynamic>> orders = <Map<String, dynamic>>[].obs;
  RxList<Map<String, dynamic>> availableOrders = <Map<String, dynamic>>[].obs;
  RxBool loading = false.obs;
  RxBool loadingAvailable = false.obs;
  DateTime? lastFetch;
  DateTime? lastAvailableFetch;
  Timer? _locationTimer;
  String? _activeDeliveringOrderId;
  Set<String> _confirmedDeliverySnapshot = <String>{};
  bool _confirmedDeliveryInitialized = false;

  String? get token => box.read('token');

  Map<String, String> _headers() => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  bool _orderBlocksNewClaim(Map<String, dynamic> order) {
    final status = (order['orderStatus'] ?? '').toString();
    if (!_busyStatuses.contains(status)) return false;
    final proof = order['deliveryProofPhoto'];
    if (proof is String && proof.trim().isNotEmpty) {
      // Proof already sent, backend allows claiming next order
      return false;
    }
    return true;
  }

  bool get hasActiveDelivery {
    for (final order in orders) {
      if (_orderBlocksNewClaim(order)) return true;
    }
    return false;
  }

  Map<String, dynamic>? get currentActiveOrder {
    for (final order in orders) {
      if (_orderBlocksNewClaim(order)) {
        return order;
      }
    }
    return null;
  }

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
      _handleDeliveryConfirmations();
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

  void _handleDeliveryConfirmations() {
    final confirmedIds = orders
        .where(
          (order) =>
              (order['shopDeliveryConfirmStatus'] ?? '')
                  .toString()
                  .toLowerCase() ==
              'confirmed',
        )
        .map((order) => (order['_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();

    if (_confirmedDeliveryInitialized) {
      final newlyConfirmed = confirmedIds.difference(
        _confirmedDeliverySnapshot,
      );
      if (newlyConfirmed.isNotEmpty) {
        _notifyConfirmedDeliveries(newlyConfirmed);
      }
    } else {
      _confirmedDeliveryInitialized = true;
    }
    _confirmedDeliverySnapshot = confirmedIds;
  }

  void _notifyConfirmedDeliveries(Set<String> ids) {
    final recent = orders
        .where((order) => ids.contains((order['_id'] ?? '').toString()))
        .take(3)
        .map((order) {
          final orderId = (order['_id'] ?? '').toString();
          final shortId = orderId.length > 6
              ? orderId.substring(orderId.length - 6).toUpperCase()
              : orderId.toUpperCase();
          return '#$shortId';
        })
        .toList();
    if (recent.isEmpty) return;
    final moreCount = ids.length - recent.length;
    final message = moreCount > 0
        ? '${recent.join(', ')} và $moreCount đơn khác đã được shop duyệt.'
        : '${recent.join(', ')} đã được shop duyệt.';
    Get.snackbar(
      'Shop đã xác nhận',
      message,
      backgroundColor: Colors.green.shade600,
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
    );
  }

  Future<ClaimOrderResult> claimOrder(String orderId) async {
    if (hasActiveDelivery) {
      final activeOrder = currentActiveOrder;
      final activeId = activeOrder?['_id']?.toString();
      final activeStatus =
          activeOrder?['orderStatus']?.toString() ?? 'Delivering';
      final proofHint =
          'Nếu đã giao xong hãy gửi bằng chứng để nhận đơn tiếp theo.';
      final message = activeId != null && activeId.isNotEmpty
          ? 'Bạn đang giao đơn $activeId ($activeStatus). Hoàn tất hoặc gửi bằng chứng trước khi nhận đơn mới. $proofHint'
          : 'Bạn đang có đơn đang giao, hãy hoàn tất hoặc gửi bằng chứng trước khi nhận thêm. $proofHint';
      return ClaimOrderResult(
        success: false,
        statusCode: 409,
        message: message,
      );
    }
    final url = Uri.parse('$appBaseUrl/api/drivers/orders/$orderId/claim');
    late http.Response res;
    try {
      res = await http.post(url, headers: _headers());
    } catch (e) {
      return ClaimOrderResult(
        success: false,
        statusCode: -1,
        message: e.toString(),
      );
    }
    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map) {
        data = decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {}
    if (kDebugMode) {
      print(
        '[ClaimOrder] id=$orderId status=${res.statusCode} body=${_safeBody(res.body)}',
      );
    }
    if (res.statusCode == 200) {
      final charged = data?['commissionCharged'];
      await fetchMyOrders(force: true);
      await fetchAvailableOrders(force: true);
      final msg = data?['message']?.toString();
      return ClaimOrderResult(
        success: true,
        statusCode: res.statusCode,
        message: msg,
        requiredCommission: charged is num ? charged : null,
      );
    }
    final required = data?['requiredCommission'];
    return ClaimOrderResult(
      success: false,
      statusCode: res.statusCode,
      message: data?['message']?.toString(),
      requiredCommission: required is num ? required : null,
    );
  }

  Future<String?> uploadProofPhoto(File file) async {
    final uri = Uri.parse('$appBaseUrl/api/upload/image');
    final tokenValue = token;
    final request = http.MultipartRequest('POST', uri);
    if (tokenValue != null) {
      request.headers['Authorization'] = 'Bearer $tokenValue';
    }
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    try {
      final response = await request.send();
      final body = await response.stream.bytesToString();
      if (response.statusCode == 200) {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          return (decoded['secure_url'] ?? decoded['url'] ?? '').toString();
        }
      } else {
        if (kDebugMode) {
          print('[uploadProofPhoto] status=${response.statusCode} body=$body');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[uploadProofPhoto] error=$e');
      }
    }
    return null;
  }

  Future<bool> submitDeliveryProof(
    String orderId, {
    required String photoUrl,
    String? note,
    String? recipient,
    double? latitude,
    double? longitude,
    bool keepConfirmation = false,
    bool supplementOnly = false,
  }) async {
    final payload = <String, dynamic>{'deliveryProofPhoto': photoUrl};
    final trimmedNote = note?.trim();
    if (trimmedNote != null && trimmedNote.isNotEmpty) {
      payload['note'] = trimmedNote;
    }
    final trimmedRecipient = recipient?.trim();
    if (trimmedRecipient != null && trimmedRecipient.isNotEmpty) {
      payload['recipientName'] = trimmedRecipient;
    }
    if (latitude != null && longitude != null) {
      payload['latitude'] = latitude;
      payload['longitude'] = longitude;
    }
    if (keepConfirmation) {
      payload['keepConfirmation'] = true;
    }
    if (supplementOnly) {
      payload['supplementOnly'] = true;
    }

    final url = Uri.parse('$appBaseUrl/api/orders/$orderId/delivery-proof');
    try {
      final res = await http.post(
        url,
        headers: _headers(),
        body: jsonEncode(payload),
      );
      if (kDebugMode) {
        print(
          '[submitDeliveryProof] status=${res.statusCode} body=${_safeBody(res.body)}',
        );
      }
      if (res.statusCode == 200) {
        await fetchMyOrders(force: true);
        _stopLocationUpdates(orderIdIfMatches: orderId);
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[submitDeliveryProof] error=$e');
      }
    }
    return false;
  }

  Future<bool> pickupCheckin(String orderId, {String? note}) async {
    double? lat;
    double? lng;
    try {
      final hasPermission = await _ensureLocationPermission();
      if (hasPermission) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        lat = pos.latitude;
        lng = pos.longitude;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[PickupCheckin] location error: $e');
      }
    }

    final payload = <String, dynamic>{};
    if (lat != null && lng != null) {
      payload['latitude'] = lat;
      payload['longitude'] = lng;
    }
    final trimmedNote = note?.trim();
    if (trimmedNote != null && trimmedNote.isNotEmpty) {
      payload['note'] = trimmedNote;
    }

    final url = Uri.parse('$appBaseUrl/api/orders/$orderId/shipper-checkin');
    final res = await http.post(
      url,
      headers: _headers(),
      body: jsonEncode(payload),
    );
    if (kDebugMode) {
      print(
        '[PickupCheckin] id=$orderId http=${res.statusCode} body=${_safeBody(res.body)}',
      );
    }
    return res.statusCode == 200;
  }

  Future<bool> confirmPickup(
    String orderId,
    String pickupCode, {
    String? note,
    String? handoverPhoto,
  }) async {
    final normalized = pickupCode.trim();
    if (normalized.isEmpty) return false;
    final payload = <String, dynamic>{'pickupCode': normalized};
    final trimmedNote = note?.trim();
    if (trimmedNote != null && trimmedNote.isNotEmpty) {
      payload['note'] = trimmedNote;
    }
    if (handoverPhoto != null && handoverPhoto.isNotEmpty) {
      payload['handoverPhoto'] = handoverPhoto;
    }

    final url = Uri.parse(
      '$appBaseUrl/api/orders/$orderId/shipper-confirm-pickup',
    );
    final res = await http.post(
      url,
      headers: _headers(),
      body: jsonEncode(payload),
    );
    if (kDebugMode) {
      print(
        '[ConfirmPickup] id=$orderId http=${res.statusCode} body=${_safeBody(res.body)}',
      );
    }
    return res.statusCode == 200;
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

  Map<String, dynamic>? findCachedOrder(String orderId) {
    for (final o in orders) {
      if ((o['_id'] ?? '').toString() == orderId) {
        return Map<String, dynamic>.from(o);
      }
    }
    return null;
  }
}
