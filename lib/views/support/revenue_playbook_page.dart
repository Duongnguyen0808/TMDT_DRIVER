import 'package:flutter/material.dart';

class RevenuePlaybookPage extends StatefulWidget {
  const RevenuePlaybookPage({super.key, this.lastCompleted});

  final DateTime? lastCompleted;

  @override
  State<RevenuePlaybookPage> createState() => _RevenuePlaybookPageState();
}

class _RevenuePlaybookPageState extends State<RevenuePlaybookPage> {
  bool _marking = false;
  bool _completed = false;

  String _formatDate(DateTime? date) {
    if (date == null) return '--/--';
    final local = date.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final due = widget.lastCompleted?.add(const Duration(days: 7));
    final overdue = due != null && DateTime.now().isAfter(due);
    return Scaffold(
      appBar: AppBar(title: const Text('Playbook tăng doanh thu')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bài kiểm tra tuần này',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chủ đề: "Tại sao lại tăng doanh thu" (chuỗi Khách hàng → Người giao hàng → Nhà cung cấp).',
                    style: TextStyle(color: Colors.grey.shade800),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lần cuối hoàn thành: ${_formatDate(widget.lastCompleted)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  if (due != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Hạn kế tiếp: ${_formatDate(due)}',
                      style: TextStyle(
                        color: overdue ? Colors.red : Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: '1. Góc nhìn Khách hàng',
            bullets: const [
              'Vì sao khách sẵn sàng trả thêm? → Nhanh hơn, minh bạch hơn.',
              'Hỏi khách về trải nghiệm trước/sau. Ghi lại insight cụ thể.',
              'Đề xuất upsell/dịch vụ giá trị gia tăng bạn có thể hỗ trợ.',
            ],
            accent: Colors.blue,
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '2. Góc nhìn Người giao hàng',
            bullets: const [
              'Kiểm tra lại các điểm nghẽn: thời gian chờ, liên lạc với khách, tuyến đường.',
              'Đánh giá minh chứng: ảnh, định vị, ghi chú đã đủ thuyết phục chưa?',
              'Lập kế hoạch cải thiện trong ca tiếp theo (ví dụ: template nhắn tin nhanh).',
            ],
            accent: Colors.deepPurple,
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '3. Góc nhìn Nhà cung cấp',
            bullets: const [
              'Khoáy sâu câu hỏi "thu ngân ghi nhận doanh thu thế nào?".',
              'Trao đổi với cửa hàng về dữ liệu bạn vừa thu thập được từ khách.',
              'Đề xuất thử nghiệm nhỏ (ví dụ combo, upsell, thời gian giao cao điểm).',
            ],
            accent: Colors.orange,
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Checklist kết nối đầu cuối',
            bullets: const [
              'Bước 1: Gọi thử một khách hàng cũ và hỏi về lý do quay lại.',
              'Bước 2: Trình bày với cửa hàng 3 ý tưởng cải thiện kinh nghiệm giao hàng.',
              'Bước 3: Ghi chép và gửi lại cho nhóm vận hành qua ticket tuần.',
            ],
            accent: Colors.green,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _marking
                ? null
                : () async {
                    setState(() => _marking = true);
                    await Future.delayed(const Duration(milliseconds: 300));
                    if (!mounted) return;
                    setState(() {
                      _marking = false;
                      _completed = true;
                    });
                    if (mounted) {
                      Navigator.of(context).pop(DateTime.now());
                    }
                  },
            icon: _marking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.flag_outlined),
            label: Text(_completed ? 'ĐÃ ĐÁNH DẤU' : 'ĐÁNH DẤU ĐÃ HOÀN THÀNH'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.bullets,
    required this.accent,
  });

  final String title;
  final List<String> bullets;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: accent.withOpacity(.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bolt_outlined, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final bullet in bullets) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(
                    child: Text(bullet, style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}
