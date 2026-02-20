import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// 二维码扫描页面
///
/// 用于扫描 TOTP 二维码，解析 otpauth:// URI
class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  bool _isScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫描二维码'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          // 相机预览
          MobileScanner(
            onDetect: (capture) {
              if (_isScanned) return;

              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final rawValue = barcode.rawValue;
                if (rawValue != null && rawValue.isNotEmpty) {
                  _isScanned = true;
                  _handleScanResult(rawValue);
                  break;
                }
              }
            },
          ),

          // 扫描框覆盖层
          CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _ScannerOverlay(),
          ),

          // 提示文字
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '将二维码放入框内即可自动扫描',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleScanResult(String value) {
    // 解析 TOTP URI
    final totpData = _parseTotpUri(value);

    if (totpData != null) {
      Navigator.pop(context, totpData);
    } else {
      // 如果不是有效的 TOTP URI，显示错误
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('无效的二维码'),
          content: const Text('无法识别 TOTP 二维码，请确保扫描的是正确的双因素认证二维码。'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _isScanned = false);
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
  }

  /// 解析 otpauth:// URI
  ///
  /// 格式: otpauth://totp/Label?secret=XXX&issuer=YYY&algorithm=SHA1&digits=6&period=30
  TotpScanResult? _parseTotpUri(String uri) {
    try {
      if (!uri.startsWith('otpauth://')) {
        return null;
      }

      final url = Uri.parse(uri);

      if (url.scheme != 'otpauth') {
        return null;
      }

      // 获取类型 (totp 或 hotp)
      final type = url.host;
      if (type != 'totp' && type != 'hotp') {
        return null;
      }

      // 获取标签 (路径部分)
      String label = url.path;
      if (label.startsWith('/')) {
        label = label.substring(1);
      }
      // URL 解码
      label = Uri.decodeComponent(label);

      // 获取参数
      final secret = url.queryParameters['secret'];
      final issuer = url.queryParameters['issuer'];
      final algorithm = url.queryParameters['algorithm'] ?? 'SHA1';
      final digits = int.tryParse(url.queryParameters['digits'] ?? '6') ?? 6;
      final period = int.tryParse(url.queryParameters['period'] ?? '30') ?? 30;

      if (secret == null || secret.isEmpty) {
        return null;
      }

      return TotpScanResult(
        secret: secret,
        label: label,
        issuer: issuer ?? '',
        algorithm: algorithm,
        digits: digits,
        period: period,
      );
    } catch (e) {
      return null;
    }
  }
}

/// 扫描结果
class TotpScanResult {
  final String secret;
  final String label;
  final String issuer;
  final String algorithm;
  final int digits;
  final int period;

  TotpScanResult({
    required this.secret,
    required this.label,
    required this.issuer,
    required this.algorithm,
    required this.digits,
    required this.period,
  });
}

/// 扫描框覆盖层绘制
class _ScannerOverlay extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;

    final scanAreaSize = size.width * 0.7;
    final scanAreaLeft = (size.width - scanAreaSize) / 2;
    final scanAreaTop = (size.height - scanAreaSize) / 2 - 50;

    // 绘制半透明背景
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final scanAreaPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(scanAreaLeft, scanAreaTop, scanAreaSize, scanAreaSize),
        const Radius.circular(12),
      ));

    // 使用 Path.combine 创建镂空效果
    final finalPath = Path.combine(
      PathOperation.difference,
      path,
      scanAreaPath,
    );

    canvas.drawPath(finalPath, paint);

    // 绘制扫描框边框
    final borderPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(scanAreaLeft, scanAreaTop, scanAreaSize, scanAreaSize),
        const Radius.circular(12),
      ),
      borderPaint,
    );

    // 绘制四个角的装饰
    final cornerPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;

    const cornerLength = 30;

    // 左上角
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop + cornerLength),
      Offset(scanAreaLeft, scanAreaTop),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop),
      Offset(scanAreaLeft + cornerLength, scanAreaTop),
      cornerPaint,
    );

    // 右上角
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize - cornerLength, scanAreaTop),
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop),
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + cornerLength),
      cornerPaint,
    );

    // 左下角
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop + scanAreaSize - cornerLength),
      Offset(scanAreaLeft, scanAreaTop + scanAreaSize),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop + scanAreaSize),
      Offset(scanAreaLeft + cornerLength, scanAreaTop + scanAreaSize),
      cornerPaint,
    );

    // 右下角
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize - cornerLength, scanAreaTop + scanAreaSize),
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + scanAreaSize),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + scanAreaSize - cornerLength),
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + scanAreaSize),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
