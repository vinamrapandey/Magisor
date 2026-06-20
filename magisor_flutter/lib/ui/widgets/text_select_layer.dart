import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'glass_card.dart';

/// A word and its bounding box in **overlay-logical** coordinates.
typedef PositionedWord = ({Rect rect, String text});

/// "Select Text" mode: the user drags a marquee across the OCR'd word boxes;
/// overlapping words highlight, and a toolbar offers actions on the joined text.
class TextSelectLayer extends StatefulWidget {
  final List<PositionedWord> words;
  final void Function(String action, String text) onAction;
  final VoidCallback onCancel;

  const TextSelectLayer({
    super.key,
    required this.words,
    required this.onAction,
    required this.onCancel,
  });

  @override
  State<TextSelectLayer> createState() => _TextSelectLayerState();
}

class _TextSelectLayerState extends State<TextSelectLayer> {
  Offset? _start;
  Offset? _current;
  final Set<int> _selected = {};

  Rect? get _dragRect =>
      (_start != null && _current != null) ? Rect.fromPoints(_start!, _current!) : null;

  void _recomputeSelection() {
    _selected.clear();
    final drag = _dragRect;
    if (drag == null) return;
    for (var i = 0; i < widget.words.length; i++) {
      if (widget.words[i].rect.overlaps(drag)) _selected.add(i);
    }
  }

  /// Selected words joined in reading order (top-to-bottom, left-to-right).
  String get _selectedText {
    final idx = _selected.toList()
      ..sort((a, b) {
        final ra = widget.words[a].rect;
        final rb = widget.words[b].rect;
        // Treat words on roughly the same line as one row.
        if ((ra.top - rb.top).abs() > ra.height * 0.6) {
          return ra.top.compareTo(rb.top);
        }
        return ra.left.compareTo(rb.left);
      });
    return idx.map((i) => widget.words[i].text).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final drag = _dragRect;
    final hasSelection = _selected.isNotEmpty;

    return Stack(
      children: [
        // Captures the drag across the whole screen.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => setState(() {
              _start = d.localPosition;
              _current = d.localPosition;
              _recomputeSelection();
            }),
            onPanUpdate: (d) => setState(() {
              _current = d.localPosition;
              _recomputeSelection();
            }),
            onTap: () {
              if (!hasSelection) widget.onCancel();
            },
            child: Container(color: Colors.black.withValues(alpha: 0.08)),
          ),
        ),

        // Highlight each selected word.
        for (final i in _selected)
          Positioned(
            left: widget.words[i].rect.left,
            top: widget.words[i].rect.top,
            width: widget.words[i].rect.width,
            height: widget.words[i].rect.height,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.accentCyan.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

        // The marquee outline.
        if (drag != null)
          Positioned(
            left: drag.left,
            top: drag.top,
            width: drag.width,
            height: drag.height,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.accentCyan, width: 1.5),
                ),
              ),
            ),
          ),

        // Top bar: hint + a one-tap "Select all".
        Align(
          alignment: const Alignment(0, -0.9),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.text_fields, color: AppColors.accentCyan, size: 16),
                const SizedBox(width: 8),
                Text(
                  widget.words.isEmpty ? 'No text detected on screen' : 'Drag across text to select',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                if (widget.words.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => setState(() {
                      _selected
                        ..clear()
                        ..addAll(List.generate(widget.words.length, (i) => i));
                    }),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accentViolet.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Select all',
                        style: TextStyle(color: AppColors.accentViolet, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Action toolbar once something is selected.
        if (hasSelection)
          Align(
            alignment: const Alignment(0, 0.86),
            child: _Toolbar(text: _selectedText, onAction: widget.onAction, onCancel: widget.onCancel),
          ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  final String text;
  final void Function(String action, String text) onAction;
  final VoidCallback onCancel;

  const _Toolbar({required this.text, required this.onAction, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.copy, 'Copy', 'copy'),
          _btn(Icons.translate, 'Translate', 'translate'),
          _btn(Icons.search, 'Search', 'search'),
          _btn(Icons.auto_awesome, 'Ask', 'ask'),
          const SizedBox(width: 4),
          InkWell(
            onTap: onCancel,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.close, color: AppColors.textMuted, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, String label, String action) {
    return InkWell(
      onTap: () => onAction(action, text),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textPrimary, size: 20),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
