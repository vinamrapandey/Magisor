import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Full-screen "Circle to Search" overlay: drag to draw a rectangle over any
/// part of the screen. Reports the selected rect (in logical pixels) on
/// release, or cancels on a tap without a drag.
class RegionSelector extends StatefulWidget {
  final void Function(Rect rect) onSelected;
  final VoidCallback onCancel;

  const RegionSelector({super.key, required this.onSelected, required this.onCancel});

  @override
  State<RegionSelector> createState() => _RegionSelectorState();
}

class _RegionSelectorState extends State<RegionSelector> {
  Offset? _start;
  Offset? _current;

  Rect? get _rect {
    if (_start == null || _current == null) return null;
    return Rect.fromPoints(_start!, _current!);
  }

  @override
  Widget build(BuildContext context) {
    final rect = _rect;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) => setState(() {
        _start = d.localPosition;
        _current = d.localPosition;
      }),
      onPanUpdate: (d) => setState(() => _current = d.localPosition),
      onPanEnd: (_) {
        final r = _rect;
        if (r != null && r.width >= 8 && r.height >= 8) {
          widget.onSelected(r);
        } else {
          widget.onCancel();
        }
      },
      onTap: widget.onCancel,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _ScrimPainter(rect))),
          if (rect != null)
            Positioned(
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.accentCyan, width: 2),
                ),
              ),
            ),
          if (rect == null)
            const Center(
              child: Text(
                'Drag to select a region',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScrimPainter extends CustomPainter {
  final Rect? hole;
  _ScrimPainter(this.hole);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x66000000);
    final h = hole;
    if (h == null) {
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }
    // Dim everywhere except the selected rectangle (even-odd punches the hole).
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRect(h)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.hole != hole;
}
