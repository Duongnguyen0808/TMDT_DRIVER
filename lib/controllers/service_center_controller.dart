import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/service_ticket.dart';
import 'auth_controller.dart';

class ServiceCenterController extends GetxController {
  final tickets = <ServiceTicket>[].obs;
  final loading = false.obs;
  final submitting = false.obs;
  final detailLoading = false.obs;
  final selectedStatus = ''.obs;
  final metadata = <String, List<String>>{}.obs;

  AuthController get _auth => Get.find<AuthController>();
  String? get _token => _auth.token;

  Map<String, String> _headers() {
    final headers = {'Content-Type': 'application/json'};
    final token = _token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    headers['x-client-app'] = 'shipper';
    return headers;
  }

  @override
  void onInit() {
    super.onInit();
    fetchMetaOptions();
    fetchTickets();
  }

  Future<void> fetchMetaOptions() async {
    try {
      final uri = Uri.parse('$apiBaseUrl/api/service-center/meta/options');
      final res = await http.get(uri, headers: _headers());
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json is Map && json['data'] is Map) {
          final data = Map<String, dynamic>.from(json['data']);
          metadata.assignAll(
            data.map((key, value) {
              final list = (value as List? ?? [])
                  .map((e) => e?.toString() ?? '')
                  .where((e) => e.isNotEmpty)
                  .toList();
              return MapEntry(key, list);
            }),
          );
        }
      }
    } catch (_) {
      // ignore meta errors silently
    }
  }

  Future<void> fetchTickets({String? status}) async {
    loading(true);
    try {
      final query = status != null && status.isNotEmpty
          ? '?status=$status'
          : '';
      final uri = Uri.parse('$apiBaseUrl/api/service-center/tickets$query');
      final res = await http.get(uri, headers: _headers());
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final List items;
        if (json is Map && json['data'] is List) {
          items = List.from(json['data']);
        } else if (json is List) {
          items = json;
        } else {
          items = const [];
        }
        tickets.assignAll(
          items
              .map((e) => ServiceTicket.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
        );
      } else {
        _showError(res.body);
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      loading(false);
    }
  }

  Future<ServiceTicket?> fetchTicketDetail(String id) async {
    detailLoading(true);
    try {
      final uri = Uri.parse('$apiBaseUrl/api/service-center/tickets/$id');
      final res = await http.get(uri, headers: _headers());
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final data = json is Map && json['data'] is Map
            ? Map<String, dynamic>.from(json['data'])
            : Map<String, dynamic>.from(json);
        final ticket = ServiceTicket.fromJson(data);
        _upsert(ticket);
        return ticket;
      }
      _showError(res.body);
    } catch (e) {
      _showError(e.toString());
    } finally {
      detailLoading(false);
    }
    return null;
  }

  Future<bool> createTicket({
    required String subject,
    required String description,
    String? category,
    String? priority,
    String? orderId,
    String? driverId,
    String? reservationId,
    String? shipmentId,
  }) async {
    submitting(true);
    try {
      final uri = Uri.parse('$apiBaseUrl/api/service-center/tickets');
      final payload = {
        'subject': subject.trim(),
        'description': description.trim(),
        if (category != null && category.isNotEmpty) 'category': category,
        if (priority != null && priority.isNotEmpty) 'priority': priority,
        if (orderId != null && orderId.isNotEmpty) 'orderId': orderId,
        if (driverId != null && driverId.isNotEmpty) 'driverId': driverId,
        if (reservationId != null && reservationId.isNotEmpty)
          'reservationId': reservationId,
        if (shipmentId != null && shipmentId.isNotEmpty)
          'shipmentId': shipmentId,
      };
      final res = await http.post(
        uri,
        headers: _headers(),
        body: jsonEncode(payload),
      );
      if (res.statusCode == 201) {
        final json = jsonDecode(res.body);
        final data = json is Map && json['data'] is Map
            ? Map<String, dynamic>.from(json['data'])
            : Map<String, dynamic>.from(json);
        final ticket = ServiceTicket.fromJson(data);
        tickets.insert(0, ticket);
        return true;
      }
      _showError(res.body);
      return false;
    } catch (e) {
      _showError(e.toString());
      return false;
    } finally {
      submitting(false);
    }
  }

  Future<bool> replyTicket({
    required String ticketId,
    required String body,
  }) async {
    detailLoading(true);
    try {
      final uri = Uri.parse(
        '$apiBaseUrl/api/service-center/tickets/$ticketId/reply',
      );
      final res = await http.post(
        uri,
        headers: _headers(),
        body: jsonEncode({'message': body.trim()}),
      );
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final data = json is Map && json['data'] is Map
            ? Map<String, dynamic>.from(json['data'])
            : Map<String, dynamic>.from(json);
        final ticket = ServiceTicket.fromJson(data);
        _upsert(ticket);
        return true;
      }
      _showError(res.body);
      return false;
    } catch (e) {
      _showError(e.toString());
      return false;
    } finally {
      detailLoading(false);
    }
  }

  void _upsert(ServiceTicket ticket) {
    final idx = tickets.indexWhere((t) => t.id == ticket.id);
    if (idx >= 0) {
      tickets[idx] = ticket;
      tickets.refresh();
    } else {
      tickets.insert(0, ticket);
    }
  }

  void _showError(String raw) {
    if (Get.isSnackbarOpen) return;
    Get.snackbar(
      'Trung tâm dịch vụ',
      raw.length > 140 ? raw.substring(0, 140) : raw,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red.shade600,
      colorText: Colors.white,
    );
  }
}
