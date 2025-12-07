import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/orders_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/wallet_controller.dart';
import '../login_page.dart';
import 'order_detail_page.dart';
import '../widgets/shipper_appbar.dart';
import 'widgets/order_card.dart';
import '../driver_profile_page.dart';
import '../wallet/wallet_page.dart';
import '../support/service_center_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final ctrl = Get.isRegistered<DriverOrdersController>()
      ? Get.find<DriverOrdersController>()
      : Get.put(DriverOrdersController());
  final walletCtrl = Get.isRegistered<WalletController>()
      ? Get.find<WalletController>()
      : Get.put(WalletController());
  final NumberFormat _currency = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );
  int _tabIndex = 0;
  String _search = '';
  final List<String> _statusFilters = const [
    'Có thể nhận', // Available
    'Tất cả', // All
    'Chờ shop', // Waiting for store confirmation
    'Đang giao', // Delivering
    'Hoàn tất', // Delivered
  ];
  final List<IconData> _statusIcons = const [
    Icons.flash_on_outlined,
    Icons.inbox_outlined,
    Icons.storefront_outlined,
    Icons.local_shipping_outlined,
    Icons.verified_outlined,
  ];
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    ctrl.fetchMyOrders();
    ctrl.fetchAvailableOrders(force: true);
    walletCtrl.fetchWallet();
  }

  Future<void> _refreshAll({bool showToast = false}) async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await Future.wait([
        ctrl.fetchAvailableOrders(force: true),
        ctrl.fetchMyOrders(force: true),
        walletCtrl.fetchWallet(force: true),
      ]);
      if (showToast) {
        Get.snackbar(
          'Đã cập nhật',
          'Danh sách đơn và ví đã được tải lại',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: ShipperAppBar(
        title: 'Đơn được giao',
        leading: IconButton(
          icon: const Icon(Icons.account_circle),
          onPressed: () => Get.to(() => const DriverProfilePage()),
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại đơn',
            onPressed: _isRefreshing
                ? null
                : () => _refreshAll(showToast: true),
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: _openWalletPage,
          ),
          IconButton(
            tooltip: 'Trung tâm dịch vụ',
            icon: const Icon(Icons.support_agent),
            onPressed: () => Get.to(() => const ServiceCenterPage()),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              final auth = Get.find<AuthController>();
              auth.logout();
              if (Get.isRegistered<DriverOrdersController>()) {
                Get.delete<DriverOrdersController>(force: true);
              }
              if (Get.isRegistered<WalletController>()) {
                Get.delete<WalletController>(force: true);
              }
              Get.offAll(() => const LoginPage());
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF7F9FF), Color(0xFFE7ECFF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _refreshAll,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: _searchField(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: _walletStrip(),
                  ),
                  Flexible(
                    fit: FlexFit.loose,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _alertsPanel(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _filtersBar(),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Obx(() {
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: _buildOrdersBody(),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return _surface(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Tìm kiếm (mã / cửa hàng / địa chỉ)',
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.blueGrey.shade400,
          ),
          suffixIcon: _search.isNotEmpty
              ? IconButton(
                  tooltip: 'Xóa',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() => _search = ''),
                )
              : null,
          border: InputBorder.none,
        ),
        onChanged: (v) => setState(() => _search = v.trim()),
      ),
    );
  }

  Widget _filtersBar() {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, index) {
          final label = _statusFilters[index];
          final selected = _tabIndex == index;
          return GestureDetector(
            onTap: () => setState(() => _tabIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        colors: [Color(0xFF4C6EF5), Color(0xFF82B1FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: selected ? null : Colors.white.withOpacity(.75),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: selected
                      ? Colors.transparent
                      : Colors.white.withOpacity(.8),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: Colors.blueAccent.withOpacity(.25),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : const [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _filterIcon(index),
                    size: 18,
                    color: selected ? Colors.white : const Color(0xFF4C5D73),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : const Color(0xFF1F2533),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: _statusFilters.length,
      ),
    );
  }

  IconData _filterIcon(int index) {
    if (index >= 0 && index < _statusIcons.length) {
      return _statusIcons[index];
    }
    return Icons.layers_outlined;
  }

  Widget _buildOrdersBody() {
    if (ctrl.loading.value) {
      return const Center(
        key: ValueKey('orders-loading'),
        child: CircularProgressIndicator(),
      );
    }

    if (_tabIndex == 0) {
      if (ctrl.loadingAvailable.value) {
        return const Center(
          key: ValueKey('available-loading'),
          child: CircularProgressIndicator(),
        );
      }
      var list = ctrl.availableOrders.where((o) {
        final status = (o['orderStatus'] ?? '').toString();
        return status != 'Preparing';
      }).toList();
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        list = list.where((o) {
          final id = (o['_id'] ?? '').toString().toLowerCase();
          final store = (o['storeId']?['title'] ?? '').toString().toLowerCase();
          final addr = (o['deliveryAddress']?['addressLine1'] ?? '')
              .toString()
              .toLowerCase();
          return id.contains(q) || store.contains(q) || addr.contains(q);
        }).toList();
      }
      if (list.isEmpty) {
        return const Center(
          key: ValueKey('available-empty'),
          child: Text('Không có đơn sẵn sàng nhận'),
        );
      }
      final busy = ctrl.hasActiveDelivery;
      final activeOrder = ctrl.currentActiveOrder;
      final children = <Widget>[];
      if (busy) {
        children.add(
          _surface(
            child: _activeDeliveryBanner(
              orderId: activeOrder?['_id']?.toString(),
              orderStatus: activeOrder?['orderStatus']?.toString(),
            ),
          ),
        );
        children.add(const SizedBox(height: 14));
      }
      for (final o in list) {
        children.add(
          _surface(
            padding: const EdgeInsets.all(0),
            child: Column(
              children: [
                OrderCard(
                  order: o,
                  onTap: () => Get.to(() => OrderDetailPage(order: o)),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.assignment_turned_in),
                          onPressed: busy ? null : () => _handleClaimOrder(o),
                          label: const Text('Nhận đơn'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
        children.add(const SizedBox(height: 14));
      }
      if (children.isNotEmpty) {
        children.removeLast();
      }
      return ListView(
        key: ValueKey(
          'available-${list.length}-${_search}-${busy ? 'busy' : 'idle'}',
        ),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        children: children,
      );
    }

    final List<Map<String, dynamic>> source = ctrl.orders;
    List<Map<String, dynamic>> filtered;
    if (_tabIndex == 1) {
      filtered = source;
    } else {
      final statusLabel = _statusFilters[_tabIndex];
      String? wanted;
      bool waitingForShop = false;
      switch (statusLabel) {
        case 'Chờ shop':
          waitingForShop = true;
          break;
        case 'Đang giao':
          wanted = 'Delivering';
          break;
        case 'Hoàn tất':
          wanted = 'Delivered';
          break;
      }
      if (waitingForShop) {
        filtered = source.where((o) {
          final status = (o['orderStatus'] ?? '').toString();
          final logistic = (o['logisticStatus'] ?? '').toString();
          return status == 'WaitingShipper' || logistic == 'SellerPending';
        }).toList();
      } else if (wanted != null) {
        filtered = source
            .where((o) => (o['orderStatus'] ?? '') == wanted)
            .toList();
      } else {
        filtered = source;
      }
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      filtered = filtered.where((o) {
        final id = (o['_id'] ?? '').toString().toLowerCase();
        final store = (o['storeId']?['title'] ?? '').toString().toLowerCase();
        final addr = (o['deliveryAddress']?['addressLine1'] ?? '')
            .toString()
            .toLowerCase();
        return id.contains(q) || store.contains(q) || addr.contains(q);
      }).toList();
    }
    if (filtered.isEmpty) {
      return const Center(
        key: ValueKey('other-empty'),
        child: Text('Không có đơn theo trạng thái'),
      );
    }
    return ListView.separated(
      key: ValueKey('tab-$_tabIndex-${filtered.length}-${_search}'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemBuilder: (_, i) {
        final o = filtered[i];
        return _surface(
          padding: const EdgeInsets.all(0),
          child: OrderCard(
            order: o,
            onTap: () => Get.to(() => OrderDetailPage(order: o)),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemCount: filtered.length,
    );
  }

  Widget _surface({
    Key? key,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
    Color color = Colors.white,
    double radius = 20,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color.withOpacity(.95),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(.35)),
      ),
      child: child,
    );
  }

  Widget _surfaceButton({
    Key? key,
    required Widget child,
    VoidCallback? onTap,
    EdgeInsets padding = const EdgeInsets.all(16),
    Color color = Colors.white,
    double radius = 20,
  }) {
    final card = _surface(
      key: key,
      child: child,
      padding: padding,
      color: color,
      radius: radius,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: card,
      ),
    );
  }

  Widget _alertsPanel() {
    return Obx(() {
      final proofIssues = ctrl.orders
          .where(_needsProofReminder)
          .toList(growable: false);
      final disputes = ctrl.orders
          .where(_hasActiveDispute)
          .toList(growable: false);
      if (proofIssues.isEmpty && disputes.isEmpty) {
        return const AnimatedSwitcher(
          duration: Duration(milliseconds: 250),
          child: SizedBox.shrink(key: ValueKey('alerts-empty')),
        );
      }

      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: ConstrainedBox(
          // Prevent the alerts column from pushing the rest of the layout off screen.
          constraints: const BoxConstraints(maxHeight: 200),
          child: Scrollbar(
            thumbVisibility: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: _surface(
                key: ValueKey(
                  'alerts-${proofIssues.length}-${disputes.length}',
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (proofIssues.isNotEmpty)
                      _alertCard(
                        title: 'Nhắc gửi ảnh bàn giao (${proofIssues.length})',
                        color: Colors.orange,
                        icon: Icons.photo_camera_back_outlined,
                        orders: proofIssues,
                        reasonBuilder: _proofReminderReason,
                      ),
                    if (disputes.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _alertCard(
                        title: 'Đơn đang bị khiếu nại (${disputes.length})',
                        color: Colors.redAccent,
                        icon: Icons.report_gmailerrorred_outlined,
                        orders: disputes,
                        reasonBuilder: _disputeReason,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _alertCard({
    required String title,
    required Color color,
    required IconData icon,
    required List<Map<String, dynamic>> orders,
    required String Function(Map<String, dynamic>) reasonBuilder,
  }) {
    final preview = orders.take(3).toList(growable: false);
    final extra = orders.length - preview.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _alertAccent(color),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final o in preview) ...[
            _alertRow(order: o, reason: reasonBuilder(o), color: color),
            const SizedBox(height: 8),
          ],
          if (extra > 0)
            Text(
              '+$extra đơn khác',
              style: TextStyle(
                color: _alertAccent(color),
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Widget _alertRow({
    required Map<String, dynamic> order,
    required String reason,
    required Color color,
  }) {
    final id = (order['_id'] ?? '').toString();
    final shortId = id.length > 6 ? id.substring(id.length - 6) : id;
    final store = (order['storeId']?['title'] ?? '').toString();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '#$shortId · $store',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                reason,
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => _openOrderDetail(order),
          child: Text('Xem', style: TextStyle(color: _alertAccent(color))),
        ),
      ],
    );
  }

  Color _alertAccent(Color base) {
    if (base is MaterialColor) return base.shade700;
    if (base is MaterialAccentColor) return base.shade700;
    final hsl = HSLColor.fromColor(base);
    final adjusted = hsl.withLightness((hsl.lightness * 0.7).clamp(0.0, 1.0));
    return adjusted.toColor();
  }

  void _openOrderDetail(Map<String, dynamic> order) {
    Get.to(() => OrderDetailPage(order: order));
  }

  bool _needsProofReminder(Map<String, dynamic> order) {
    final status = (order['orderStatus'] ?? '').toString();
    final validStatus = status == 'Delivering' || status == 'PickedUp';
    final proofPhoto = (order['deliveryProofPhoto'] ?? '').toString();
    final confirmStatus = (order['shopDeliveryConfirmStatus'] ?? 'None')
        .toString();
    final issueStatus = (order['deliveryIssueStatus'] ?? 'None').toString();
    final warned = issueStatus == 'Warned' || issueStatus == 'Escalated';
    final rejected = confirmStatus == 'Rejected';
    if (!validStatus) return false;
    return proofPhoto.isEmpty || warned || rejected;
  }

  bool _hasActiveDispute(Map<String, dynamic> order) {
    final dispute = (order['customerDisputeStatus'] ?? 'None').toString();
    if (dispute == 'Pending') return true;
    final issueStatus = (order['deliveryIssueStatus'] ?? 'None').toString();
    return issueStatus == 'Disputed';
  }

  String _proofReminderReason(Map<String, dynamic> order) {
    final proofPhoto = (order['deliveryProofPhoto'] ?? '').toString();
    final confirmStatus = (order['shopDeliveryConfirmStatus'] ?? 'None')
        .toString();
    final issueStatus = (order['deliveryIssueStatus'] ?? 'None').toString();
    if (confirmStatus == 'Rejected') {
      final reason = (order['shopDeliveryRejectReason'] ?? '').toString();
      if (reason.isNotEmpty) {
        return 'Shop yêu cầu chụp lại: $reason';
      }
      return 'Shop từ chối ảnh bàn giao, chụp lại ngay.';
    }
    if (proofPhoto.isEmpty) {
      return 'Chưa gửi ảnh bàn giao cho shop.';
    }
    if (issueStatus == 'Escalated') {
      return 'Đơn bị escalated, cần liên hệ shop & bổ sung ảnh.';
    }
    if (issueStatus == 'Warned') {
      return 'Hệ thống nhắc gửi ảnh trước khi bị escalate.';
    }
    return 'Cần kiểm tra lại bằng chứng.';
  }

  String _disputeReason(Map<String, dynamic> order) {
    final note = (order['customerDisputeNote'] ?? '').toString();
    if (note.isNotEmpty) {
      return note;
    }
    final issueNote = (order['deliveryIssueNote'] ?? '').toString();
    if (issueNote.isNotEmpty) {
      return issueNote;
    }
    return 'Khách báo chưa nhận được hàng, cần phối hợp xử lý.';
  }

  Widget _walletStrip() {
    return Obx(() {
      final summary = walletCtrl.wallet.value;
      final loading = walletCtrl.loading.value;
      final error = walletCtrl.errorMessage.value;
      final balanceText = summary != null
          ? _currency.format(summary.balance.toDouble())
          : (loading ? 'Đang tải...' : 'Chưa có dữ liệu');
      return _surfaceButton(
        onTap: _openWalletPage,
        color: Colors.green.shade50,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ví tài xế',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    balanceText,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  if (!loading && summary?.lastTopupAt != null)
                    Text(
                      'Nạp gần nhất: ' + _formatDate(summary!.lastTopupAt!),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  if (error != null)
                    Text(error, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
      );
    });
  }

  Future<void> _openWalletPage() async {
    await Get.to(() => const WalletPage());
    await walletCtrl.fetchWallet(force: true);
  }

  Future<void> _handleClaimOrder(Map<String, dynamic> order) async {
    final result = await ctrl.claimOrder(order['_id'].toString());
    if (result.success) {
      await walletCtrl.fetchWallet(force: true);
      Get.snackbar(
        'Nhận đơn',
        'Bạn đã nhận đơn thành công',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (result.statusCode == 402) {
      await walletCtrl.fetchWallet(force: true);
      _showInsufficientDialog(result.requiredCommission);
      return;
    }
    if (result.statusCode == 409) {
      Get.snackbar(
        'Đang giao đơn',
        result.message ??
            'Bạn cần hoàn tất đơn hiện tại trước khi nhận thêm đơn mới.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade700,
        colorText: Colors.white,
      );
      return;
    }
    final msg = result.message ?? 'Nhận đơn không thành công';
    Get.snackbar(
      'Thất bại',
      msg,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.redAccent,
      colorText: Colors.white,
    );
  }

  Widget _activeDeliveryBanner({String? orderId, String? orderStatus}) {
    final hasId = orderId != null && orderId.isNotEmpty;
    final statusLabel = orderStatus ?? 'Đang giao';
    final text = hasId
        ? 'Bạn đang giao đơn $orderId ($statusLabel). Hoàn tất hoặc giao hàng xong trước khi nhận đơn mới.'
        : 'Bạn đang có đơn cần giao, hãy hoàn tất trước khi nhận thêm.';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showInsufficientDialog(num? required) {
    final balance = walletCtrl.wallet.value?.balance ?? 0;
    final needed = required != null && required > 0
        ? _currency.format(required.toDouble())
        : null;
    num? shortfallRaw;
    if (required != null) {
      shortfallRaw = required - balance;
      if (shortfallRaw < 0) shortfallRaw = 0;
    }
    final shortfallText = shortfallRaw != null
        ? _currency.format(shortfallRaw.toDouble())
        : null;

    final buffer = <String>[];
    if (needed != null) {
      buffer.add('Cần tối thiểu: $needed');
    }
    if (shortfallText != null) {
      buffer.add(
        'Bạn đang thiếu: $shortfallText (số dư hiện tại ${_currency.format(balance.toDouble())})',
      );
    }
    buffer.add('Vui lòng nạp thêm tiền để nhận đơn COD này.');

    final message = buffer.join('\n');
    Get.defaultDialog(
      title: 'Ví không đủ',
      middleText: message,
      textConfirm: 'Nạp ví',
      textCancel: 'Để sau',
      confirmTextColor: Colors.white,
      onConfirm: () {
        Get.back();
        Future.delayed(const Duration(milliseconds: 150), _openWalletPage);
      },
    );
  }

  String _formatDate(DateTime dt) {
    return DateFormat('dd/MM HH:mm').format(dt);
  }
}
