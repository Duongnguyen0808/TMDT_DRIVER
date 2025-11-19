import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/orders_controller.dart';
import '../../controllers/auth_controller.dart';
import '../login_page.dart';
import 'order_detail_page.dart';
import '../widgets/shipper_appbar.dart';
import 'widgets/order_card.dart';
import '../driver_profile_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final ctrl = Get.put(DriverOrdersController());
  int _tabIndex = 0;
  String _search = '';
  final List<String> _statusFilters = const [
    'Có thể nhận', // Available
    'Tất cả', // All
    'Đang giao', // Delivering
    'Hoàn tất', // Delivered
    // Removed Preparing from tabs (ẩn đơn chưa sẵn sàng lấy)
  ];

  @override
  void initState() {
    super.initState();
    ctrl.fetchMyOrders();
    ctrl.fetchAvailableOrders(force: true);
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
            icon: const Icon(Icons.logout),
            onPressed: () {
              final auth = Get.find<AuthController>();
              auth.logout();
              Get.offAll(() => const LoginPage());
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ctrl.fetchMyOrders(force: true),
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
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemBuilder: (_, i) {
                      final o = list[i];
                      return Column(
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
                                  onPressed: () async {
                                    final ok = await ctrl.claimOrder(
                                      o['_id'].toString(),
                                    );
                                    if (ok) {
                                      Get.snackbar(
                                        'Nhận đơn',
                                        'Bạn đã nhận đơn thành công',
                                        snackPosition: SnackPosition.BOTTOM,
                                      );
                                    } else {
                                      Get.snackbar(
                                        'Thất bại',
                                        'Nhận đơn không thành công',
                                        snackPosition: SnackPosition.BOTTOM,
                                        backgroundColor: Colors.redAccent,
                                        colorText: Colors.white,
                                      );
                                    }
                                  },
                                  label: const Text('Nhận đơn'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemCount: list.length,
                  );
                }

                // Other tabs
                final List<Map<String, dynamic>> source = ctrl.orders;
                List<Map<String, dynamic>> filtered;
                if (_tabIndex == 1) {
                  filtered = source; // Tất cả
                } else {
                  final statusLabel = _statusFilters[_tabIndex];
                  // Map tiếng Việt -> status code
                  String? wanted;
                  switch (statusLabel) {
                    case 'Đang giao':
                      wanted = 'Delivering';
                      break;
                    case 'Hoàn tất':
                      wanted = 'Delivered';
                      break;
                  }
                  filtered = wanted == null
                      ? source
                      : source
                            .where((o) => (o['orderStatus'] ?? '') == wanted)
                            .toList();
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
}
