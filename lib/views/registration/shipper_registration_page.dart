import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../controllers/shipper_controller.dart';
import '../widgets/shipper_appbar.dart';

class ShipperRegistrationPage extends StatefulWidget {
  const ShipperRegistrationPage({super.key});
  @override
  State<ShipperRegistrationPage> createState() =>
      _ShipperRegistrationPageState();
}

class _ShipperRegistrationPageState extends State<ShipperRegistrationPage> {
  final ctrl = Get.put(ShipperController());
  final fullNameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  // Loại xe chọn từ danh sách (không nhập tay)
  final Map<String, String> vehicleTypesVi = {
    'motorbike': 'Xe máy',
    'car': 'Ô tô',
    'light_truck': 'Xe tải nhẹ',
    'heavy_truck': 'Xe tải nặng',
  };
  String selectedVehicleType = 'motorbike';
  final vehiclePlateCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  File? idFront;
  File? idBack;
  File? driverLicense;
  File? vehicleReg;
  File? selfie;

  String recaptchaToken = '';

  bool get isLoggedIn => ctrl.token != null && ctrl.token!.isNotEmpty;

  Future<void> _pickFor(void Function(File f) setter) async {
    final f = await ctrl.pickImage(ImageSource.gallery);
    if (f != null) setState(() => setter(f));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ShipperAppBar(title: 'Đăng ký Shipper'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isLoggedIn) ...[
              const Text(
                'Tạo tài khoản để gửi hồ sơ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passwordCtrl,
                decoration: const InputDecoration(labelText: 'Mật khẩu'),
                obscureText: true,
              ),
              const Divider(height: 32),
            ],
            TextField(
              controller: fullNameCtrl,
              decoration: const InputDecoration(labelText: 'Họ và tên'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Số điện thoại'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedVehicleType,
              decoration: const InputDecoration(labelText: 'Loại xe'),
              items: vehicleTypesVi.entries
                  .map(
                    (e) => DropdownMenuItem<String>(
                      value: e.key,
                      child: Text(e.value),
                    ),
                  )
                  .toList(),
              onChanged: (v) =>
                  setState(() => selectedVehicleType = v ?? 'motorbike'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: vehiclePlateCtrl,
              decoration: const InputDecoration(labelText: 'Biển số xe'),
            ),
            const SizedBox(height: 16),
            const Text('Tải ảnh giấy tờ:'),
            const SizedBox(height: 8),
            _docRow(
              'CMND/CCCD mặt trước',
              idFront,
              () => _pickFor((f) => idFront = f),
            ),
            _docRow(
              'CMND/CCCD mặt sau',
              idBack,
              () => _pickFor((f) => idBack = f),
            ),
            _docRow(
              'Bằng lái xe',
              driverLicense,
              () => _pickFor((f) => driverLicense = f),
            ),
            _docRow(
              'Đăng ký xe',
              vehicleReg,
              () => _pickFor((f) => vehicleReg = f),
            ),
            _docRow(
              'Ảnh chân dung (selfie)',
              selfie,
              () => _pickFor((f) => selfie = f),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: recaptchaToken == 'ok',
              onChanged: (val) {
                setState(() => recaptchaToken = val == true ? 'ok' : '');
              },
              title: const Text('Tôi không phải robot'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 16),
            Obx(
              () => ElevatedButton.icon(
                onPressed: ctrl.loading.value ? null : _submit,
                icon: ctrl.loading.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  isLoggedIn ? 'Gửi hồ sơ' : 'Tạo tài khoản & gửi hồ sơ',
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (isLoggedIn)
              TextButton(
                onPressed: _checkStatus,
                child: const Text('Kiểm tra trạng thái hồ sơ của tôi'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _docRow(String label, File? file, VoidCallback onPick) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        if (file != null) const Icon(Icons.check_circle, color: Colors.green),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: onPick, child: const Text('Chọn ảnh')),
      ],
    );
  }

  Future<void> _submit() async {
    // Validate trước, chỉ set loading khi thực sự gọi mạng
    if (fullNameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
      Get.snackbar('Thiếu thông tin', 'Vui lòng nhập họ tên và số điện thoại');
      return;
    }
    if ([
      idFront,
      idBack,
      driverLicense,
      vehicleReg,
      selfie,
    ].any((f) => f == null)) {
      Get.snackbar('Thiếu giấy tờ', 'Vui lòng tải đủ 5 ảnh giấy tờ');
      return;
    }
    if (!isLoggedIn &&
        (emailCtrl.text.trim().isEmpty ||
            passwordCtrl.text.trim().length < 6)) {
      Get.snackbar('Thiếu thông tin', 'Email và mật khẩu (>=6 ký tự) bắt buộc');
      return;
    }
    ctrl.loading.value = true; // bắt đầu tiến trình thật sự
    try {
      final uploadFn = isLoggedIn ? ctrl.uploadImage : ctrl.uploadPublicImage;
      final urls = <String?>[];
      urls.add(await uploadFn(idFront!));
      urls.add(await uploadFn(idBack!));
      urls.add(await uploadFn(driverLicense!));
      urls.add(await uploadFn(vehicleReg!));
      urls.add(await uploadFn(selfie!));
      if (urls.any((u) => u == null)) {
        Get.snackbar('Lỗi', 'Tải ảnh thất bại, thử lại');
        return;
      }
      bool ok;
      if (isLoggedIn) {
        ok = await ctrl.submitApplication(
          fullName: fullNameCtrl.text.trim(),
          phone: phoneCtrl.text.trim(),
          vehicleType: selectedVehicleType,
          vehiclePlate: vehiclePlateCtrl.text.trim(),
          idFrontUrl: urls[0]!,
          idBackUrl: urls[1]!,
          driverLicenseUrl: urls[2]!,
          vehicleRegUrl: urls[3]!,
          selfieUrl: urls[4]!,
        );
      } else {
        ok = await ctrl.publicApply(
          email: emailCtrl.text.trim(),
          password: passwordCtrl.text.trim(),
          fullName: fullNameCtrl.text.trim(),
          phone: phoneCtrl.text.trim(),
          vehicleType: selectedVehicleType,
          vehiclePlate: vehiclePlateCtrl.text.trim(),
          idFrontUrl: urls[0]!,
          idBackUrl: urls[1]!,
          driverLicenseUrl: urls[2]!,
          vehicleRegUrl: urls[3]!,
          selfieUrl: urls[4]!,
          recaptchaToken: recaptchaToken,
        );
      }
      if (ok) {
        Get.snackbar(
          'Thành công',
          isLoggedIn
              ? 'Đã gửi hồ sơ, vui lòng chờ duyệt'
              : 'Đã tạo tài khoản & gửi hồ sơ',
        );
        Navigator.of(context).pop();
      } else {
        Get.snackbar('Lỗi', 'Không gửi được hồ sơ');
      }
    } finally {
      ctrl.loading.value = false;
    }
  }

  Future<void> _checkStatus() async {
    final app = await ctrl.getMyApplication();
    if (app == null) {
      Get.snackbar('Thông báo', 'Chưa có hồ sơ');
      return;
    }
    final status = app['approvalStatus'] ?? 'unknown';
    final reason = app['rejectionReason'] ?? '';
    Get.dialog(
      AlertDialog(
        title: const Text('Trạng thái hồ sơ'),
        content: Text(
          'Trạng thái: $status${reason.isNotEmpty ? "\nLý do: $reason" : ""}',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Đóng')),
        ],
      ),
    );
  }
}
