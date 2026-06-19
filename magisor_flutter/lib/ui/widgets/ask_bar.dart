import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import 'glass_card.dart';

/// A glassmorphic command bar for the "What's on my screen?" flow.
///
/// The user types a free-form question; on submit it's sent up with the
/// current screenshot. Includes a full-screen scrim so tapping outside cancels.
class AskBar extends StatefulWidget {
  final void Function(String question) onSubmit;
  final VoidCallback onCancel;

  const AskBar({super.key, required this.onSubmit, required this.onCancel});

  @override
  State<AskBar> createState() => _AskBarState();
}

class _AskBarState extends State<AskBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  static const _suggestions = [
    'Summarize this screen',
    'What should I do next?',
    'Explain this error',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit([String? text]) {
    final q = (text ?? _controller.text).trim();
    if (q.isNotEmpty) widget.onSubmit(q);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Tap-outside-to-cancel scrim.
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onCancel,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.black.withValues(alpha: 0.15)),
          ),
        ),
        Align(
          alignment: const Alignment(0, -0.45),
          child: GlassCard(
            width: 540,
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppColors.accentCyan, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      "What's on your screen?",
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: widget.onCancel,
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, color: AppColors.textMuted, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        autofocus: true,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                        textInputAction: TextInputAction.send,
                        onSubmitted: _submit,
                        decoration: const InputDecoration(
                          hintText: 'Ask anything about what you see…',
                          hintStyle: TextStyle(color: AppColors.textMuted),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SendButton(onTap: _submit),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _suggestions.map(_suggestionChip).toList(),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 220.ms).slideY(begin: -0.12, curve: Curves.easeOut),
        ),
      ],
    );
  }

  Widget _suggestionChip(String text) {
    return InkWell(
      onTap: () => _submit(text),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.glassSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Text(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SendButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.accentViolet,
        ),
        child: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
      ),
    );
  }
}
