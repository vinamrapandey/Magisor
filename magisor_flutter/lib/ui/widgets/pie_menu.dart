import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

class PieMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  PieMenuItem({required this.icon, required this.label, required this.onTap});
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
  
  final double baseInnerRadius = 50.0;
  final double baseOuterRadius = 150.0;
  final double hoveredOuterRadius = 175.0;
  
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
    double r = hoveredOuterRadius;
    
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
    int count = widget.items.length;
    double totalSweep = pi;
    double sliceSweep = totalSweep / count;
    double gap = 0.05;

    List<Widget> children = [];
    
    for (int i = 0; i < count; i++) {
      double startAngle = _baseRotation + (i * sliceSweep) + (gap / 2);
      double activeSweep = sliceSweep - gap;
      bool isHovered = _hoveredIndex == i;
      double outerR = isHovered ? hoveredOuterRadius : baseOuterRadius;

      double midAngle = startAngle + (activeSweep / 2);
      double iconDist = baseInnerRadius + (baseOuterRadius - baseInnerRadius) * 0.5;
      if (isHovered) iconDist += 10;
      
      double iconX = widget.centerPosition.dx + iconDist * cos(midAngle);
      double iconY = widget.centerPosition.dy + iconDist * sin(midAngle);

      children.add(
        Positioned.fill(
          child: ClipPath(
            clipper: ArcClipper(
              center: widget.centerPosition,
              startAngle: startAngle,
              sweepAngle: activeSweep,
              innerRadius: baseInnerRadius,
              outerRadius: outerR,
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
              child: MouseRegion(
                onEnter: (_) => setState(() => _hoveredIndex = i),
                onExit: (_) => setState(() => _hoveredIndex = null),
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    widget.items[i].onTap();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    color: Colors.white.withValues(alpha: isHovered ? 0.3 : 0.1),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      
      children.add(
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          left: iconX - 40,
          top: iconY - (isHovered ? 25 : 15),
          width: 80,
          height: 60,
          child: IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.items[i].icon, 
                  color: Colors.black87,
                  size: isHovered ? 30 : 26,
                ),
                if (isHovered)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      widget.items[i].label,
                      style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        ...children,
      ],
    );
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
