import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../controllers/shipper_controller.dart';

class ShipperRegistrationPage extends StatefulWidget {
  const ShipperRegistrationPage({super.key});
  @override
  State<ShipperRegistrationPage> createState() =>
      _ShipperRegistrationPageState();
}

class _ShipperRegistrationPageState extends State<ShipperRegistrationPage> {
  final ctrl = Get.put(ShipperController());
  late final WebViewController webviewController;
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final fullNameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final plateCtrl = TextEditingController();

  String vehicleType = 'motorbike';
  final vehicleTypeOptions = const {
    'motorbike': 'Xe máy',
    'car': 'Ô tô',
    'light_truck': 'Xe tải nhẹ',
    'heavy_truck': 'Xe tải nặng',
  };

  File? idFront;
  File? idBack;
  File? driverLicense;
  File? vehicleReg;
  File? selfie;

  String? idFrontUrl;
  String? idBackUrl;
  String? driverLicenseUrl;
  String? vehicleRegUrl;
  String? selfieUrl;

  String recaptchaToken = '';
  String? captchaError;
  bool captchaLoaded = false;

  bool get isLoggedIn => ctrl.token != null && (ctrl.token ?? '').isNotEmpty;

  final platePattern = RegExp(
    r'^[0-9]{2}[A-Z]{1,2}[- ]?[0-9]{3,4}\.[0-9]{2}$',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    final html = '''
<!DOCTYPE html><html><head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<script src="https://www.google.com/recaptcha/api.js" async defer></script>
<style>body{margin:0;padding:0;display:flex;justify-content:center;align-items:center;height:120px;} .g-recaptcha{transform:scale(0.9);transform-origin:0 0;}</style>
</head><body>
<div class="g-recaptcha" data-sitekey="6LcwzxAsAAAAAHqsTmx1pFehB0lXR_KzasTSUq0G" data-callback="captchaCallback"></div>
<script>
function captchaCallback(token){ Recaptcha.postMessage(token); }
</script>
</body></html>
''';
    webviewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'Recaptcha',
        onMessageReceived: (JavaScriptMessage msg) {
          setState(() {
            recaptchaToken = msg.message;
            captchaError = null;
          });
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            setState(() => captchaLoaded = true);
          },
        ),
      )
      ..loadHtmlString(html);
  }

  Future<void> pickDoc(String kind) async {
    final file = await ctrl.pickImage(ImageSource.gallery);
    if (file == null) return;
    setState(() {
      switch (kind) {
        case 'idFront':
          idFront = file;
          break;
        case 'idBack':
          idBack = file;
          break;
        case 'driverLicense':
          driverLicense = file;
          break;
        case 'vehicleReg':
          vehicleReg = file;
          break;
        case 'selfie':
          selfie = file;
          break;
      }
    });
  }

  Future<bool> uploadAll() async {
    // Parallel upload of all selected files
    final futures = <Future<void>>[];
    void addUpload(File? f, void Function(String url) setter) {
      if (f == null) return;
      futures.add(
        ctrl.uploadPublicImage(f).then((url) {
          if (url != null) setter(url);
        }),
      );
    }

    addUpload(idFront, (u) => idFrontUrl = u);
    addUpload(idBack, (u) => idBackUrl = u);
    addUpload(driverLicense, (u) => driverLicenseUrl = u);
    addUpload(vehicleReg, (u) => vehicleRegUrl = u);
    addUpload(selfie, (u) => selfieUrl = u);

    await Future.wait(futures);
    return [
      idFrontUrl,
      idBackUrl,
      driverLicenseUrl,
      vehicleRegUrl,
      selfieUrl,
    ].every((e) => (e ?? '').isNotEmpty);
  }

  Future<void> submit() async {
    if (!isLoggedIn &&
        (emailCtrl.text.trim().isEmpty || passCtrl.text.isEmpty)) {
      Get.snackbar('Thiếu thông tin', 'Nhập email & mật khẩu');
      return;
    }
    if (fullNameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
      Get.snackbar('Thiếu thông tin', 'Nhập họ tên & số điện thoại');
      return;
    }
    if (!platePattern.hasMatch(plateCtrl.text.trim())) {
      Get.snackbar('Biển số sai', 'Biển số không hợp lệ (vd: 29A-12345.67)');
      return;
    }
    if (recaptchaToken.isEmpty) {
      Get.snackbar('Thiếu CAPTCHA', 'Nhập mã reCAPTCHA trước khi gửi');
      return;
    }
    final okDocs = await uploadAll();
    if (!okDocs) {
      Get.snackbar('Lỗi', 'Upload tài liệu thất bại');
      return;
    }
    final success = await ctrl.publicApply(
      email: emailCtrl.text.trim(),
      password: passCtrl.text,
      fullName: fullNameCtrl.text.trim(),
      phone: phoneCtrl.text.trim(),
      vehicleType: vehicleType,
      vehiclePlate: plateCtrl.text.trim().toUpperCase(),
      idFrontUrl: idFrontUrl!,
      idBackUrl: idBackUrl!,
      driverLicenseUrl: driverLicenseUrl!,
      vehicleRegUrl: vehicleRegUrl!,
      selfieUrl: selfieUrl!,
      recaptchaToken: recaptchaToken,
    );
    if (success) {
      Get.snackbar('Thành công', 'Đã gửi hồ sơ. Chờ duyệt.');
      Navigator.pop(context);
    } else {
      Get.snackbar('Thất bại', 'Gửi hồ sơ không thành công');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký Shipper')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isLoggedIn) ...[
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mật khẩu'),
              ),
            ],
            TextField(
              controller: fullNameCtrl,
              decoration: const InputDecoration(labelText: 'Họ tên'),
            ),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Số điện thoại'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: vehicleType,
              items: vehicleTypeOptions.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => vehicleType = v ?? 'motorbike'),
              decoration: const InputDecoration(labelText: 'Loại xe'),
            ),
            TextField(
              controller: plateCtrl,
              decoration: const InputDecoration(
                labelText: 'Biển số xe (VD: 29A-12345.67)',
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _docButton(
                  'CMND/CCCD mặt trước',
                  idFront,
                  () => pickDoc('idFront'),
                ),
                _docButton(
                  'CMND/CCCD mặt sau',
                  idBack,
                  () => pickDoc('idBack'),
                ),
                _docButton(
                  'GPLX',
                  driverLicense,
                  () => pickDoc('driverLicense'),
                ),
                _docButton('ĐK xe', vehicleReg, () => pickDoc('vehicleReg')),
                _docButton('Ảnh selfie', selfie, () => pickDoc('selfie')),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Xác thực reCAPTCHA',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 130,
              child: Stack(
                children: [
                  WebViewWidget(controller: webviewController),
                  if (!captchaLoaded)
                    const Positioned.fill(
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                Text(
                  recaptchaToken.isEmpty ? 'Chưa xác thực' : 'Đã xác thực',
                  style: TextStyle(
                    color: recaptchaToken.isEmpty ? Colors.red : Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () {
                    setState(() {
                      recaptchaToken = '';
                      captchaLoaded = false;
                    });
                    webviewController.reload();
                  },
                  child: const Text('Làm mới'),
                ),
              ],
            ),
            if (captchaError != null)
              Text(
                captchaError!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            const SizedBox(height: 24),
            Obx(
              () => ElevatedButton(
                onPressed: ctrl.loading.value ? null : submit,
                child: ctrl.loading.value
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Gửi hồ sơ'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _docButton(String label, File? file, VoidCallback pick) {
    return SizedBox(
      width: 160,
      child: OutlinedButton(
        onPressed: pick,
        child: Column(
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Icon(
              file == null ? Icons.upload_file : Icons.check_circle,
              color: file == null ? Colors.grey : Colors.green,
            ),
          ],
        ),
      ),
    );
  }
}
