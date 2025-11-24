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
  late final DriverOrdersController ctrl;
  late Map<String, dynamic> _order;
  bool _statusUpdating = false;
  bool _pickupBusy = false;
  bool _refreshing = false;
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  String get _orderId => (_order['_id'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    ctrl = Get.find<DriverOrdersController>();
    _order = Map<String, dynamic>.from(widget.order);
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
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

    final List recipientCoords = order['recipientCoords'] is List
        ? List.from(order['recipientCoords'] as List)
        : const [];
    final double? destLat = recipientCoords.isNotEmpty
        ? (recipientCoords[0] as num).toDouble()
        : null;
    final double? destLng = recipientCoords.length > 1
        ? (recipientCoords[1] as num).toDouble()
        : null;

    final List storeCoords = order['storeCoords'] is List
        ? List.from(order['storeCoords'] as List)
        : const [];
    final double? storeLat = storeCoords.isNotEmpty
        ? (storeCoords[0] as num).toDouble()
        : null;
    final double? storeLng = storeCoords.length > 1
        ? (storeCoords[1] as num).toDouble()
        : null;

    return Scaffold(
      appBar: ShipperAppBar(
        title: 'Chi tiết đơn',
        actions: [
          IconButton(
            onPressed: _refreshing ? null : _refreshOrder,
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshOrder,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Mã: $_orderId',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Trạng thái logistics: '),
                if (logisticStatus.isNotEmpty)
                  _LogisticChip(status: logisticStatus)
                else
                  const Text('--'),
              ],
            ),
            const Divider(height: 24),
            const Text(
              'LẤY HÀNG TẠI:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              storeTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            const Text(
              'GIAO HÀNG ĐẾN:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              addr,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Divider(height: 24),
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
            const Text(
              'Điều hướng bản đồ:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
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
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (destLat != null && destLng != null)
                        ? () => _openMap(destLat, destLng, title: 'Khách hàng')
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
            const SizedBox(height: 24),
            _buildPickupSection(status),
            const SizedBox(height: 24),
            _buildStatusActions(status),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshOrder() async {
    setState(() => _refreshing = true);
    await ctrl.fetchMyOrders(force: true);
    final latest = ctrl.findCachedOrder(_orderId);
    if (mounted && latest != null) {
      setState(() => _order = latest);
    }
    if (mounted) {
      setState(() => _refreshing = false);
    }
  }

  Future<void> _handleCheckin() async {
    if (_pickupBusy) return;
    setState(() => _pickupBusy = true);
    final note = _noteCtrl.text.trim();
    final ok = await ctrl.pickupCheckin(
      _orderId,
      note: note.isEmpty ? null : note,
    );
    if (!mounted) return;
    setState(() => _pickupBusy = false);
    if (ok) {
      Get.snackbar(
        'Đã báo cửa hàng',
        'Bạn đã check-in tại cửa hàng',
        snackPosition: SnackPosition.BOTTOM,
      );
      await _refreshOrder();
    } else {
      Get.snackbar(
        'Không thể báo cửa hàng',
        'Vui lòng thử lại',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _handleConfirmPickup() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      Get.snackbar(
        'Thiếu mã',
        'Nhập mã 6 số do cửa hàng cung cấp',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (_pickupBusy) return;
    setState(() => _pickupBusy = true);
    final note = _noteCtrl.text.trim();
    final ok = await ctrl.confirmPickup(
      _orderId,
      code,
      note: note.isEmpty ? null : note,
    );
    if (!mounted) return;
    setState(() => _pickupBusy = false);
    if (ok) {
      _codeCtrl.clear();
      Get.snackbar(
        'Đã nhận hàng',
        'Bắt đầu rời cửa hàng để giao khách',
        snackPosition: SnackPosition.BOTTOM,
      );
      await _refreshOrder();
    } else {
      Get.snackbar(
        'Không thể xác nhận',
        'Kiểm tra mã và thử lại',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _startDelivering() async {
    if (_statusUpdating) return;
    setState(() => _statusUpdating = true);
    final ok = await ctrl.updateOrderStatus(_orderId, 'Delivering');
    if (!mounted) return;
    setState(() => _statusUpdating = false);
    if (ok) {
      Get.snackbar(
        'Đang giao',
        'Bạn đang trên đường tới khách',
        snackPosition: SnackPosition.BOTTOM,
      );
      await _refreshOrder();
    } else {
      Get.snackbar(
        'Không thể cập nhật',
        'Vui lòng thử lại',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _markDelivered() async {
    if (_statusUpdating) return;
    setState(() => _statusUpdating = true);
    final ok = await ctrl.markDelivered(_orderId);
    if (!mounted) return;
    setState(() => _statusUpdating = false);
    if (ok) {
      Get.snackbar(
        'Hoàn tất',
        'Đơn đã giao thành công',
        snackPosition: SnackPosition.BOTTOM,
      );
      Get.back();
    } else {
      Get.snackbar(
        'Không thể cập nhật',
        'Vui lòng thử lại',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    }
  }

  Widget _buildPickupSection(String status) {
    final assignedAt = _parseDate(_order['pickupAssignedAt']);
    final readyAt = _parseDate(_order['pickupReadyAt']);
    final checkinAt = _parseDate(_order['pickupCheckinAt']);
    final confirmAt = _parseDate(_order['pickupConfirmedAt']);
    final expiresAt = _parseDate(_order['pickupCodeExpiresAt']);
    final codeAvailable = (_order['pickupCode'] ?? '').toString().isNotEmpty;
    final checkinLocation = _formatLocation(_order['pickupCheckinLocation']);
    final pickupNotes = (_order['pickupNotes'] ?? '').toString();
    final awaitingStore = readyAt == null;
    final canInteract = {'WaitingShipper', 'ReadyForPickup'}.contains(status);
    final showCheckin = canInteract;
    final showConfirm = canInteract && codeAvailable;
    final showAwaitingCode = canInteract && readyAt != null && !codeAvailable;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.handshake_outlined, color: Colors.indigo),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bàn giao shop ↔ shipper',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _timelineRow(
              'Được giao cho bạn',
              assignedAt,
              Icons.assignment_ind_outlined,
            ),
            _timelineRow('Shop sẵn sàng', readyAt, Icons.storefront_outlined),
            _timelineRow(
              'Bạn đã có mặt',
              checkinAt,
              Icons.punch_clock_outlined,
              detail: checkinLocation,
            ),
            _timelineRow(
              'Xác nhận lấy hàng',
              confirmAt,
              Icons.task_alt_outlined,
            ),
            if (pickupNotes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Ghi chú: $pickupNotes',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            if (awaitingStore)
              _infoBanner(
                'Cửa hàng chưa báo sẵn sàng. Liên hệ cửa hàng để họ phát mã.',
                icon: Icons.hourglass_bottom,
                color: Colors.orange.shade100,
              )
            else if (showAwaitingCode)
              _infoBanner(
                'Shop đã sẵn sàng nhưng chưa đưa mã. Nhờ nhân viên đọc mã 6 số cho bạn.',
                icon: Icons.lock_clock,
                color: Colors.amber.shade100,
              )
            else if (!canInteract && confirmAt != null)
              _infoBanner(
                'Bạn đã lấy hàng. Nhớ chuyển sang Đang giao khi rời cửa hàng.',
                icon: Icons.check_circle_outline,
                color: Colors.green.shade100,
              ),
            if (_pickupBusy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (showCheckin) ...[
              ElevatedButton.icon(
                onPressed: _pickupBusy ? null : _handleCheckin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade700,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.punch_clock),
                label: const Text('Tôi đã đến cửa hàng'),
              ),
              const SizedBox(height: 12),
            ],
            if (showConfirm) ...[
              TextField(
                controller: _codeCtrl,
                enabled: !_pickupBusy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nhập mã do cửa hàng cung cấp',
                  prefixIcon: Icon(Icons.qr_code_2),
                  border: OutlineInputBorder(),
                ),
              ),
              if (expiresAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Mã hết hạn: ${_formatDate(expiresAt)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              enabled: !_pickupBusy && (showCheckin || showConfirm),
              decoration: const InputDecoration(
                labelText: 'Ghi chú cho cửa hàng (tuỳ chọn)',
                border: OutlineInputBorder(),
              ),
            ),
            if (showConfirm) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _pickupBusy ? null : _handleConfirmPickup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.verified_outlined),
                label: const Text('XÁC NHẬN ĐÃ NHẬN HÀNG'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusActions(String status) {
    final widgets = <Widget>[];
    if (status == 'PickedUp') {
      widgets.add(
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: _statusUpdating ? null : _startDelivering,
          child: _statusUpdating
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'BẮT ĐẦU GIAO (ĐANG ĐI)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      );
    }
    if (status == 'Delivering') {
      widgets.add(
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: _statusUpdating ? null : _markDelivered,
          child: _statusUpdating
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
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      );
    }

    if (widgets.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Thao tác', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        for (int i = 0; i < widgets.length; i++) ...[
          widgets[i],
          if (i != widgets.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _timelineRow(
    String label,
    DateTime? time,
    IconData icon, {
    String? detail,
  }) {
    final detailText = detail != null && detail.trim().isNotEmpty
        ? detail.trim()
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  time != null ? _formatDate(time) : '---',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                if (detailText != null)
                  Text(
                    detailText,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBanner(
    String message, {
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.black54),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String && raw.isNotEmpty) {
      try {
        return DateTime.parse(raw);
      } catch (_) {}
    }
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    return null;
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '---';
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }

  String _formatLocation(dynamic raw) {
    if (raw is Map) {
      final lat = (raw['latitude'] as num?)?.toDouble();
      final lng = (raw['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        return '(${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)})';
      }
    }
    return '';
  }

  Future<void> _openMap(double lat, double lng, {String title = ''}) async {
    final targetLabel = title.isEmpty ? 'điểm đến' : title;
    final Uri googleMapAppUrl = Uri.parse(
      'google.navigation:q=$lat,$lng&mode=d',
    );
    final Uri googleMapBrowserUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    final Uri appleMapsUrl = Uri.parse(
      'https://maps.apple.com/?daddr=$lat,$lng&dirflg=d',
    );

    try {
      if (await canLaunchUrl(googleMapAppUrl)) {
        await launchUrl(googleMapAppUrl);
      } else if (await canLaunchUrl(appleMapsUrl)) {
        await launchUrl(appleMapsUrl);
      } else {
        await launchUrl(
          googleMapBrowserUrl,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể mở bản đồ tới $targetLabel: $e');
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
