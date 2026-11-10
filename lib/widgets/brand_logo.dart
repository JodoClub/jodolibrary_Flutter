import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  final bool compact;
  final bool inverse;
  final double? height;

  const BrandLogo({
    super.key,
    this.compact = false,
    this.inverse = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final double defaultHeight = compact ? 32.0 : 44.0;
    final double effectiveHeight = height ?? defaultHeight;

    final logoImage = Image.asset(
      'assets/images/logo.png',
      height: effectiveHeight,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    if (inverse) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(compact ? 10 : 14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: logoImage,
      );
    }

    return logoImage;
  }
}
