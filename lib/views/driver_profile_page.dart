import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
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
  Map<String, dynamic>? _ratingSummary;
  List<Map<String, dynamic>> _recentRatings = [];
  bool _ratingsLoading = false;
  String? _ratingsError;
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
      _ratingSummary = null;
      _recentRatings = [];
      _ratingsLoading = false;
      _ratingsError = null;
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
            _loadRatings();
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
              _loadRatings();
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

  Future<void> _loadRatings() async {
    final driverId = _resolveDriverId();
    if (driverId == null) return;

    setState(() {
      _ratingsLoading = true;
      _ratingsError = null;
    });

    try {
      final auth = Get.find<AuthController>();
      final token = auth.token;
      if (token == null) {
        setState(() {
          _ratingsError = 'Không xác định được phiên đăng nhập';
        });
        return;
      }

      final headers = {'Authorization': 'Bearer $token'};
      final url = '$apiBaseUrl/api/rating/Driver/$driverId';
      final res = await http.get(Uri.parse(url), headers: headers);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final summaryRaw = decoded['summary'];
        final ratingsRaw = decoded['ratings'];
        Map<String, dynamic>? summary;
        if (summaryRaw is Map) {
          summary = summaryRaw.map((k, v) => MapEntry(k.toString(), v));
        }
        final parsedRatings = <Map<String, dynamic>>[];
        if (ratingsRaw is List) {
          for (final item in ratingsRaw) {
            if (item is Map) {
              parsedRatings.add(item.map((k, v) => MapEntry(k.toString(), v)));
            }
          }
        }
        setState(() {
          _ratingSummary = summary;
          _recentRatings = parsedRatings;
        });
        return;
      }

      final msg =
          _extractMessage(res.body) ??
          'Không tải được đánh giá (${res.statusCode})';
      setState(() {
        _ratingsError = msg;
      });
    } catch (_) {
      setState(() {
        _ratingsError = 'Không tải được đánh giá';
      });
    } finally {
      if (mounted) {
        setState(() {
          _ratingsLoading = false;
        });
      }
    }
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

  String? _resolveDriverId() {
    final driver = me?['driver'];
    if (driver is Map) {
      final dynamic id = driver['_id'] ?? driver['id'] ?? driver['driverId'];
      if (id != null && id.toString().isNotEmpty) {
        return id.toString();
      }
    }
    final dynamic fallback = me?['_id'] ?? me?['id'];
    if (fallback != null && fallback.toString().isNotEmpty) {
      return fallback.toString();
    }
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
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  _buildRatingSection(),
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

  Widget _buildRatingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Đánh giá từ khách hàng',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (_ratingsLoading)
          const Center(child: CircularProgressIndicator())
        else if (_ratingsError != null) ...[
          Text(_ratingsError!, style: const TextStyle(color: Colors.red)),
          TextButton(onPressed: _loadRatings, child: const Text('Thử tải lại')),
        ] else ...[
          _buildRatingSummaryCard(),
          const SizedBox(height: 16),
          if (_recentRatings.isNotEmpty)
            ..._recentRatings
                .take(3)
                .map(
                  (rating) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RatingTile(
                      rating: rating,
                      dateFormatter: _formatDate,
                      starBuilder: _buildStars,
                    ),
                  ),
                )
                .toList()
          else
            const Text('Bạn chưa có đánh giá nào'),
        ],
      ],
    );
  }

  Widget _buildRatingSummaryCard() {
    final average = _toDouble(_ratingSummary?['average']);
    final total = _toInt(_ratingSummary?['total']);
    final breakdown = _ratingSummary?['breakdown'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                average != null ? average.toStringAsFixed(1) : '—',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStars(average ?? 0),
                  Text('$total lượt đánh giá'),
                ],
              ),
            ],
          ),
          if (breakdown is Map)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildBreakdownChips(breakdown),
            ),
        ],
      ),
    );
  }

  Wrap _buildBreakdownChips(Map breakdown) {
    final chips = <Widget>[];
    for (var score = 5; score >= 1; score--) {
      final count = _toInt(breakdown[score.toString()]);
      chips.add(
        Chip(
          avatar: const Icon(Icons.star, color: Colors.amber, size: 16),
          label: Text('$score★: $count'),
        ),
      );
    }
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Row _buildStars(double rating) {
    return Row(
      children: List.generate(5, (index) {
        final starPosition = index + 1;
        IconData icon;
        if (rating >= starPosition) {
          icon = Icons.star;
        } else if (rating + 0.5 >= starPosition) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }
        return Icon(icon, color: Colors.amber, size: 18);
      }),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final parsed = DateTime.tryParse(raw)?.toLocal();
      if (parsed == null) return '';
      return DateFormat('dd/MM/yyyy HH:mm').format(parsed);
    } catch (_) {
      return '';
    }
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
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

class _RatingTile extends StatelessWidget {
  const _RatingTile({
    required this.rating,
    required this.dateFormatter,
    required this.starBuilder,
  });

  final Map<String, dynamic> rating;
  final String Function(String?) dateFormatter;
  final Row Function(double) starBuilder;

  @override
  Widget build(BuildContext context) {
    final user = rating['userId'];
    final author = user is Map
        ? (user['username'] ?? user['email'] ?? 'Khách hàng ẩn danh')
        : (rating['reviewerName'] ?? 'Khách hàng ẩn danh');
    final score = rating['rating'] is num
        ? (rating['rating'] as num).toDouble()
        : double.tryParse(rating['rating']?.toString() ?? '') ?? 0;
    final comment = rating['comment']?.toString();
    final createdAt = rating['createdAt']?.toString();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  author.toString(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dateFormatter(createdAt),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          starBuilder(score),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(comment),
          ],
        ],
      ),
    );
  }
}
