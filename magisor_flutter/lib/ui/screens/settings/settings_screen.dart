import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../../core/providers/ai_provider.dart';
import '../../../core/providers/provider_registry.dart';
import '../../../core/services/shake_detector_service.dart';
import '../../../core/services/system_service.dart';
import '../onboarding/provider_setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _activeCategoryIndex = 0;

  static const List<String> _categories = [
    'AI & Providers',
    'Gesture & Shake',
    'System & Startup',
  ];

  static const Map<String, Color> _providerAccents = {
    'Gemini': AppColors.accentViolet,
    'Claude': AppColors.accentCoral,
    'Groq': AppColors.accentCyan,
  };

  @override
  Widget build(BuildContext context) {
    final shakeService = context.watch<ShakeDetectorService>();
    final registry = context.watch<ProviderRegistry>();
    final system = context.watch<SystemService>();

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            const Text(
              'Settings',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Configure AI providers, sensitivity, and desktop startup behavior.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // Category Sub-tabs Bar (Inspired by Reference Design)
            Row(
              children: List.generate(_categories.length, (index) {
                final isSelected = _activeCategoryIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _activeCategoryIndex = index),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.ink : AppColors.sidebarBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.ink : AppColors.glassBorder,
                        ),
                      ),
                      child: Text(
                        _categories[index],
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // Content Panel Based on Category
            if (_activeCategoryIndex == 0) ...[
              _buildProvidersCard(context, registry),
            ] else if (_activeCategoryIndex == 1) ...[
              _buildShakeCard(context, shakeService),
            ] else ...[
              _buildStartupCard(context, system),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.glassSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildProvidersCard(BuildContext context, ProviderRegistry registry) {
    return _buildCard(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'AI Provider & Model',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Select which model powers your overlay searches and translations.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProviderSetupScreen()),
              ),
              icon: const Icon(Icons.key, size: 16, color: Colors.white),
              label: const Text('Manage API Keys'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Divider(color: AppColors.glassBorder),
        const SizedBox(height: 16),

        // Provider Options
        ...registry.providers.map((p) => _providerRow(context, p, registry)),

        const SizedBox(height: 20),
        Text(
          'Model for ${registry.active.providerName}',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _modelDropdown(context, registry),
      ],
    );
  }

  Widget _providerRow(BuildContext context, AIProvider p, ProviderRegistry registry) {
    final accent = _providerAccents[p.providerName] ?? AppColors.ink;
    final isActive = registry.active.providerName == p.providerName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => registry.setActive(p.providerName),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? AppColors.surfaceAlt : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? AppColors.ink.withValues(alpha: 0.2) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.providerName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      p.modelId,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive ? AppColors.ink : const Color(0xFFCBD5E1),
                    width: isActive ? 6 : 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modelDropdown(BuildContext context, ProviderRegistry registry) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.sidebarBackground,
        border: Border.all(color: AppColors.glassBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: registry.active.modelId,
          dropdownColor: Colors.white,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
          icon: const Icon(Icons.expand_more, color: AppColors.textMuted, size: 20),
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

  Widget _buildShakeCard(BuildContext context, ShakeDetectorService s) {
    return _buildCard(
      children: [
        const Text(
          'Mouse Shake Sensitivity',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Adjust how vigorously you need to shake the mouse to summon the overlay menu.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 24),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppColors.ink,
            inactiveTrackColor: const Color(0xFFE2E8F0),
            thumbColor: AppColors.ink,
            overlayColor: AppColors.ink.withValues(alpha: 0.1),
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(
            value: s.sensitivity.index / 2.0,
            onChanged: (v) => context
                .read<ShakeDetectorService>()
                .updateSensitivity(ShakeSensitivity.values[(v * 2).round()]),
            divisions: 2,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final l in const ['Low (Gentle)', 'Medium (Balanced)', 'High (Strict)'])
              Text(
                l,
                style: TextStyle(
                  color: s.sensitivity.name.toLowerCase() == l.split(' ')[0].toLowerCase()
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: s.sensitivity.name.toLowerCase() == l.split(' ')[0].toLowerCase()
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStartupCard(BuildContext context, SystemService system) {
    return _buildCard(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Launch at Windows Startup',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Magisor will start silently in the system tray when you log in.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            Switch(
              value: system.launchAtStartup,
              onChanged: (v) => context.read<SystemService>().setLaunchAtStartup(v),
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.ink,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFCBD5E1),
            ),
          ],
        ),
      ],
    );
  }
}
