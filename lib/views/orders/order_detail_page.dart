import 'package:flutter/material.dart';
import '../../utils/currency.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/orders_controller.dart';
import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart';
import '../../config/vietmap_config.dart';
import 'package:get_storage/get_storage.dart';
import '../widgets/shipper_appbar.dart';

class OrderDetailPage extends StatefulWidget {
  final Map<String, dynamic> order;
  const OrderDetailPage({super.key, required this.order});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  VietmapController? _vietmapController;
  bool showInternalMap = true; // Vietmap nội bộ thay cho OSM
  final box = GetStorage();
  bool _updating = false; // lock status updates

  @override
  void initState() {
    super.initState();
    final externalPref = box.read('shipper.pref.externalNav') as bool?;
    if (externalPref != null) {
      showInternalMap = !externalPref;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<DriverOrdersController>();
    final order = widget.order;
    final status = (order['orderStatus'] ?? '').toString();
    final logisticStatus = (order['logisticStatus'] ?? '').toString();
    final addr = (order['deliveryAddress']?['addressLine1'] ?? '').toString();
    final storeTitle = (order['storeId']?['title'] ?? '').toString();
    final orderTotal =
        double.tryParse(order['orderTotal']?.toString() ?? '0') ?? 0;
    final deliveryFee =
        double.tryParse(order['deliveryFee']?.toString() ?? '0') ?? 0;
    final grandTotal =
        double.tryParse(order['grandTotal']?.toString() ?? '0') ?? 0;
    final List recipientCoords = (order['recipientCoords'] ?? []) as List;
    final double? destLat = recipientCoords.isNotEmpty
        ? (recipientCoords[0] as num).toDouble()
        : null;
    final double? destLng = recipientCoords.length > 1
        ? (recipientCoords[1] as num).toDouble()
        : null;
    final List storeCoords = (order['storeCoords'] ?? []) as List;
    final double? storeLat = storeCoords.isNotEmpty
        ? (storeCoords[0] as num).toDouble()
        : null;
    final double? storeLng = storeCoords.length > 1
        ? (storeCoords[1] as num).toDouble()
        : null;

    return Scaffold(
      appBar: const ShipperAppBar(title: 'Chi tiết đơn'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mã: ${order['_id']}'),
            const SizedBox(height: 8),
            Text('Trạng thái: $status'),
            if (logisticStatus.isNotEmpty) ...[
              const SizedBox(height: 4),
              _LogisticChip(status: logisticStatus),
            ],
            const SizedBox(height: 8),
            Text('Cửa hàng: $storeTitle'),
            const SizedBox(height: 8),
            Text('Địa chỉ giao: $addr'),
            const SizedBox(height: 8),
            Text('Tạm tính: ${formatVND(orderTotal)}'),
            Text('Phí giao: ${formatVND(deliveryFee)}'),
            Text('Tổng: ${formatVND(grandTotal)}'),
            const SizedBox(height: 12),
            if (destLat != null && destLng != null) ...[
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Vietmap trong app'),
                    selected: showInternalMap,
                    onSelected: (_) {
                      setState(() => showInternalMap = true);
                      box.write('shipper.pref.externalNav', false);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Điều hướng ngoài'),
                    selected: !showInternalMap,
                    onSelected: (_) {
                      setState(() => showInternalMap = false);
                      box.write('shipper.pref.externalNav', true);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (showInternalMap)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 260,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        VietmapGL(
                          styleString: vietmapStyleUrl(),
                          initialCameraPosition: CameraPosition(
                            target: LatLng(destLat, destLng),
                            zoom: 13,
                          ),
                          onMapCreated: (controller) async {
                            _vietmapController = controller;
                            await _addMarkersAndFitBounds(
                              destLat,
                              destLng,
                              storeLat,
                              storeLng,
                            );
                          },
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: _MapCircleButton(
                            icon: Icons.my_location,
                            onTap: () async {
                              await _addMarkersAndFitBounds(
                                destLat,
                                destLng,
                                storeLat,
                                storeLng,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: () async {
                    await _openNavChooser(
                      destLat: destLat,
                      destLng: destLng,
                      storeLat: storeLat,
                      storeLng: storeLng,
                    );
                  },
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.navigation, color: Colors.blueGrey),
                        SizedBox(height: 6),
                        Text('Nhấn để mở điều hướng ngoài'),
                      ],
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: (destLat != null && destLng != null)
                  ? () async {
                      await _openNavChooser(
                        destLat: destLat,
                        destLng: destLng,
                        storeLat: storeLat,
                        storeLng: storeLng,
                      );
                    }
                  : null,
              icon: const Icon(Icons.map),
              label: const Text('Mở bản đồ ngoài'),
            ),
            const Spacer(),
            // Action buttons adapt to new flow:
            // - Available & claim now handled in list
            // - Delivering -> mark delivered
            // - Preparing state no direct driver start; occurs via claim
            if (status == 'Delivering') ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: !_updating
                          ? () async {
                              setState(() => _updating = true);
                              final ok = await ctrl.markDelivered(
                                order['_id'].toString(),
                              );
                              setState(() => _updating = false);
                              if (ok) {
                                Get.snackbar(
                                  'Hoàn tất',
                                  'Đơn đã giao thành công',
                                  snackPosition: SnackPosition.BOTTOM,
                                );
                                Get.back();
                              }
                            }
                          : null,
                      child: _updating
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Đã giao (Hoàn tất)'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _addMarkersAndFitBounds(
    double destLat,
    double destLng,
    double? storeLat,
    double? storeLng,
  ) async {
    if (_vietmapController == null) return;
    await _vietmapController!.clearSymbols();
    await _vietmapController!.addSymbol(
      SymbolOptions(
        geometry: LatLng(destLat, destLng),
        iconImage: "marker-15",
        iconSize: 1.5,
      ),
    );
    if (storeLat != null && storeLng != null) {
      await _vietmapController!.addSymbol(
        SymbolOptions(
          geometry: LatLng(storeLat, storeLng),
          iconImage: "shop-15",
          iconSize: 1.5,
        ),
      );
      // Vẽ tuyến đường placeholder: các điểm nhỏ giữa cửa hàng và điểm giao
      await _drawRoutePlaceholder(
        LatLng(storeLat, storeLng),
        LatLng(destLat, destLng),
        segments: 14,
      );
      final swLat = storeLat < destLat ? storeLat : destLat;
      final swLng = storeLng < destLng ? storeLng : destLng;
      final neLat = storeLat > destLat ? storeLat : destLat;
      final neLng = storeLng > destLng ? storeLng : destLng;
      await _vietmapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(swLat, swLng),
            northeast: LatLng(neLat, neLng),
          ),
          left: 32,
          top: 32,
          bottom: 32,
          right: 32,
        ),
      );
    } else {
      await _vietmapController!.animateCamera(
        CameraUpdate.newLatLng(LatLng(destLat, destLng)),
      );
    }
  }

  Future<void> _drawRoutePlaceholder(
    LatLng origin,
    LatLng dest, {
    int segments = 10,
  }) async {
    if (_vietmapController == null) return;
    if (segments < 2) segments = 2;
    // Không vẽ nếu hai điểm quá gần
    final dLat = dest.latitude - origin.latitude;
    final dLng = dest.longitude - origin.longitude;
    if (dLat.abs() < 0.00005 && dLng.abs() < 0.00005) return;
    for (int i = 1; i < segments; i++) {
      final frac = i / segments;
      final lat = origin.latitude + dLat * frac;
      final lng = origin.longitude + dLng * frac;
      await _vietmapController!.addSymbol(
        SymbolOptions(
          geometry: LatLng(lat, lng),
          iconImage:
              "marker-15", // Placeholder - có thể đổi sang icon tuyến đường chuyên biệt nếu style hỗ trợ
          iconSize: 0.6,
        ),
      );
    }
  }

  Future<void> _openNavChooser({
    required double destLat,
    required double destLng,
    double? storeLat,
    double? storeLng,
  }) async {
    final hasOrigin = storeLat != null && storeLng != null;
    final originParam = hasOrigin
        ? '${storeLat.toStringAsFixed(6)},${storeLng.toStringAsFixed(6)}'
        : '';
    final destParam =
        '${destLat.toStringAsFixed(6)},${destLng.toStringAsFixed(6)}';

    final googleMapsIOS = Uri.parse(
      'comgooglemaps://?${hasOrigin ? 'saddr=$originParam&' : ''}daddr=$destParam&directionsmode=driving',
    );
    final googleMapsAndroidNav = Uri.parse(
      'google.navigation:q=$destParam&mode=d',
    );
    final wazeUri = Uri.parse('waze://?ll=$destParam&navigate=yes');
    final appleMaps = Uri.parse(
      'maps://?${hasOrigin ? 'saddr=$originParam&' : ''}daddr=$destParam&dirflg=d',
    );
    final browserMaps = Uri.parse(
      'https://www.google.com/maps/dir/?api=1${hasOrigin ? '&origin=$originParam' : ''}&destination=$destParam&travelmode=driving',
    );

    final opts = <_NavOption>[];
    if (await canLaunchUrl(googleMapsIOS)) {
      opts.add(_NavOption('Google Maps', Icons.map, googleMapsIOS));
    }
    if (await canLaunchUrl(googleMapsAndroidNav)) {
      opts.add(
        _NavOption('Google Maps (Android)', Icons.map, googleMapsAndroidNav),
      );
    }
    if (await canLaunchUrl(wazeUri)) {
      opts.add(_NavOption('Waze', Icons.directions_car, wazeUri));
    }
    if (await canLaunchUrl(appleMaps)) {
      opts.add(_NavOption('Apple Maps', Icons.map_outlined, appleMaps));
    }
    opts.add(_NavOption('Trình duyệt', Icons.language, browserMaps));

    await showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: opts.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final o = opts[i];
              return ListTile(
                leading: Icon(o.icon),
                title: Text(o.title),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  if (await canLaunchUrl(o.uri)) {
                    await launchUrl(
                      o.uri,
                      mode: LaunchMode.externalApplication,
                    );
                  } else {
                    await launchUrl(
                      browserMaps,
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
              );
            },
          ),
        );
      },
    );
  }
}

// Removed local formatter; using formatVND

class _LogisticChip extends StatelessWidget {
  const _LogisticChip({required this.status});
  final String status;

  Color _color() {
    switch (status) {
      case 'SellerPending':
        return Colors.brown;
      case 'ToOriginHub':
        return Colors.orange;
      case 'AtOriginHub':
        return Colors.deepOrange;
      case 'ToLocalHub':
        return Colors.teal;
      case 'AtLocalHub':
        return Colors.blueAccent;
      case 'PickedUp':
        return Colors.indigo;
      case 'Delivering':
        return Colors.purple;
      case 'Delivered':
        return Colors.green;
      case 'Cancelled':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  String _label() {
    switch (status) {
      case 'SellerPending':
        return 'Chờ shop';
      case 'ToOriginHub':
        return 'Đến kho tổng';
      case 'AtOriginHub':
        return 'Ở kho tổng';
      case 'ToLocalHub':
        return 'Đến kho địa phương';
      case 'AtLocalHub':
        return 'Ở kho địa phương';
      case 'PickedUp':
        return 'Đã lấy';
      case 'Delivering':
        return 'Đang giao';
      case 'Delivered':
        return 'Hoàn tất';
      case 'Cancelled':
        return 'Hủy';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withOpacity(.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_shipping, size: 14, color: c),
          const SizedBox(width: 4),
          Text(
            _label(),
            style: TextStyle(
              color: c,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavOption {
  final String title;
  final IconData icon;
  final Uri uri;
  _NavOption(this.title, this.icon, this.uri);
}

class _MapCircleButton extends StatelessWidget {
  const _MapCircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(8.0),
          child: Icon(Icons.my_location, size: 20),
        ),
      ),
    );
  }
}
