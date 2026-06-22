import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PieMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  PieMenuItem({required this.icon, required this.label, required this.onTap, this.color});
}

class PieMenu extends StatefulWidget {
  final Offset centerPosition;
  final List<PieMenuItem> items;
  final VoidCallback onClose;

  const PieMenu({
    super.key,
    required this.centerPosition,
    required this.items,
    required this.onClose,
  });

  @override
  State<PieMenu> createState() => _PieMenuState();
}

class _PieMenuState extends State<PieMenu> {
  int? _hoveredIndex;

  late double screenWidth;
  late double screenHeight;

  double _baseRotation = -pi / 2;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.of(context).size;
    screenWidth = size.width;
    screenHeight = size.height;
    
    _calculateOrientation();
  }

  void _calculateOrientation() {
    double x = widget.centerPosition.dx;
    double y = widget.centerPosition.dy;
    const r = 140.0; // approx ring + chip half-size

    bool canFitRight = (x + r < screenWidth) && (y - r > 0) && (y + r < screenHeight);
    bool canFitLeft = (x - r > 0) && (y - r > 0) && (y + r < screenHeight);
    bool canFitBottom = (y + r < screenHeight) && (x - r > 0) && (x + r < screenWidth);
    bool canFitTop = (y - r > 0) && (x - r > 0) && (x + r < screenWidth);
    
    if (canFitRight) {
      _baseRotation = -pi / 2;
    } else if (canFitLeft) {
      _baseRotation = pi / 2;
    } else if (canFitBottom) {
      _baseRotation = 0;
    } else if (canFitTop) {
      _baseRotation = pi;
    } else {
      _baseRotation = -pi / 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.items.length;
    const ringRadius = 90.0;
    const chipSize = 46.0;
    // Spread items over a 270° arc starting from _baseRotation.
    const arc = pi * 1.5;
    final startAngle = _baseRotation - arc / 2;
    final step = n > 1 ? arc / (n - 1) : 0.0;

    final children = <Widget>[
      Positioned.fill(
        child: GestureDetector(
          onTap: widget.onClose,
          behavior: HitTestBehavior.opaque,
          // Slight dim so the cream chips read on any background.
          child: Container(color: Colors.black.withValues(alpha: 0.18)),
        ),
      ),
    ];

    for (var i = 0; i < n; i++) {
      final a = startAngle + i * step;
      final cx = widget.centerPosition.dx + cos(a) * ringRadius;
      final cy = widget.centerPosition.dy + sin(a) * ringRadius;
      final hovered = _hoveredIndex == i;
      final item = widget.items[i];
      final accent = item.color ?? AppColors.textPrimary;

      // Chip
      children.add(Positioned(
        left: cx - chipSize / 2,
        top: cy - chipSize / 2,
        width: chipSize,
        height: chipSize,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hoveredIndex = i),
          onExit: (_) => setState(() => _hoveredIndex = null),
          child: GestureDetector(
            onTap: item.onTap,
            child: AnimatedScale(
              scale: hovered ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.backgroundPrimary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x55000000), blurRadius: 18, offset: Offset(0, 8)),
                  ],
                ),
                child: Icon(item.icon, color: accent, size: 21),
              ),
            ),
          ),
        ),
      ));

      // Label below the chip, only when hovered.
      if (hovered) {
        children.add(Positioned(
          left: cx - 60,
          top: cy + chipSize / 2 + 4,
          width: 120,
          child: IgnorePointer(
            child: Text(
              item.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.backgroundPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ));
      }
    }

    return Stack(children: children);
  }
}

class ArcClipper extends CustomClipper<Path> {
  final Offset center;
  final double startAngle;
  final double sweepAngle;
  final double innerRadius;
  final double outerRadius;

  ArcClipper({
    required this.center,
    required this.startAngle,
    required this.sweepAngle,
    required this.innerRadius,
    required this.outerRadius,
  });

  @override
  Path getClip(Size size) {
    final Path path = Path();
    
    path.arcTo(
      Rect.fromCircle(center: center, radius: outerRadius),
      startAngle,
      sweepAngle,
      true,
    );
    
    path.arcTo(
      Rect.fromCircle(center: center, radius: innerRadius),
      startAngle + sweepAngle,
      -sweepAngle,
      false,
    );
    
    path.close();
    return path;
  }

  @override
  bool shouldReclip(ArcClipper oldClipper) {
    return oldClipper.startAngle != startAngle ||
        oldClipper.sweepAngle != sweepAngle ||
        oldClipper.innerRadius != innerRadius ||
        oldClipper.outerRadius != outerRadius ||
        oldClipper.center != center;
  }
}
