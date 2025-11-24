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
  Map<String, dynamic>? _application;
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
      me = null;
      _application = null;
    });
    http.Response? lastResponse;
    String? lastException;
    try {
      final auth = Get.find<AuthController>();
      final token = auth.token;
      if (token == null) {
        setState(() {
          error = 'Không xác định được phiên đăng nhập';
        });
        return;
      }

      final headers = {'Authorization': 'Bearer $token'};
      final profileUrl = '$apiBaseUrl/api/drivers/me/profile';
      try {
        final res = await http.get(Uri.parse(profileUrl), headers: headers);
        lastResponse = res;
        if (res.statusCode == 200) {
          final parsed = _parseDriverProfile(res.body);
          if (parsed != null) {
            final app = await _fetchApplication(headers);
            setState(() {
              me = parsed;
              _application = app;
            });
            return;
          }
        }
      } catch (e) {
        lastException = e.toString();
      }

      final endpoints = <String>[
        '$apiBaseUrl/api/users',
        '$apiBaseUrl/me',
        '$apiBaseUrl/api/auth/me',
      ];

      for (final url in endpoints) {
        try {
          final res = await http.get(Uri.parse(url), headers: headers);
          lastResponse = res;
          if (res.statusCode == 200) {
            final parsed = _parseUser(res.body);
            if (parsed != null) {
              final app = await _fetchApplication(headers);
              setState(() {
                me = parsed;
                _application = app;
              });
              return;
            }
          }
          if (res.statusCode == 404) {
            continue;
          }
        } catch (e) {
          lastException = e.toString();
        }
      }

      final msg =
          _extractMessage(lastResponse?.body) ??
          lastException ??
          'Lỗi tải hồ sơ (${lastResponse?.statusCode ?? 'không rõ'})';
      setState(() {
        error = msg;
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Map<String, dynamic>? _parseUser(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final payload = decoded['data'] is Map ? decoded['data'] : decoded;
        return payload.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> _fetchApplication(
    Map<String, String> headers,
  ) async {
    final url = '$apiBaseUrl/api/shipper/me/application';
    try {
      final res = await http.get(Uri.parse(url), headers: headers);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final data = decoded['data'];
        if (data is Map) {
          return data.map((k, v) => MapEntry(k.toString(), v));
        }
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic>? _parseDriverProfile(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final data = decoded['data'];
        if (data is Map) {
          final user = data['user'];
          final driver = data['driver'];
          final result = <String, dynamic>{};
          if (user is Map) {
            user.forEach((key, value) {
              result[key.toString()] = value;
            });
          }
          if (driver is Map) {
            result['driver'] = driver.map(
              (key, value) => MapEntry(key.toString(), value),
            );
          }
          return result.isEmpty ? null : result;
        }
      }
    } catch (_) {}
    return null;
  }

  String? _extractMessage(String? body) {
    if (body == null) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final docSection = _buildDocumentSection();
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
                  _infoRow(
                    'Loại tài khoản',
                    _localizeUserType(me!['userType']),
                  ),
                  if (me!['phone'] != null)
                    _infoRow('Số điện thoại', me!['phone'].toString()),
                  if (me!['verification'] != null)
                    _infoRow(
                      'Đã xác minh email',
                      me!['verification'] == true ? 'Có' : 'Chưa',
                    ),
                  if (me!['phoneVerification'] != null)
                    _infoRow(
                      'Đã xác minh số',
                      me!['phoneVerification'] == true ? 'Có' : 'Chưa',
                    ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  ..._buildDriverDetails(),
                  if (docSection.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    ...docSection,
                  ],
                ],
              ),
      ),
    );
  }

  List<Widget> _buildDriverDetails() {
    final driver = me?['driver'];
    if (driver is! Map) return const [];
    final store = driver['store'];
    final applicationPlate = _application?['vehiclePlate']?.toString() ?? '';
    final driverPlate = driver['vehiclePlate']?.toString() ?? '';
    final plateDisplay = driverPlate.isNotEmpty
        ? driverPlate
        : applicationPlate;
    return [
      const Text(
        'Thông tin tài xế',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      _infoRow('Trạng thái', _localizeDriverStatus(driver['status'])),
      _infoRow('Loại phương tiện', _localizeVehicleType(driver['vehicleType'])),
      _infoRow('Biển số', plateDisplay),
      if (driver['note'] != null && driver['note'].toString().isNotEmpty)
        _infoRow('Ghi chú', driver['note'].toString()),
      if (store is Map) _infoRow('Cửa hàng', store['title']?.toString() ?? ''),
    ];
  }

  List<Widget> _buildDocumentSection() {
    final app = _application;
    if (app == null) return const [];
    final entries = <Map<String, String>>[];
    void addEntry(String key, String label) {
      final value = app[key]?.toString();
      if (value != null && value.isNotEmpty) {
        entries.add({'label': label, 'url': value});
      }
    }

    addEntry('selfieUrl', 'Ảnh chân dung');
    addEntry('idFrontUrl', 'CMND/CCCD mặt trước');
    addEntry('idBackUrl', 'CMND/CCCD mặt sau');
    addEntry('driverLicenseUrl', 'Bằng lái xe');
    addEntry('vehicleRegUrl', 'Đăng ký xe');

    if (entries.isEmpty) return const [];
    return [
      const Text(
        'Giấy tờ đã tải lên',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: entries
            .map(
              (doc) => _DocumentCard(
                label: doc['label']!,
                url: doc['url']!,
                onTap: () => _showImagePreview(doc['label']!, doc['url']!),
              ),
            )
            .toList(),
      ),
    ];
  }

  void _showImagePreview(String label, String url) {
    Get.dialog(
      Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                color: Colors.black87,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: Get.back,
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            InteractiveViewer(
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Không tải được ảnh'),
                    ),
                  ),
                ),
              ),
            ),
            TextButton(onPressed: Get.back, child: const Text('Đóng')),
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

  String _localizeUserType(dynamic type) {
    final value = type?.toString().toLowerCase().trim();
    switch (value) {
      case 'driver':
        return 'Tài xế';
      case 'store':
        return 'Cửa hàng';
      case 'customer':
        return 'Khách hàng';
      case 'admin':
        return 'Quản trị viên';
      default:
        return type?.toString() ?? '';
    }
  }

  String _localizeDriverStatus(dynamic status) {
    final value = status?.toString().toLowerCase().trim();
    switch (value) {
      case 'available':
      case 'active':
        return 'Sẵn sàng nhận đơn';
      case 'busy':
      case 'delivering':
        return 'Đang giao hàng';
      case 'offline':
        return 'Ngoại tuyến';
      case 'suspended':
      case 'blocked':
        return 'Bị tạm khóa';
      default:
        return status?.toString() ?? '';
    }
  }

  String _localizeVehicleType(dynamic type) {
    final value = type?.toString().toLowerCase().trim();
    switch (value) {
      case 'motorbike':
      case 'bike':
        return 'Xe máy';
      case 'car':
        return 'Xe hơi';
      case 'truck':
        return 'Xe tải';
      case 'bicycle':
        return 'Xe đạp';
      default:
        return type?.toString() ?? '';
    }
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.label,
    required this.url,
    required this.onTap,
  });

  final String label;
  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
