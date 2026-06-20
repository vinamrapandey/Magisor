import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/glass_card.dart';
import '../../../core/providers/provider_registry.dart';
import '../../../core/services/shake_detector_service.dart';
import '../../../core/services/system_service.dart';
import '../onboarding/provider_setup_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shakeService = context.watch<ShakeDetectorService>();
    final registry = context.watch<ProviderRegistry>();
    final system = context.watch<SystemService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: AppColors.textPrimary)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Providers', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Active provider used for screen analysis', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 8),
                ...registry.providers.map(
                  (p) => RadioListTile<String>(
                    value: p.providerName,
                    groupValue: registry.active.providerName,
                    onChanged: (name) {
                      if (name != null) registry.setActive(name);
                    },
                    activeColor: AppColors.accentViolet,
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.providerName, style: const TextStyle(color: AppColors.textPrimary)),
                    subtitle: Text(p.modelId, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Model for ${registry.active.providerName}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                DropdownButton<String>(
                  isExpanded: true,
                  value: registry.active.modelId,
                  dropdownColor: AppColors.backgroundPrimary,
                  style: const TextStyle(color: AppColors.textPrimary),
                  underline: Container(height: 1, color: AppColors.glassBorder),
                  items: registry.active.availableModels
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(m, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (m) {
                    if (m != null) {
                      context.read<ProviderRegistry>().setModel(registry.active, m);
                    }
                  },
                ),
                const Divider(color: AppColors.glassBorder),
                ListTile(
                  title: const Text('Manage API Keys', style: TextStyle(color: AppColors.textPrimary)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderSetupScreen()));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Shake Sensitivity', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Slider(
                  value: shakeService.sensitivity.index / 2.0,
                  onChanged: (val) {
                    int idx = (val * 2).round();
                    context.read<ShakeDetectorService>().updateSensitivity(ShakeSensitivity.values[idx]);
                  },
                  divisions: 2,
                  activeColor: AppColors.accentViolet,
                  inactiveColor: AppColors.glassBorder,
                ),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Low', style: TextStyle(color: AppColors.textMuted)),
                    Text('Medium', style: TextStyle(color: AppColors.textMuted)),
                    Text('High', style: TextStyle(color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Startup', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: system.launchAtStartup,
                  onChanged: (v) => context.read<SystemService>().setLaunchAtStartup(v),
                  activeColor: AppColors.accentViolet,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Launch Magisor at Windows startup', style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: const Text('Starts silently in the system tray when you sign in', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}