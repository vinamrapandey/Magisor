import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Small uppercase letter-spaced eyebrow above a header (editorial style).
class Eyebrow extends StatelessWidget {
  final String text;
  const Eyebrow(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
        ),
      );
}

/// Big editorial page headline.
class PageHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  const PageHeader({super.key, required this.eyebrow, required this.title});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(eyebrow),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
        ],
      );
}

/// Small uppercase section label used inside cards.
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
      );
}

/// Centers and caps the width of long pages so wide-monitor layouts don't
/// stretch edge-to-edge. The fix for desktop responsiveness.
class CenteredPage extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  const CenteredPage({
    super.key,
    required this.child,
    this.maxWidth = 720,
    this.padding = const EdgeInsets.fromLTRB(24, 24, 24, 32),
  });
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: padding,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        ),
      );
}

/// Dark ink pill button (matches the reference's "Get in touch").
class InkButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  const InkButton({super.key, required this.label, this.icon, required this.onPressed});
  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.backgroundPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                if (icon != null) ...[
                  const SizedBox(width: 8),
                  Icon(icon, color: AppColors.backgroundPrimary, size: 16),
                ],
              ],
            ),
          ),
        ),
      );
}
