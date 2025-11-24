import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/service_center_controller.dart';
import '../../models/service_ticket.dart';

class ServiceTicketFormPage extends StatefulWidget {
  const ServiceTicketFormPage({super.key});

  @override
  State<ServiceTicketFormPage> createState() => _ServiceTicketFormPageState();
}

class _ServiceTicketFormPageState extends State<ServiceTicketFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  String? _selectedCategory;
  String? _selectedPriority;

  late final ServiceCenterController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<ServiceCenterController>()
        ? Get.find<ServiceCenterController>()
        : Get.put(ServiceCenterController());
    final categories = controller.metadata['categories'];
    final priorities = controller.metadata['priorities'];
    final List<String> categoryOptions =
        (categories != null && categories.isNotEmpty)
        ? List<String>.from(categories)
        : ServiceTicket.defaultCategories;
    final List<String> priorityOptions =
        (priorities != null && priorities.isNotEmpty)
        ? List<String>.from(priorities)
        : ServiceTicket.defaultPriorities;
    _selectedCategory = categoryOptions.first;
    _selectedPriority = priorityOptions.first;
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await controller.createTicket(
      subject: _subjectCtrl.text,
      description: _descriptionCtrl.text,
      category: _selectedCategory,
      priority: _selectedPriority,
    );
    if (ok && mounted) {
      Get.back();
      Get.snackbar(
        'Trung tâm dịch vụ',
        'Đã gửi yêu cầu hỗ trợ thành công',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final categories = controller.metadata['categories'];
    final priorities = controller.metadata['priorities'];
    final List<String> categoryOptions =
        (categories != null && categories.isNotEmpty)
        ? List<String>.from(categories)
        : ServiceTicket.defaultCategories;
    final List<String> priorityOptions =
        (priorities != null && priorities.isNotEmpty)
        ? List<String>.from(priorities)
        : ServiceTicket.defaultPriorities;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Tạo yêu cầu mới',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _subjectCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tiêu đề',
                      hintText: 'Ví dụ: Không nhận được đơn mới',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vui lòng nhập tiêu đề';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Danh mục'),
                    items: categoryOptions
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(ServiceTicket.labelForCategory(c)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedCategory = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedPriority,
                    decoration: const InputDecoration(labelText: 'Độ ưu tiên'),
                    items: priorityOptions
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(ServiceTicket.labelForPriority(p)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedPriority = value),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionCtrl,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả chi tiết',
                      hintText:
                          'Hãy mô tả vấn đề để đội hỗ trợ xử lý nhanh nhất',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().length < 20) {
                        return 'Vui lòng mô tả ít nhất 20 ký tự';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Obx(() {
                    final busy = controller.submitting.value;
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                        label: Text(busy ? 'Đang gửi...' : 'Gửi yêu cầu'),
                        onPressed: busy ? null : _submit,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
