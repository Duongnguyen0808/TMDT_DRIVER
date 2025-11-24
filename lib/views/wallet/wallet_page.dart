import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/wallet_controller.dart';
import '../widgets/shipper_appbar.dart';
import 'wallet_topup_page.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  late final WalletController ctrl;
  final NumberFormat _currency = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    ctrl = Get.isRegistered<WalletController>()
        ? Get.find<WalletController>()
        : Get.put(WalletController());
  }

  Future<void> _refresh() => ctrl.fetchWallet(force: true);

  Future<void> _startTopup() async {
    final amount = await _promptAmount();
    if (amount == null) return;
    final url = await ctrl.createTopupIntent(amount);
    if (url == null) {
      final msg = ctrl.errorMessage.value ?? 'Không tạo được URL thanh toán';
      Get.snackbar('Lỗi', msg);
      return;
    }
    final success = await Get.to<bool>(() => WalletTopupPage(paymentUrl: url));
    if (success == true) {
      await ctrl.fetchWallet(force: true);
      Get.snackbar('Thành công', 'Vui lòng chờ ví cập nhật trong giây lát');
    }
  }

  Future<void> _handleQuickAdjust(bool increase) async {
    final amount = await _promptAmount(
      title: increase
          ? 'Nhập số tiền muốn cộng vào ví'
          : 'Nhập số tiền muốn trừ khỏi ví',
      confirmLabel: increase ? 'Cộng tiền' : 'Rút tiền',
    );
    if (amount == null) return;

    final success = await ctrl.adjustBalance(
      amount: amount,
      increase: increase,
      note: increase ? 'Manual credit' : 'Manual debit',
    );

    final message = increase
        ? 'Đã cộng tiền vào ví tài xế'
        : 'Đã trừ tiền khỏi ví tài xế';

    if (success) {
      Get.snackbar('Thành công', message);
    } else {
      final msg = ctrl.errorMessage.value ?? 'Không thực hiện được yêu cầu';
      Get.snackbar('Lỗi', msg);
    }
  }

  Future<int?> _promptAmount({
    String title = 'Nhập số tiền cần nạp',
    String hintText = 'Ví dụ: 200000',
    String initialValue = '200000',
    String confirmLabel = 'Tiếp tục',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final amount = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: hintText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Huỷ'),
            ),
            ElevatedButton(
              onPressed: () {
                final raw = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
                if (raw.isEmpty) {
                  Get.snackbar('Thiếu dữ liệu', 'Vui lòng nhập số tiền hợp lệ');
                  return;
                }
                final value = int.tryParse(raw);
                if (value == null || value <= 0) {
                  Get.snackbar('Sai định dạng', 'Số tiền phải lớn hơn 0');
                  return;
                }
                Navigator.of(ctx).pop(value);
              },
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return amount;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ShipperAppBar(
        title: 'Ví tài xế',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ctrl.fetchWallet(force: true),
          ),
        ],
      ),
      body: Obx(() {
        final summary = ctrl.wallet.value;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _balanceCard(summary),
              const SizedBox(height: 16),
              _transactionsCard(
                summary?.transactions ?? const <Map<String, dynamic>>[],
              ),
              const SizedBox(height: 16),
              _manualAdjustButtons(),
              const SizedBox(height: 80),
            ],
          ),
        );
      }),
      floatingActionButton: Obx(
        () => FloatingActionButton.extended(
          onPressed: ctrl.creatingTopup.value ? null : _startTopup,
          icon: const Icon(Icons.add_card),
          label: ctrl.creatingTopup.value
              ? const Text('Đang tạo link...')
              : const Text('Nạp tiền'),
        ),
      ),
    );
  }

  Widget _balanceCard(WalletSummary? summary) {
    final balanceText = summary == null
        ? '—'
        : _currency.format(summary.balance.toDouble());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Số dư hiện tại',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              balanceText,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            if (ctrl.errorMessage.value != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  ctrl.errorMessage.value!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            if (summary?.lastTopupAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Nạp gần nhất: ${_formatDate(summary!.lastTopupAt!)}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            if (summary?.lastChargeAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Khấu trừ gần nhất: ${_formatDate(summary!.lastChargeAt!)}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _transactionsCard(List<Map<String, dynamic>> transactions) {
    if (transactions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Lịch sử giao dịch',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              Text('Chưa có giao dịch nào gần đây'),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Lịch sử giao dịch',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            ...transactions.map((tx) => _transactionTile(tx)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _manualAdjustButtons() {
    final adjusting = ctrl.adjusting.value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: adjusting ? null : () => _handleQuickAdjust(true),
                label: Text(adjusting ? 'Đang xử lý...' : 'Cộng tiền'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: adjusting ? null : () => _handleQuickAdjust(false),
                label: Text(adjusting ? 'Đang xử lý...' : 'Rút tiền'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _transactionTile(Map<String, dynamic> tx) {
    final type = tx['type']?.toString() ?? '';
    final amountNum = tx['amount'] as num? ?? 0;
    final amountText = _currency.format(amountNum.toDouble());
    final color = amountNum >= 0 ? Colors.green : Colors.red;
    final desc = tx['description']?.toString() ?? '';
    final createdAt = tx['createdAt'];
    DateTime? created;
    if (createdAt is String) {
      try {
        created = DateTime.parse(createdAt).toLocal();
      } catch (_) {}
    }
    final balanceAfter = tx['balanceAfter'] as num?;
    final titleText = desc.isNotEmpty ? desc : _localizedTxType(type);
    return ListTile(
      leading: Icon(
        type == 'commission' ? Icons.trending_down : Icons.trending_up,
        color: color,
      ),
      title: Text(titleText),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (created != null) Text(_formatDate(created)),
          if (balanceAfter != null)
            Text('Số dư sau: ${_currency.format(balanceAfter.toDouble())}'),
        ],
      ),
      trailing: Text(
        amountText,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _localizedTxType(String type) {
    switch (type) {
      case 'topup':
        return 'Nạp ví';
      case 'commission':
        return 'Trừ tiền COD';
      case 'adjustment':
        return 'Điều chỉnh';
      case 'refund':
        return 'Hoàn tiền';
      default:
        return type;
    }
  }

  String _formatDate(DateTime dt) {
    return DateFormat('dd/MM HH:mm').format(dt);
  }
}
