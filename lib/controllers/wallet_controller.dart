import 'dart:convert';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class WalletSummary {
  WalletSummary({
    required this.balance,
    required this.currency,
    required this.transactions,
    this.lastTopupAt,
    this.lastChargeAt,
  });

  final num balance;
  final String currency;
  final List<Map<String, dynamic>> transactions;
  final DateTime? lastTopupAt;
  final DateTime? lastChargeAt;
}

class WalletController extends GetxController {
  final box = GetStorage();

  final RxBool loading = false.obs;
  final RxBool creatingTopup = false.obs;
  final RxBool adjusting = false.obs;
  final RxnString errorMessage = RxnString();
  final Rxn<WalletSummary> wallet = Rxn<WalletSummary>();
  DateTime? lastFetch;

  String? get token => box.read('token');

  Map<String, String> _headers() => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  @override
  void onInit() {
    super.onInit();
    fetchWallet();
  }

  Future<void> fetchWallet({bool force = false}) async {
    if (!force && lastFetch != null) {
      final diff = DateTime.now().difference(lastFetch!);
      if (diff.inSeconds < 10 && wallet.value != null) {
        return;
      }
    }
    loading.value = true;
    errorMessage.value = null;
    try {
      final res = await http.get(
        Uri.parse('$apiBaseUrl/api/drivers/wallet'),
        headers: _headers(),
      );
      if (res.statusCode == 200) {
        final data = _decodeBody(res.body);
        final payload = _extractWalletPayload(data);
        if (payload != null) {
          final List transactions = payload['transactions'] is List
              ? payload['transactions'] as List
              : const [];
          final normalizedTransactions = transactions
              .map(_asMap)
              .whereType<Map<String, dynamic>>()
              .toList();
          wallet.value = WalletSummary(
            balance: payload['balance'] is num ? payload['balance'] as num : 0,
            currency: payload['currency']?.toString() ?? 'VND',
            transactions: normalizedTransactions,
            lastTopupAt: _parseDate(payload['lastTopupAt']),
            lastChargeAt: _parseDate(payload['lastChargeAt']),
          );
          lastFetch = DateTime.now();
        } else {
          errorMessage.value = 'Không có dữ liệu ví';
        }
      } else {
        errorMessage.value =
            _extractMessage(res.body) ??
            'Không thể tải ví (HTTP ${res.statusCode})';
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  Future<String?> createTopupIntent(int amount, {String? note}) async {
    creatingTopup.value = true;
    errorMessage.value = null;
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/api/drivers/wallet/topup'),
        headers: _headers(),
        body: jsonEncode({'amount': amount, if (note != null) 'note': note}),
      );
      final data = _decodeBody(res.body);
      if (res.statusCode == 200) {
        if (data is Map && data['url'] is String) {
          return data['url'] as String;
        }
        errorMessage.value = 'Phản hồi nạp ví không hợp lệ';
        return null;
      }
      final msg = data is Map ? data['message']?.toString() : null;
      errorMessage.value = msg ?? 'Nạp ví thất bại (HTTP ${res.statusCode})';
      return null;
    } catch (e) {
      errorMessage.value = e.toString();
      return null;
    } finally {
      creatingTopup.value = false;
    }
  }

  Future<bool> adjustBalance({
    required int amount,
    required bool increase,
    String? note,
  }) async {
    adjusting.value = true;
    errorMessage.value = null;
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/api/drivers/wallet/mock-adjust'),
        headers: _headers(),
        body: jsonEncode({
          'amount': amount,
          'action': increase ? 'credit' : 'debit',
          if (note != null && note.isNotEmpty) 'note': note,
        }),
      );

      final data = _decodeBody(res.body);
      if (res.statusCode == 200) {
        await fetchWallet(force: true);
        return true;
      }

      final msg = data is Map && data['message'] != null
          ? data['message'].toString()
          : 'Điều chỉnh ví thất bại (HTTP ${res.statusCode})';
      errorMessage.value = msg;
      return false;
    } catch (e) {
      errorMessage.value = e.toString();
      return false;
    } finally {
      adjusting.value = false;
    }
  }

  dynamic _decodeBody(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _extractWalletPayload(dynamic data) {
    final map = _asMap(data);
    if (map == null) return null;
    if (map['data'] is Map) {
      return _asMap(map['data']);
    }
    if (map['wallet'] is Map) {
      return _asMap(map['wallet']);
    }
    // Some deployments may return the wallet object directly
    if (map.containsKey('balance')) {
      return map;
    }
    return null;
  }

  String? _extractMessage(String body) {
    final data = _decodeBody(body);
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return null;
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, v) => MapEntry(key.toString(), v));
    }
    return null;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }
}
