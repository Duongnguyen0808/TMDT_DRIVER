import 'package:flutter/material.dart';

class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, this.onTap});

  final Map<String, dynamic> order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final id = (order['_id'] ?? '').toString();
    final shortId = id.isNotEmpty && id.length > 6
        ? id.substring(id.length - 6)
        : id;
    final status = (order['orderStatus'] ?? '').toString();
    final storeTitle = (order['storeId']?['title'] ?? '').toString();
    final addr = (order['deliveryAddress']?['addressLine1'] ?? '').toString();
    final double grandTotal =
        double.tryParse(order['grandTotal']?.toString() ?? '0') ?? 0;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _statusGradient(status),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: _statusColor(status).withOpacity(.15),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(_statusIcon(status), color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Đơn #$shortId',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      _StatusChip(
                        status: status,
                        label: _statusLabel(status),
                        color: _statusColor(status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (storeTitle.isNotEmpty)
                    Text(
                      'Cửa hàng: $storeTitle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (addr.isNotEmpty)
                    Text(
                      'Địa chỉ: $addr',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 6),
                  Text(
                    'Tổng: ${grandTotal.toStringAsFixed(0)}đ',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Preparing':
        return Colors.deepOrangeAccent;
      case 'Delivering':
        return Colors.indigo;
      case 'Delivered':
        return Colors.green.shade600;
      case 'Cancelled':
        return Colors.grey.shade600;
      case 'Rejected':
        return Colors.redAccent;
      default:
        return Colors.blueGrey;
    }
  }

  List<Color> _statusGradient(String s) {
    final base = _statusColor(s);
    return [base.withOpacity(.85), base.withOpacity(.55)];
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'Preparing':
        return Icons.hourglass_bottom;
      case 'Delivering':
        return Icons.local_shipping;
      case 'Delivered':
        return Icons.check_circle_outline;
      case 'Cancelled':
        return Icons.block;
      case 'Rejected':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'Preparing':
        return 'Chuẩn bị';
      case 'Delivering':
        return 'Đang giao';
      case 'Delivered':
        return 'Hoàn tất';
      case 'Cancelled':
        return 'Hủy';
      case 'Rejected':
        return 'Từ chối';
      default:
        return s;
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.status,
    required this.label,
    required this.color,
  });
  final String status;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_miniIcon(), size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  IconData _miniIcon() {
    switch (status) {
      case 'Preparing':
        return Icons.hourglass_empty;
      case 'Delivering':
        return Icons.delivery_dining;
      case 'Delivered':
        return Icons.check;
      case 'Cancelled':
        return Icons.block;
      case 'Rejected':
        return Icons.close;
      default:
        return Icons.help_outline;
    }
  }
}
