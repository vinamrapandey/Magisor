import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';

class ProviderSetupScreen extends StatefulWidget {
  const ProviderSetupScreen({super.key});

  @override
  State<ProviderSetupScreen> createState() => _ProviderSetupScreenState();
}

class _ProviderSetupScreenState extends State<ProviderSetupScreen> {
  final _storage = const FlutterSecureStorage();
  final Map<String, TextEditingController> _controllers = {
    'Gemini': TextEditingController(),
    'Claude': TextEditingController(),
    'OpenAI': TextEditingController(),
    'Groq': TextEditingController(),
  };

  Future<void> _saveKey(String provider, String key) async {
    await _storage.write(key: 'magisor_${provider.toLowerCase()}_key', value: key);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$provider key saved locally!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your AI'), backgroundColor: Colors.transparent),
      body: Center(
        child: SizedBox(
          height: 300,
          child: ListView(
            padding: const EdgeInsets.all(16),
            scrollDirection: Axis.horizontal,
            children: _controllers.keys.map((provider) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GlassCard(
                  width: 300,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(provider, style: const TextStyle(fontSize: 24, color: AppColors.textPrimary)),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _controllers[provider],
                        obscureText: true,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'API Key',
                          hintText: 'Paste key here...',
                          labelStyle: const TextStyle(color: AppColors.textMuted),
                          hintStyle: TextStyle(color: AppColors.textMuted.withOpacity(0.5)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _saveKey(provider, _controllers[provider]!.text),
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