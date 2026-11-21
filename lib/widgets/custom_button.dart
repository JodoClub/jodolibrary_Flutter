import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum ButtonVariant { primary, secondary, ghost }

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final Widget? leading;
  final Widget? trailing;
  final double? width;
  final double height;

  const CustomButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.leading,
    this.trailing,
    this.width,
    this.height = 56.0,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    BorderSide border = BorderSide.none;
    List<BoxShadow> shadows = [];

    switch (variant) {
      case ButtonVariant.primary:
        bgColor = AppColors.orange500;
        textColor = Colors.white;
        shadows = [
          BoxShadow(
            color: AppColors.orange500.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ];
        break;
      case ButtonVariant.secondary:
        bgColor = Colors.white;
        textColor = AppColors.slate800;
        border = const BorderSide(color: AppColors.slate200, width: 1.5);
        break;
      case ButtonVariant.ghost:
        bgColor = AppColors.slate100;
        textColor = AppColors.slate600;
        break;
    }

    return Container(
      width: width ?? double.infinity,
      constraints: BoxConstraints(minHeight: height),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: border != BorderSide.none ? Border.fromBorderSide(border) : null,
        boxShadow: shadows,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
