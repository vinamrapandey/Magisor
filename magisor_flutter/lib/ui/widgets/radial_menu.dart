import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'glass_button.dart';

class RadialMenu extends StatefulWidget {
  final Offset centerPosition;
  final VoidCallback onClose;
  final Function(String action) onActionSelected;

  const RadialMenu({
    super.key,
    required this.centerPosition,
    required this.onClose,
    required this.onActionSelected,
  });

  @override
  State<RadialMenu> createState() => _RadialMenuState();
}

class _RadialMenuState extends State<RadialMenu> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  final List<_MenuAction> _actions = [
    _MenuAction('Summarize', Icons.short_text, 'summarize'),
    _MenuAction('Explain', Icons.lightbulb_outline, 'explain'),
    _MenuAction('Translate', Icons.translate, 'translate'),
    _MenuAction('Copy Text', Icons.copy, 'copy'),
    _MenuAction('Close', Icons.close, 'close'),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _rotationAnimation = Tween<double>(begin: -0.5, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleAction(_MenuAction action) async {
    await _controller.reverse();
    if (action.id == 'close') {
      widget.onClose();
    } else {
      widget.onActionSelected(action.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () async {
              await _controller.reverse();
              widget.onClose();
            },
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.black.withOpacity(0.01)),
          ),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Positioned(
              left: widget.centerPosition.dx - 150,
              top: widget.centerPosition.dy - 150,
              width: 300,
              height: 300,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Transform.rotate(
                  angle: _rotationAnimation.value,
                  child: Stack(
                    alignment: Alignment.center,
                    children: _buildBubbles(),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  List<Widget> _buildBubbles() {
    final double radius = 100.0;
    List<Widget> bubbles = [];
    final int count = _actions.length;
    final double angleStep = (2 * math.pi) / count;
    final double startAngle = -math.pi / 2;

    for (int i = 0; i < count; i++) {
      final double angle = startAngle + (i * angleStep);
      final double x = radius * math.cos(angle);
      final double y = radius * math.sin(angle);

      bubbles.add(
        Transform.translate(
          offset: Offset(x, y),
          child: GlassButton(
            icon: _actions[i].icon,
            label: _actions[i].label,
            size: 72.0,
            onTap: () => _handleAction(_actions[i]),
          ),
        ),
      );
    }
    
    bubbles.add(
      GlassButton(
        icon: Icons.auto_awesome,
        label: 'Magisor',
        size: 56.0,
        onTap: () async {
          await _controller.reverse();
          widget.onClose();
        },
      )
    );

    return bubbles;
  }
}

class _MenuAction {
  final String label;
  final IconData icon;
  final String id;
  _MenuAction(this.label, this.icon, this.id);
}