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
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Tìm kiếm (mã / cửa hàng / địa chỉ)',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _search = v.trim()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: _walletStrip(),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemBuilder: (_, i) {
                  final label = _statusFilters[i];
                  final selected = _tabIndex == i;
                  return ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) => setState(() => _tabIndex = i),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: _statusFilters.length,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Obx(() {
                if (ctrl.loading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                // Available tab
                if (_tabIndex == 0) {
                  if (ctrl.loadingAvailable.value) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  // Ẩn đơn Preparing khỏi danh sách claim
                  var list = ctrl.availableOrders.where((o) {
                    final s = (o['orderStatus'] ?? '').toString();
                    return s != 'Preparing';
                  }).toList();
                  if (_search.isNotEmpty) {
                    final q = _search.toLowerCase();
                    list = list.where((o) {
                      final id = (o['_id'] ?? '').toString().toLowerCase();
                      final store = (o['storeId']?['title'] ?? '')
                          .toString()
                          .toLowerCase();
                      final addr = (o['deliveryAddress']?['addressLine1'] ?? '')
                          .toString()
                          .toLowerCase();
                      return id.contains(q) ||
                          store.contains(q) ||
                          addr.contains(q);
                    }).toList();
                  }
                  if (list.isEmpty) {
                    return const Center(
                      child: Text('Không có đơn sẵn sàng nhận'),
                    );
                  }
                  final busy = ctrl.hasActiveDelivery;
                  final activeOrder = ctrl.currentActiveOrder;
                  final children = <Widget>[];
                  if (busy) {
                    children.add(
                      _activeDeliveryBanner(
                        orderId: activeOrder?['_id']?.toString(),
                        orderStatus: activeOrder?['orderStatus']?.toString(),
                      ),
                    );
                    children.add(const SizedBox(height: 12));
                  }
                  for (final o in list) {
                    children.add(
                      Column(
                        children: [
                          OrderCard(
                            order: o,
                            onTap: () =>
                                Get.to(() => OrderDetailPage(order: o)),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.assignment_turned_in),
                                  onPressed: busy
                                      ? null
                                      : () => _handleClaimOrder(o),
                                  label: const Text('Nhận đơn'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                    children.add(const SizedBox(height: 12));
                  }
                  if (children.isNotEmpty) {
                    children.removeLast();
                  }
                  return ListView(
                    padding: const EdgeInsets.all(12),
                    children: children,
                  );
                }

                // Other tabs
                final List<Map<String, dynamic>> source = ctrl.orders;
                List<Map<String, dynamic>> filtered;
                if (_tabIndex == 1) {
                  filtered = source; // Tất cả
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
                      return status == 'WaitingShipper' ||
                          logistic == 'SellerPending';
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
                    final store = (o['storeId']?['title'] ?? '')
                        .toString()
                        .toLowerCase();
                    final addr = (o['deliveryAddress']?['addressLine1'] ?? '')
                        .toString()
                        .toLowerCase();
                    return id.contains(q) ||
                        store.contains(q) ||
                        addr.contains(q);
                  }).toList();
                }
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('Không có đơn theo trạng thái'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (_, i) {
                    final o = filtered[i];
                    return OrderCard(
                      order: o,
                      onTap: () => Get.to(() => OrderDetailPage(order: o)),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemCount: filtered.length,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _walletStrip() {
    return Obx(() {
      final summary = walletCtrl.wallet.value;
      final loading = walletCtrl.loading.value;
      final error = walletCtrl.errorMessage.value;
      final balanceText = summary != null
          ? _currency.format(summary.balance.toDouble())
          : (loading ? 'Đang tải...' : 'Chưa có dữ liệu');
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _openWalletPage,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade100),
          ),
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
