import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/provider_registry.dart';
import '../../theme/app_colors.dart';
import '../../widgets/glass_card.dart';

class ProviderSetupScreen extends StatefulWidget {
  const ProviderSetupScreen({super.key});

  @override
  State<ProviderSetupScreen> createState() => _ProviderSetupScreenState();
}

enum _KeyStatus { idle, verifying, valid, invalid }

class _ProviderSetupScreenState extends State<ProviderSetupScreen> {
  final _storage = const FlutterSecureStorage();
  late final Map<String, TextEditingController> _controllers;
  final Map<String, _KeyStatus> _status = {};

  @override
  void initState() {
    super.initState();
    // Drive the cards from the real provider list so keys map to providers
    // that actually exist.
    final names = context.read<ProviderRegistry>().providers.map((p) => p.providerName);
    _controllers = {for (final name in names) name: TextEditingController()};
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveAndVerify(String provider, String key) async {
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an API key first.')),
      );
      return;
    }

    setState(() => _status[provider] = _KeyStatus.verifying);

    final aiProvider = context.read<ProviderRegistry>().byName(provider);
    final isValid = await aiProvider.verifyKey(key);

    // Save regardless so a transient network failure during verify doesn't
    // discard the user's key; the status tells them whether it checked out.
    await _storage.write(key: 'magisor_${provider.toLowerCase()}_key', value: key);

    if (!mounted) return;
    setState(() => _status[provider] = isValid ? _KeyStatus.valid : _KeyStatus.invalid);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isValid
            ? '$provider key saved and verified!'
            : '$provider key saved, but verification failed (check the key).'),
      ),
    );
  }

  Widget _statusBadge(String provider) {
    switch (_status[provider] ?? _KeyStatus.idle) {
      case _KeyStatus.verifying:
        return const SizedBox(
          height: 16, width: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentViolet),
        );
      case _KeyStatus.valid:
        return const Icon(Icons.check_circle, color: AppColors.successGreen, size: 18);
      case _KeyStatus.invalid:
        return const Icon(Icons.error, color: AppColors.errorRed, size: 18);
      case _KeyStatus.idle:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your AI'), backgroundColor: Colors.transparent),
      body: Center(
        child: SizedBox(
          height: 340,
          child: ListView(
            padding: const EdgeInsets.all(16),
            scrollDirection: Axis.horizontal,
            children: _controllers.keys.map((provider) {
              final verifying = _status[provider] == _KeyStatus.verifying;
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GlassCard(
                  width: 300,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(provider, style: const TextStyle(fontSize: 24, color: AppColors.textPrimary)),
                          const SizedBox(width: 8),
                          _statusBadge(provider),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _controllers[provider],
                        obscureText: true,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'API Key',
                          hintText: 'Paste key here...',
                          labelStyle: const TextStyle(color: AppColors.textMuted),
                          hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: verifying
                            ? null
                            : () => _saveAndVerify(provider, _controllers[provider]!.text),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentViolet),
                        child: const Text('Save Key & Verify'),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
