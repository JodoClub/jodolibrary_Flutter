import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';

class QRCodeGraphic extends StatelessWidget {
  final double size;
  final String? data;

  const QRCodeGraphic({super.key, this.size = 110, this.data});

  @override
  Widget build(BuildContext context) {
    if (data != null && data!.trim().isNotEmpty) {
      return Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.05),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.06),
          child: QrImageView(
            data: data!.trim(),
            version: QrVersions.auto,
            size: size,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: AppColors.slate900,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: AppColors.slate900,
            ),
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: _QRPainter(),
      ),
    );
  }
}

class _QRPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 100.0;

    void drawModule(double x, double y, double w, double h, Color color, [double r = 1.0]) {
      final paint = Paint()..color = color;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x * scale, y * scale, w * scale, h * scale),
        Radius.circular(r * scale),
      );
      canvas.drawRRect(rect, paint);
    }

    void drawMarker(double x, double y) {
      // Outer box
      drawModule(x, y, 26, 26, AppColors.slate900, 4);
      // White inner
      drawModule(x + 5, y + 5, 16, 16, Colors.white, 2);
      // Inner dot
      drawModule(x + 9, y + 9, 8, 8, AppColors.slate900, 1.5);
    }

    // 3 Position Markers
    drawMarker(6, 6);
    drawMarker(68, 6);
    drawMarker(6, 68);

    // Data Pattern Modules (Slate & Orange accent)
    final dark = AppColors.slate900;
    const orange = AppColors.orange500;

    drawModule(38, 8, 6, 6, dark);
    drawModule(48, 8, 6, 6, dark);
    drawModule(58, 14, 6, 6, orange);
    drawModule(38, 20, 6, 6, dark);
    drawModule(48, 26, 6, 6, dark);
    drawModule(58, 26, 6, 6, dark);

    drawModule(8, 38, 6, 6, dark);
    drawModule(18, 44, 6, 6, dark);
    drawModule(28, 38, 6, 6, dark);
    drawModule(38, 38, 8, 8, dark, 2);
    drawModule(54, 38, 8, 8, dark, 2);
    drawModule(46, 46, 8, 8, orange, 2);
    drawModule(68, 38, 6, 6, dark);
    drawModule(78, 44, 6, 6, dark);
    drawModule(86, 38, 6, 6, dark);

    drawModule(8, 54, 6, 6, dark);
    drawModule(18, 58, 6, 6, dark);
    drawModule(28, 54, 6, 6, dark);
    drawModule(38, 58, 6, 6, dark);
    drawModule(48, 66, 6, 6, dark);
    drawModule(58, 58, 6, 6, dark);
    drawModule(68, 54, 6, 6, dark);
    drawModule(82, 58, 6, 6, dark);

    drawModule(38, 76, 6, 6, dark);
    drawModule(48, 82, 6, 6, orange);
    drawModule(58, 76, 6, 6, dark);
    drawModule(68, 80, 6, 6, dark);
    drawModule(78, 74, 6, 6, dark);
    drawModule(86, 86, 6, 6, dark);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
