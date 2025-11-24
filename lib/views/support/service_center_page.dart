import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/service_center_controller.dart';
import '../../models/service_ticket.dart';
import 'service_ticket_detail_page.dart';
import 'service_ticket_form_page.dart';

class ServiceCenterPage extends StatefulWidget {
  const ServiceCenterPage({super.key});

  @override
  State<ServiceCenterPage> createState() => _ServiceCenterPageState();
}

class _ServiceCenterPageState extends State<ServiceCenterPage> {
  late final ServiceCenterController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<ServiceCenterController>()
        ? Get.find<ServiceCenterController>()
        : Get.put(ServiceCenterController());
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Trung tâm dịch vụ',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => controller.fetchTickets(
              status: controller.selectedStatus.value.isEmpty
                  ? null
                  : controller.selectedStatus.value,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.to(() => const ServiceTicketFormPage()),
        backgroundColor: primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Tạo yêu cầu', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          _StatusStrip(controller: controller),
          const Divider(height: 1),
          Expanded(
            child: Obx(() {
              if (controller.loading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (controller.tickets.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () => controller.fetchTickets(
                    status: controller.selectedStatus.value.isEmpty
                        ? null
                        : controller.selectedStatus.value,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(32),
                    children: const [
                      Icon(Icons.support_agent, size: 72, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        'Bạn chưa có yêu cầu nào. Nhấn "Tạo yêu cầu" để bắt đầu.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () => controller.fetchTickets(
                  status: controller.selectedStatus.value.isEmpty
                      ? null
                      : controller.selectedStatus.value,
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: controller.tickets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    final ticket = controller.tickets[index];
                    return _TicketCard(ticket: ticket, controller: controller);
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  final ServiceCenterController controller;
  const _StatusStrip({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final metaStatuses = controller.metadata['statuses'];
      final List<String> statuses =
          (metaStatuses != null && metaStatuses.isNotEmpty)
          ? metaStatuses
          : ServiceTicket.defaultStatuses;
      final selected = controller.selectedStatus.value;
      return SizedBox(
        height: 56,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemBuilder: (_, idx) {
            final normalized = idx == 0 ? '' : statuses[idx - 1];
            final active = selected == normalized;
            return ChoiceChip(
              label: Text(
                idx == 0 ? 'Tất cả' : ServiceTicket.labelForStatus(normalized),
              ),
              selected: active,
              onSelected: (_) {
                controller.selectedStatus.value = normalized;
                controller.fetchTickets(
                  status: normalized.isEmpty ? null : normalized,
                );
              },
            );
          },
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemCount: statuses.length + 1,
        ),
      );
    });
  }
}

class _TicketCard extends StatelessWidget {
  final ServiceTicket ticket;
  final ServiceCenterController controller;
  const _TicketCard({required this.ticket, required this.controller});

  Color _statusColor(String status) {
    switch (status) {
      case 'Resolved':
      case 'Closed':
        return Colors.green.shade600;
      case 'WaitingRequester':
        return Colors.orange.shade600;
      case 'In Progress':
        return Colors.blue.shade600;
      default:
        return Colors.red.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final detail = await controller.fetchTicketDetail(ticket.id);
        if (detail != null) {
          Get.to(() => ServiceTicketDetailPage(ticketId: detail.id));
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ticket.subject,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(ticket.status).withOpacity(.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    ticket.readableStatus,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _statusColor(ticket.status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '#${ticket.code} • Ưu tiên ${ticket.readablePriority}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              ticket.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  ticket.timeAgo(),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
