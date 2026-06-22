import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/editorial.dart';
import '../../../core/providers/ai_provider.dart';
import '../../../core/providers/provider_registry.dart';
import '../../../core/services/shake_detector_service.dart';
import '../../../core/services/system_service.dart';
import '../onboarding/provider_setup_screen.dart';

/// Accent dot color per AI provider — small visual mnemonic.
const _providerAccents = {
  'Gemini': AppColors.accentViolet,
  'Claude': AppColors.accentCoral,
  'Groq': AppColors.accentCyan,
};

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shakeService = context.watch<ShakeDetectorService>();
    final registry = context.watch<ProviderRegistry>();
    final system = context.watch<SystemService>();

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: CenteredPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageHeader(eyebrow: 'Settings', title: 'Configure your assistant.'),
            const SizedBox(height: 24),
            _providersCard(context, registry),
            const SizedBox(height: 14),
            _shakeCard(context, shakeService),
            const SizedBox(height: 14),
            _startupCard(context, system),
          ],
        ),
      ),
    );
  }

  Widget _providersCard(BuildContext context, ProviderRegistry registry) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('AI Provider'),
          ...registry.providers.map((p) => _providerRow(context, p, registry)),
          const Divider(color: AppColors.glassBorder, height: 24),
          Text('Model for ${registry.active.providerName}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 6),
          _modelDropdown(context, registry),
          const SizedBox(height: 14),
          InkWell(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProviderSetupScreen())),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: const [
                  Expanded(
                    child: Text('Manage API keys',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                  ),
                  Icon(Icons.arrow_forward, color: AppColors.textMuted, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _providerRow(BuildContext context, AIProvider p, ProviderRegistry registry) {
    final accent = _providerAccents[p.providerName] ?? AppColors.ink;
    final isActive = registry.active.providerName == p.providerName;
    return InkWell(
      onTap: () => registry.setActive(p.providerName),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Row(
          children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.providerName,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text(p.modelId,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
            // Custom radio (dark, editorial)
            Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: isActive ? AppColors.ink : const Color(0xFFCFCABD),
                    width: isActive ? 5 : 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modelDropdown(BuildContext context, ProviderRegistry registry) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x22000000)),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: registry.active.modelId,
          dropdownColor: AppColors.glassSurface,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          icon: const Icon(Icons.expand_more, color: AppColors.textMuted, size: 18),
          items: registry.active.availableModels
              .map((m) => DropdownMenuItem(
                    value: m,
                    child: Text(m, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (m) {
            if (m != null) context.read<ProviderRegistry>().setModel(registry.active, m);
          },
        ),
      ),
    );
  }

  Widget _shakeCard(BuildContext context, ShakeDetectorService s) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Shake sensitivity'),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.ink,
              inactiveTrackColor: const Color(0xFFE7E3DA),
              thumbColor: AppColors.ink,
              overlayColor: AppColors.ink.withValues(alpha: 0.1),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            ),
            child: Slider(
              value: s.sensitivity.index / 2.0,
              onChanged: (v) => context
                  .read<ShakeDetectorService>()
                  .updateSensitivity(ShakeSensitivity.values[(v * 2).round()]),
              divisions: 2,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final l in const ['Low', 'Medium', 'High'])
                Text(l,
                    style: TextStyle(
                      color: s.sensitivity.name.toLowerCase() == l.toLowerCase()
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: s.sensitivity.name.toLowerCase() == l.toLowerCase()
                          ? FontWeight.w600
                          : FontWeight.normal,
                    )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _startupCard(BuildContext context, SystemService system) {
    return GlassCard(
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Launch at Windows startup',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                SizedBox(height: 2),
                Text('Starts silently in the system tray',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: system.launchAtStartup,
            onChanged: (v) => context.read<SystemService>().setLaunchAtStartup(v),
            activeThumbColor: AppColors.backgroundPrimary,
            activeTrackColor: AppColors.ink,
            inactiveThumbColor: AppColors.backgroundPrimary,
            inactiveTrackColor: const Color(0xFFCFCABD),
          ),
        ],
      ),
    );
  }
}
