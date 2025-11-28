import 'package:flutter/material.dart';
import '../../utils/currency.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/orders_controller.dart';
import '../widgets/shipper_appbar.dart';
import 'widgets/delivery_proof_sheet.dart';

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
    final customerName =
        (order['deliveryAddress']?['displayName'] ??
                order['userId']?['username'] ??
                order['userId']?['name'] ??
                'Khách hàng')
            .toString();
    final rawCustomerPhone = (order['userId']?['phone'] ?? '').toString();
    final normalizedCustomerPhone = rawCustomerPhone.replaceAll(
      RegExp(r'[^0-9+]'),
      '',
    );
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
    final issueCard = _buildDeliveryIssueCard(status);

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
            if (issueCard != null) ...[
              issueCard,
              const SizedBox(height: 24),
              const Divider(height: 24),
            ],
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
            if (normalizedCustomerPhone.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildCustomerContactCard(customerName, normalizedCustomerPhone),
            ],
            const SizedBox(height: 24),
            _buildPickupSection(status),
            const SizedBox(height: 24),
            _buildStatusActions(status),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerContactCard(String name, String phone) {
    final displayPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Liên hệ khách hàng:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(displayPhone, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _callCustomer(displayPhone),
                        icon: const Icon(Icons.call),
                        label: const Text('Gọi khách'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _messageCustomer(displayPhone),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Nhắn tin'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _callCustomer(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    final canLaunch = await canLaunchUrl(uri);
    final launched = canLaunch ? await launchUrl(uri) : false;
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở ứng dụng gọi điện.')),
      );
    }
  }

  Future<void> _messageCustomer(String phone) async {
    final uri = Uri(scheme: 'sms', path: phone);
    final canLaunch = await canLaunchUrl(uri);
    final launched = canLaunch ? await launchUrl(uri) : false;
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở ứng dụng nhắn tin.')),
      );
    }
  }

  Widget? _buildDeliveryIssueCard(String driverStatus) {
    final confirmStatus = (_order['shopDeliveryConfirmStatus'] ?? 'None')
        .toString();
    final issueStatus = (_order['deliveryIssueStatus'] ?? 'None').toString();
    final disputeStatus = (_order['customerDisputeStatus'] ?? 'None')
        .toString();
    final deliveryProof = (_order['deliveryProofPhoto'] ?? '').toString();
    final List<String> proofAlbum = (_order['deliveryProofAlbum'] is List)
        ? List<String>.from(
            (_order['deliveryProofAlbum'] as List)
                .map((e) => e == null ? '' : e.toString())
                .where((url) => url.isNotEmpty),
          )
        : <String>[];
    final bool needShopAction = confirmStatus == 'Rejected';
    final bool issueActive = issueStatus != 'None' && issueStatus != 'Resolved';
    final bool disputeActive = disputeStatus != 'None';
    if (!needShopAction && !issueActive && !disputeActive) {
      return null;
    }

    final Color accent = disputeStatus == 'Pending' || issueStatus == 'Disputed'
        ? Colors.redAccent
        : Colors.orange.shade700;
    final List<Widget> chips = [];
    if (issueStatus != 'None') {
      chips.add(
        _issueChip(
          icon: Icons.warning_amber_outlined,
          label: _issueStatusLabel(issueStatus),
          color: _issueStatusColor(issueStatus),
        ),
      );
    }
    if (needShopAction || confirmStatus == 'Pending') {
      chips.add(
        _issueChip(
          icon: Icons.fact_check_outlined,
          label: _shopConfirmLabel(confirmStatus),
          color: _shopConfirmColor(confirmStatus),
        ),
      );
    }
    if (disputeStatus != 'None') {
      chips.add(
        _issueChip(
          icon: Icons.report_problem_outlined,
          label: _disputeStatusLabel(disputeStatus),
          color: _disputeStatusColor(disputeStatus),
        ),
      );
    }

    final rejectReason = (_order['shopDeliveryRejectReason'] ?? '').toString();
    final disputeNote = (_order['customerDisputeNote'] ?? '').toString();
    final issueNote = (_order['deliveryIssueNote'] ?? '').toString();
    final disputeResolution = (_order['customerDisputeResolution'] ?? '')
        .toString();
    final bool canResendProof = driverStatus == 'Delivering';
    final bool needsProofButton =
        canResendProof && (deliveryProof.isEmpty || needShopAction);
    final bool canSendSupplement =
        canResendProof && (disputeActive || issueStatus == 'Escalated');
    final bool preserveConfirmation = confirmStatus == 'Confirmed';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.priority_high, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cảnh báo giao hàng',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (chips.isNotEmpty)
              Wrap(spacing: 8, runSpacing: 8, children: chips),
            if (chips.isNotEmpty) const SizedBox(height: 12),
            if (needShopAction && rejectReason.isNotEmpty)
              _issueText(
                'Shop yêu cầu bổ sung: $rejectReason',
                color: Colors.red.shade700,
              ),
            if (disputeNote.isNotEmpty) _issueText('Khách báo: $disputeNote'),
            if (issueNote.isNotEmpty)
              _issueText('Ghi chú hệ thống: $issueNote'),
            if (disputeResolution.isNotEmpty && disputeStatus != 'Pending')
              _issueText('Kết quả xử lý: $disputeResolution'),
            if (proofAlbum.isNotEmpty) ...[
              const SizedBox(height: 12),
              _ProofAlbumViewer(urls: proofAlbum),
            ],
            if (needsProofButton) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _statusUpdating
                    ? null
                    : () => _openDeliveryProofSheet(
                        supplementOnly: false,
                        preserveConfirmation: preserveConfirmation,
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.photo_camera_back_outlined),
                label: Text(
                  deliveryProof.isEmpty
                      ? 'CHỤP ẢNH BÀN GIAO'
                      : 'GỬI LẠI BẰNG CHỨNG',
                ),
              ),
            ],
            if (canSendSupplement) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _statusUpdating
                    ? null
                    : () => _openDeliveryProofSheet(
                        supplementOnly: true,
                        preserveConfirmation: preserveConfirmation,
                      ),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('BỔ SUNG BẰNG CHỨNG'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _issueChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _issueText(String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: color ?? Colors.black87,
        ),
      ),
    );
  }

  String _issueStatusLabel(String status) {
    switch (status) {
      case 'Warned':
        return 'Đã bị nhắc gửi ảnh';
      case 'Escalated':
        return 'Bị giám sát escalated';
      case 'Disputed':
        return 'Đang tranh chấp';
      case 'Resolved':
        return 'Đã xử lý xong';
      default:
        return 'Cảnh báo logistics';
    }
  }

  Color _issueStatusColor(String status) {
    switch (status) {
      case 'Warned':
        return Colors.orange;
      case 'Escalated':
        return Colors.deepOrange;
      case 'Disputed':
        return Colors.redAccent;
      case 'Resolved':
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }

  String _shopConfirmLabel(String status) {
    switch (status) {
      case 'Pending':
        return 'Shop chưa xác nhận';
      case 'Rejected':
        return 'Shop yêu cầu bổ sung';
      case 'Confirmed':
        return 'Shop đã xác nhận';
      default:
        return 'Trạng thái shop';
    }
  }

  Color _shopConfirmColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.amber.shade800;
      case 'Rejected':
        return Colors.redAccent;
      case 'Confirmed':
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }

  String _disputeStatusLabel(String status) {
    switch (status) {
      case 'Pending':
        return 'Khách đang khiếu nại';
      case 'Resolved':
        return 'Khiếu nại đã xử lý';
      case 'Rejected':
        return 'Cửa hàng từ chối khiếu nại';
      default:
        return 'Trạng thái khiếu nại';
    }
  }

  Color _disputeStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.redAccent;
      case 'Resolved':
        return Colors.green;
      case 'Rejected':
        return Colors.blueGrey;
      default:
        return Colors.blueGrey;
    }
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

  Future<void> _openDeliveryProofSheet({
    bool supplementOnly = false,
    bool preserveConfirmation = false,
  }) async {
    if (_statusUpdating) return;
    final deliveryAddress = _order['deliveryAddress'] as Map<String, dynamic>?;
    final inferredRecipient =
        (deliveryAddress?['recipientName'] ??
                deliveryAddress?['contactName'] ??
                deliveryAddress?['fullName'] ??
                deliveryAddress?['name'] ??
                '')
            .toString();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.95,
          child: DeliveryProofSheet(
            controller: ctrl,
            orderId: _orderId,
            initialRecipient: inferredRecipient.isEmpty
                ? null
                : inferredRecipient,
            supplementOnly: supplementOnly,
            preserveConfirmation: preserveConfirmation,
          ),
        );
      },
    );
    if (result == true) {
      await _refreshOrder();
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
      final proofPhoto = (_order['deliveryProofPhoto'] ?? '').toString();
      final confirmStatus = (_order['shopDeliveryConfirmStatus'] ?? 'None')
          .toString();
      final rejectReason = (_order['shopDeliveryRejectReason'] ?? '')
          .toString();
      final bool proofRejected = confirmStatus == 'Rejected';
      final bool proofConfirmed = confirmStatus == 'Confirmed';
      final bool proofPending =
          !proofConfirmed && !proofRejected && proofPhoto.isNotEmpty;

      if (proofPending) {
        widgets.add(
          _infoBanner(
            'Đã gửi ảnh bàn giao, chờ shop xác nhận.',
            icon: Icons.hourglass_top,
            color: Colors.amber.shade100,
          ),
        );
      }

      if (proofRejected) {
        final detail = rejectReason.isNotEmpty
            ? ': $rejectReason'
            : ' (chưa có lý do)';
        widgets.add(
          _infoBanner(
            'Shop từ chối bằng chứng$detail. Chụp rõ mặt hàng và khách nhận.',
            icon: Icons.error_outline,
            color: Colors.red.shade100,
          ),
        );
      }

      if (proofConfirmed) {
        widgets.add(
          _infoBanner(
            'Shop đã xác nhận bàn giao. Đơn sẽ chuyển sang Hoàn tất sớm.',
            icon: Icons.verified_outlined,
            color: Colors.green.shade100,
          ),
        );
        widgets.add(
          OutlinedButton.icon(
            onPressed: _statusUpdating
                ? null
                : () => _openDeliveryProofSheet(
                    supplementOnly: true,
                    preserveConfirmation: true,
                  ),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('BỔ SUNG BẰNG CHỨNG (KHÔNG RESET)'),
          ),
        );
      }

      if (!proofConfirmed) {
        final label = proofPhoto.isEmpty
            ? 'TẢI ẢNH BÀN GIAO'
            : proofRejected
            ? 'GỬI LẠI BẰNG CHỨNG'
            : 'BỔ SUNG BẰNG CHỨNG';
        widgets.add(
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: proofRejected ? Colors.redAccent : Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _statusUpdating ? null : _openDeliveryProofSheet,
            child: _statusUpdating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        );
      }
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

class _ProofAlbumViewer extends StatelessWidget {
  const _ProofAlbumViewer({required this.urls});
  final List<String> urls;

  void _openPreview(String url) {
    if (url.isEmpty) return;
    Get.dialog(
      Dialog(
        child: InteractiveViewer(
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ảnh đã gửi',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: urls.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) => _ProofThumb(
              url: urls[index],
              onTap: () => _openPreview(urls[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProofThumb extends StatelessWidget {
  const _ProofThumb({required this.url, required this.onTap});
  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade200,
              border: Border.all(color: Colors.grey.shade300),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
            ),
          ),
        ),
      ),
    );
  }
}

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
