import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../controllers/auth_controller.dart';
import '../config/api_config.dart';
import 'widgets/shipper_appbar.dart';

class DriverProfilePage extends StatefulWidget {
  const DriverProfilePage({super.key});

  @override
  State<DriverProfilePage> createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends State<DriverProfilePage> {
  Map<String, dynamic>? me;
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final auth = Get.find<AuthController>();
      final token = auth.token;
      if (token == null) {
        setState(() {
          error = 'Không có token';
          loading = false;
        });
        return;
      }
      // Try /me then fallback /api/auth/me
      final u1 = Uri.parse('$apiBaseUrl/me');
      var res = await http.get(u1, headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 404) {
        final u2 = Uri.parse('$apiBaseUrl/api/auth/me');
        res = await http.get(u2, headers: {'Authorization': 'Bearer $token'});
      }
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map) {
          setState(() {
            me = data.map((k, v) => MapEntry(k.toString(), v));
          });
        } else {
          setState(() {
            me = {'raw': data};
          });
        }
      } else {
        setState(() {
          error = 'Lỗi tải hồ sơ (${res.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ShipperAppBar(title: 'Hồ sơ tài xế'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _load,
                    child: const Text('Thử lại'),
                  ),
                ],
              )
            : me == null
            ? const Text('Không có dữ liệu hồ sơ')
            : ListView(
                children: [
                  _infoRow('ID', me!['id'] ?? me!['_id'] ?? ''),
                  _infoRow('Email', me!['email'] ?? ''),
                  _infoRow('Tên', me!['username'] ?? ''),
                  _infoRow('Loại tài khoản', me!['userType'] ?? ''),
                  if (me!['phone'] != null)
                    _infoRow('Số điện thoại', me!['phone'].toString()),
                ],
              ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? '—' : value)),
        ],
      ),
    );
  }
}
