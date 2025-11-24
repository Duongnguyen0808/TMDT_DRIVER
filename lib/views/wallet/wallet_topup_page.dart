import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../widgets/shipper_appbar.dart';

class WalletTopupPage extends StatefulWidget {
  const WalletTopupPage({super.key, required this.paymentUrl});

  final String paymentUrl;

  @override
  State<WalletTopupPage> createState() => _WalletTopupPageState();
}

class _WalletTopupPageState extends State<WalletTopupPage> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _handledResult = false;
  String? _statusText;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() => _loading = true);
          },
          onPageFinished: (url) {
            if (!mounted) return;
            setState(() => _loading = false);
            _detectCallback(url);
          },
          onNavigationRequest: (request) {
            _detectCallback(request.url);
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ShipperAppBar(
        title: 'Thanh toán VNPay',
        actions: [
          TextButton(
            onPressed: () => _complete(false),
            child: const Text('Đóng', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_statusText != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 24,
              child: Card(
                color: Colors.black.withOpacity(0.7),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _statusText!,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle),
                onPressed: () => _complete(true),
                label: const Text('Đã thanh toán, kiểm tra ví'),
              ),
              TextButton(
                onPressed: () => _complete(false),
                child: const Text('Huỷ và quay lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _detectCallback(String url) {
    if (!url.contains('vnp_ResponseCode') || _handledResult) {
      return;
    }
    Uri? uri;
    try {
      uri = Uri.parse(url);
    } catch (_) {
      return;
    }
    final code =
        uri.queryParameters['vnp_ResponseCode'] ??
        uri.queryParameters['vnp_response_code'] ??
        uri.queryParameters['vnp_responsecode'];
    if (code == null) return;
    final success = code == '00';
    if (!mounted) return;
    setState(() {
      _statusText = success
          ? 'Thanh toán thành công. Nhấn Quay lại để cập nhật ví.'
          : 'Thanh toán chưa hoàn tất (mã $code).';
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      _complete(success);
    });
  }

  void _complete(bool success) {
    if (_handledResult || !mounted) return;
    _handledResult = true;
    Navigator.of(context).pop(success);
  }
}
