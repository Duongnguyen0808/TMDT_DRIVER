import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/service_center_controller.dart';
import '../../models/service_ticket.dart';

class ServiceTicketDetailPage extends StatefulWidget {
  final String ticketId;
  const ServiceTicketDetailPage({super.key, required this.ticketId});

  @override
  State<ServiceTicketDetailPage> createState() =>
      _ServiceTicketDetailPageState();
}

class _ServiceTicketDetailPageState extends State<ServiceTicketDetailPage> {
  late final ServiceCenterController controller;
  final _replyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<ServiceCenterController>()
        ? Get.find<ServiceCenterController>()
        : Get.put(ServiceCenterController());
    controller.fetchTicketDetail(widget.ticketId);
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  ServiceTicket? _currentTicket() {
    try {
      return controller.tickets.firstWhere((t) => t.id == widget.ticketId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;
    final ok = await controller.replyTicket(
      ticketId: widget.ticketId,
      body: text,
    );
    if (ok) {
      _replyCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Chi tiết yêu cầu',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Obx(() {
        final ticket = _currentTicket();
        if (ticket == null || controller.detailLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            _TicketHeader(ticket: ticket),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemBuilder: (_, index) {
                  final message = ticket.messages[index];
                  final alignRight = message.authorType == 'Driver';
                  return Align(
                    alignment: alignRight
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: alignRight
                            ? primary.withOpacity(.12)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${message.authorName} • ${_format(message.createdAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(message.body),
                        ],
                      ),
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemCount: ticket.messages.length,
              ),
            ),
            const Divider(height: 1),
            _ReplyBox(
              controller: controller,
              replyCtrl: _replyCtrl,
              onSend: _sendReply,
              disabled:
                  ticket.status == 'Closed' || ticket.status == 'Resolved',
            ),
          ],
        );
      }),
    );
  }

  String _format(DateTime dt) {
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }
}

class _TicketHeader extends StatelessWidget {
  final ServiceTicket ticket;
  const _TicketHeader({required this.ticket});

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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ticket.subject,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Chip(
                label: Text(ticket.readableStatus),
                backgroundColor: _statusColor(ticket.status).withOpacity(.15),
                labelStyle: TextStyle(color: _statusColor(ticket.status)),
              ),
              Chip(label: Text('Ưu tiên ${ticket.readablePriority}')),
              Chip(label: Text(ticket.readableCategory)),
              ...ticket.tags.map((tag) => Chip(label: Text(tag))).toList(),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Mã yêu cầu: ${ticket.code}',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          Text(
            'Cập nhật: ${DateFormat('dd/MM/yyyy HH:mm').format(ticket.updatedAt)}',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _ReplyBox extends StatelessWidget {
  final TextEditingController replyCtrl;
  final VoidCallback onSend;
  final ServiceCenterController controller;
  final bool disabled;
  const _ReplyBox({
    required this.replyCtrl,
    required this.onSend,
    required this.controller,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final hint = disabled
        ? 'Yêu cầu đã đóng, không thể phản hồi'
        : 'Nhập phản hồi của bạn...';
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(12),
        color: Colors.white,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: replyCtrl,
                minLines: 1,
                maxLines: 4,
                enabled: !disabled,
                decoration: InputDecoration(
                  hintText: hint,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Obx(() {
              final busy = controller.detailLoading.value;
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: busy || disabled ? null : onSend,
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send),
              );
            }),
          ],
        ),
      ),
    );
  }
}
