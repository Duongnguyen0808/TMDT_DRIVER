import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

import '../../../controllers/orders_controller.dart';

class DeliveryProofSheet extends StatefulWidget {
  const DeliveryProofSheet({
    super.key,
    required this.controller,
    required this.orderId,
    this.initialRecipient,
    this.supplementOnly = false,
    this.preserveConfirmation = false,
  });

  final DriverOrdersController controller;
  final String orderId;
  final String? initialRecipient;
  final bool supplementOnly;
  final bool preserveConfirmation;

  @override
  State<DeliveryProofSheet> createState() => _DeliveryProofSheetState();
}

class _DeliveryProofSheetState extends State<DeliveryProofSheet> {
  final _recipientCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _picker = ImagePicker();
  XFile? _photo;
  Position? _position;
  bool _submitting = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialRecipient != null &&
        widget.initialRecipient!.isNotEmpty) {
      _recipientCtrl.text = widget.initialRecipient!;
    }
  }

  @override
  void dispose() {
    _recipientCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        setState(() => _photo = picked);
      }
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể mở camera/ảnh: $e');
    }
  }

  Future<void> _captureLocation() async {
    setState(() => _locating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Get.snackbar('GPS tắt', 'Bật dịch vụ vị trí để lưu tọa độ bàn giao');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Get.snackbar(
            'Thiếu quyền truy cập',
            'Cho phép ứng dụng dùng vị trí để xác minh bàn giao',
          );
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        Get.snackbar(
          'Thiếu quyền truy cập',
          'Hãy bật quyền vị trí cho ứng dụng trong phần cài đặt',
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() => _position = pos);
    } catch (e) {
      Get.snackbar('Lỗi định vị', e.toString());
    } finally {
      setState(() => _locating = false);
    }
  }

  Future<void> _submit() async {
    if (_photo == null) {
      Get.snackbar('Thiếu ảnh', 'Chụp ít nhất một ảnh bằng chứng bàn giao');
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final url = await widget.controller.uploadProofPhoto(File(_photo!.path));
      if (url == null || url.isEmpty) {
        Get.snackbar('Tải ảnh thất bại', 'Không thể tải ảnh lên, thử lại sau');
        return;
      }
      final ok = await widget.controller.submitDeliveryProof(
        widget.orderId,
        photoUrl: url,
        note: _noteCtrl.text,
        recipient: _recipientCtrl.text,
        latitude: _position?.latitude,
        longitude: _position?.longitude,
        keepConfirmation: widget.preserveConfirmation,
        supplementOnly: widget.supplementOnly,
      );
      if (ok) {
        if (mounted) Navigator.of(context).pop(true);
        final msg = widget.supplementOnly
            ? 'Đã bổ sung bằng chứng cho tranh chấp'
            : 'Đang chờ shop xác nhận';
        Get.snackbar('Đã gửi', msg);
      } else {
        Get.snackbar('Gửi thất bại', 'Hãy thử lại hoặc kiểm tra kết nối');
      }
    } catch (e) {
      Get.snackbar('Lỗi', e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lat = _position?.latitude;
    final lng = _position?.longitude;
    final hasPhoto = _photo != null;
    final isSupplement = widget.supplementOnly;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    isSupplement ? 'Bổ sung bằng chứng' : 'Bằng chứng bàn giao',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _submitting
                    ? null
                    : () => _pickPhoto(ImageSource.camera),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.shade400,
                        width: hasPhoto ? 0 : 1.2,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: hasPhoto
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(File(_photo!.path), fit: BoxFit.cover),
                              Positioned(
                                right: 12,
                                bottom: 12,
                                child: ElevatedButton.icon(
                                  onPressed: _submitting
                                      ? null
                                      : () => _pickPhoto(ImageSource.camera),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black.withOpacity(
                                      .6,
                                    ),
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.camera_alt_outlined),
                                  label: const Text('Chụp lại'),
                                ),
                              ),
                            ],
                          )
                        : Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.camera_alt,
                                  size: 48,
                                  color: Colors.black45,
                                ),
                                SizedBox(height: 8),
                                Text('Chạm để chụp ảnh bàn giao'),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _recipientCtrl,
                decoration: const InputDecoration(
                  labelText: 'Người nhận (khách hoặc người nhà)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú thêm (tuỳ chọn)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _locating || _submitting
                          ? null
                          : _captureLocation,
                      icon: _locating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_outlined),
                      label: Text(
                        lat != null
                            ? 'Lưu vị trí (${lat.toStringAsFixed(4)}, ${lng?.toStringAsFixed(4) ?? ''})'
                            : 'Ghi lại vị trí',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                ),
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  _submitting
                      ? 'Đang gửi...'
                      : (isSupplement
                            ? 'GỬI BẰNG CHỨNG BỔ SUNG'
                            : 'GỬI CHO SHOP'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
