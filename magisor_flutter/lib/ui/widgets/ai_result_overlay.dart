import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/magisor_response.dart';
import '../../core/utils/text_utils.dart';
import '../theme/app_colors.dart';
import 'glass_card.dart';

class AIResultOverlay extends StatelessWidget {
  final bool isLoading;
  final MagisorResponse? result;
  final VoidCallback onClose;
  final Function(String followUpText) onFollowUp;
  final bool isSaved;
  final VoidCallback? onToggleSaved;
  final void Function(String question)? onAskFollowUp;

  const AIResultOverlay({
    super.key,
    required this.isLoading,
    this.result,
    required this.onClose,
    required this.onFollowUp,
    this.isSaved = false,
    this.onToggleSaved,
    this.onAskFollowUp,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: const CircularProgressIndicator(color: AppColors.accentViolet)
            .animate()
            .scale(duration: 400.ms, curve: Curves.easeOutBack),
      );
    }

    if (result == null) return const SizedBox();

    final url = firstUrl('${result!.summary}\n${result!.extractedText}');

    return Center(
      child: GlassCard(
        width: 400,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: AppColors.accentCyan, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Magisor (${result!.providerUsed})',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onToggleSaved != null)
                          IconButton(
                            tooltip: isSaved ? 'Saved' : 'Save',
                            icon: Icon(
                              isSaved ? Icons.bookmark : Icons.bookmark_border,
                              color: isSaved ? AppColors.accentCyan : AppColors.textMuted,
                            ),
                            onPressed: onToggleSaved,
                          ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.textMuted),
                          onPressed: onClose,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  result!.summary,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _utilButton(Icons.copy, 'Copy', () => _copy(context, result!.summary)),
                    if (url != null)
                      _utilButton(Icons.open_in_new, 'Open link', () => _openUrl(url)),
                  ],
                ),
                if (result!.extractedText.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Captured text', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      InkWell(
                        onTap: () => _copy(context, result!.extractedText),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.copy, size: 14, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.glassSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: SelectableText(
                      result!.extractedText,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
                if (result!.actions.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text('Suggested Actions:', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: result!.actions.map((action) => _buildActionChip(action)).toList(),
                  ),
                ],
                if (onAskFollowUp != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.glassSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    child: _FollowUpField(onSubmit: onAskFollowUp!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ).animate().fadeIn().slideY(begin: 0.1, curve: Curves.easeOut),
    );
  }

  Widget _buildActionChip(String label) {
    return InkWell(
      onTap: () => onFollowUp(label),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.accentViolet.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accentViolet.withValues(alpha: 0.5)),
        ),
        child: Text(label, style: const TextStyle(color: AppColors.accentViolet, fontSize: 12)),
      ),
    );
  }

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _utilButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.glassSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.textPrimary),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// Free-form follow-up input shown under a result, for multi-turn questions.
class _FollowUpField extends StatefulWidget {
  final void Function(String question) onSubmit;
  const _FollowUpField({required this.onSubmit});

  @override
  State<_FollowUpField> createState() => _FollowUpFieldState();
}

class _FollowUpFieldState extends State<_FollowUpField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            onSubmitted: (_) => _send(),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Ask a follow-up…',
              hintStyle: TextStyle(color: AppColors.textMuted),
              isDense: true,
              border: InputBorder.none,
            ),
          ),
        ),
        InkWell(
          onTap: _send,
          borderRadius: BorderRadius.circular(20),
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.send, size: 18, color: AppColors.accentViolet),
          ),
        ),
      ],
    );
  }
}
