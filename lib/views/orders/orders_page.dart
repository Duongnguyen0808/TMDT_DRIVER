import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/orders_controller.dart';
import 'order_detail_page.dart';
import '../widgets/shipper_appbar.dart';
import 'widgets/order_card.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final ctrl = Get.put(DriverOrdersController());
  int _tabIndex = 0;
  final List<String> _statusFilters = const [
    'All',
    'Preparing',
    'Delivering',
    'Delivered',
  ];

  @override
  void initState() {
    super.initState();
    ctrl.fetchMyOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ShipperAppBar(
        title: 'Đơn được giao',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ctrl.fetchMyOrders(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ctrl.fetchMyOrders(force: true),
        child: Column(
          children: [
            SizedBox(
              height: 48,
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
                final List<Map<String, dynamic>> source = ctrl.orders;
                List<Map<String, dynamic>> filtered;
                if (_tabIndex == 0) {
                  filtered = source;
                } else {
                  final status = _statusFilters[_tabIndex];
                  filtered = source
                      .where(
                        (o) => (o['orderStatus'] ?? '').toString() == status,
                      )
                      .toList();
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
