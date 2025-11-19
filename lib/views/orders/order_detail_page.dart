import 'package:flutter/material.dart';
import '../../utils/currency.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/orders_controller.dart';
import '../widgets/shipper_appbar.dart';

class OrderDetailPage extends StatefulWidget {
  final Map<String, dynamic> order;
  const OrderDetailPage({super.key, required this.order});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  bool _updating = false; // Giữ lại biến này để khóa nút khi đang call API

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<DriverOrdersController>();
    final order = widget.order;

    // Lấy dữ liệu cơ bản
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

    // Lấy tọa độ Khách (Recipient)
    final List recipientCoords = (order['recipientCoords'] ?? []) as List;
    final double? destLat = recipientCoords.isNotEmpty
        ? (recipientCoords[0] as num).toDouble()
        : null;
    final double? destLng = recipientCoords.length > 1
        ? (recipientCoords[1] as num).toDouble()
        : null;

    // Lấy tọa độ Shop (Store)
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
            // --- Phần thông tin đơn hàng ---
            Text(
              'Mã: ${order['_id']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Trạng thái: '),
                if (logisticStatus.isNotEmpty)
                  _LogisticChip(status: logisticStatus),
              ],
            ),
            const Divider(height: 24),

            // --- Phần thông tin Shop ---
            const Text(
              'LẤY HÀNG TẠI:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              storeTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),

            // const SizedBox(height: 4),
            // Text(storeAddr), // Hiển thị địa chỉ shop nếu có
            const SizedBox(height: 16),

            // --- Phần thông tin Khách ---
            const Text(
              'GIAO HÀNG ĐẾN:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              addr,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),

            const Divider(height: 24),

            // --- Phần Tài chính ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tổng tiền thu:'),
                Text(
                  formatVND(grandTotal),
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '(Tạm tính: ${formatVND(orderTotal)} + Ship: ${formatVND(deliveryFee)})',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),

            const SizedBox(height: 24),

            // --- PHẦN 2 NÚT ĐIỀU HƯỚNG (THAY ĐỔI CHÍNH) ---
            const Text(
              'Điều hướng bản đồ:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Nút đến Shop
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (storeLat != null && storeLng != null)
                        ? () => _openMap(storeLat, storeLng, title: storeTitle)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade100,
                      foregroundColor: Colors.deepOrange,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.store),
                    label: const Text('Đến Shop'),
                  ),
                ),
                const SizedBox(width: 12),
                // Nút đến Khách
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (destLat != null && destLng != null)
                        ? () => _openMap(destLat, destLng, title: "Khách hàng")
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade100,
                      foregroundColor: Colors.blue.shade900,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.person_pin_circle),
                    label: const Text('Đến Khách'),
                  ),
                ),
              ],
            ),

            const Spacer(),

            // --- Button xử lý trạng thái đơn hàng (Giữ nguyên logic cũ) ---
            if (status == 'Delivering') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
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
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'ĐÃ GIAO HÀNG (HOÀN TẤT)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Hàm mở bản đồ đơn giản hóa
  Future<void> _openMap(double lat, double lng, {String title = ''}) async {
    // 1. Tạo URL chuyên dụng cho Google Maps App trên Android/iOS
    final Uri googleMapAppUrl = Uri.parse(
      "google.navigation:q=$lat,$lng&mode=d",
    );

    // 2. Tạo URL mở bằng trình duyệt (fallback nếu không có app)
    final Uri googleMapBrowserUrl = Uri.parse(
      "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving",
    );

    // 3. Tạo URL cho Apple Maps (dành cho iOS)
    final Uri appleMapsUrl = Uri.parse(
      "https://maps.apple.com/?daddr=$lat,$lng&dirflg=d",
    );

    try {
      if (await canLaunchUrl(googleMapAppUrl)) {
        // Ưu tiên mở bằng App Google Maps
        await launchUrl(googleMapAppUrl);
      } else if (await canLaunchUrl(appleMapsUrl)) {
        // Nếu là iPhone và không có Google Maps -> Mở Apple Maps
        await launchUrl(appleMapsUrl);
      } else {
        // Cuối cùng mở bằng trình duyệt
        await launchUrl(
          googleMapBrowserUrl,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      Get.snackbar("Lỗi", "Không thể mở bản đồ: $e");
    }
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
