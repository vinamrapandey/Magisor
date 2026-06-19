import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/saved_item.dart';
import '../../core/services/storage_service.dart';
import '../../core/utils/text_utils.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';

/// Full-screen view of a single stored AI interaction: the complete answer,
/// extracted text (copyable), and save/delete controls.
class EntryDetailScreen extends StatefulWidget {
  final SavedItem item;
  const EntryDetailScreen({super.key, required this.item});

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  late SavedItem _item = widget.item;

  StorageService get _storage => context.read<StorageService>();

  Future<void> _toggleSaved() async {
    await _storage.toggleSaved(_item);
    final updated = _storage.history.where((e) => e.id == _item.id);
    if (mounted && updated.isNotEmpty) setState(() => _item = updated.first);
  }

  Future<void> _delete() async {
    await _storage.deleteEntry(_item);
    if (mounted) Navigator.of(context).pop();
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }

  String _formatTime(DateTime t) =>
      '${t.day}/${t.month}/${t.year}  ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final url = firstUrl('${_item.summary}\n${_item.extractedText}');

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: const Text('Detail'),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            tooltip: _item.saved ? 'Unsave' : 'Save',
            icon: Icon(
              _item.saved ? Icons.bookmark : Icons.bookmark_border,
              color: _item.saved ? AppColors.accentCyan : AppColors.textMuted,
            ),
            onPressed: _toggleSaved,
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline, color: AppColors.textMuted),
            onPressed: _delete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentViolet.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_item.providerUsed,
                    style: const TextStyle(color: AppColors.accentViolet, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 10),
              Text(_formatTime(_item.timestamp),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 18),
          Text(_item.query,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              _item.summary.isNotEmpty ? _item.summary : '(no summary)',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.5),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _actionButton(Icons.copy, 'Copy answer',
                  () => _copy(_item.summary, 'Answer')),
              if (url != null)
                _actionButton(Icons.open_in_new, 'Open link', () => _openUrl(url)),
            ],
          ),
          if (_item.extractedText.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Extracted text',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                TextButton.icon(
                  onPressed: () => _copy(_item.extractedText, 'Extracted text'),
                  icon: const Icon(Icons.copy, size: 16, color: AppColors.accentCyan),
                  label: const Text('Copy', style: TextStyle(color: AppColors.accentCyan)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                _item.extractedText,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.glassSurface,
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.glassBorder),
        elevation: 0,
      ),
    );
  }
}
