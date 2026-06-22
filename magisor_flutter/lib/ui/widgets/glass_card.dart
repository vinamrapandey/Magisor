import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A clean editorial card: white surface, hairline border, soft shadow,
/// rounded corners. (Name kept as GlassCard for compatibility.)
class GlassCard extends StatelessWidget {
  final Widget? child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry? borderRadius;

  const GlassCard({
    super.key,
    this.child,
    this.width,
    this.height,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(16);
    return Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.glassSurface,
        borderRadius: br is BorderRadius ? br : BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder, width: 1),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      // Transparent Material so InkWell/ListTile ripples paint correctly.
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}
