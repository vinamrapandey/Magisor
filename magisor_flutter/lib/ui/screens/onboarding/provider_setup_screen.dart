import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/provider_registry.dart';
import '../../theme/app_colors.dart';
import '../../widgets/editorial.dart';
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
    _loadExistingKeys();
  }

  Future<void> _loadExistingKeys() async {
    final registry = context.read<ProviderRegistry>();
    for (final p in registry.providers) {
      final key = await p.loadKey();
      if (key != null && key.isNotEmpty && mounted) {
        _controllers[p.providerName]?.text = key;
        setState(() {
          _status[p.providerName] = _KeyStatus.valid;
        });
      }
    }
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
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
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
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: const Text('API keys'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: CenteredPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageHeader(eyebrow: 'Providers', title: 'Bring your own keys.'),
            const SizedBox(height: 8),
            const Text(
              'Paste an API key for any provider you want to use. Keys stay on this device, encrypted in the OS secure store.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            for (final entry in _controllers.entries) ...[
              _providerKeyCard(entry.key),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }

  Widget _providerKeyCard(String provider) {
    final verifying = _status[provider] == _KeyStatus.verifying;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                provider,
                style: const TextStyle(
                  fontSize: 18,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              _statusBadge(provider),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controllers[provider],
            obscureText: true,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Paste API key…',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surfaceAlt,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.ink, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: InkButton(
              label: verifying ? 'Verifying…' : 'Save & verify',
              icon: verifying ? null : Icons.arrow_forward,
              onPressed: verifying
                  ? () {}
                  : () => _saveAndVerify(provider, _controllers[provider]!.text),
            ),
          ),
        ],
      ),
    );
  }
}
