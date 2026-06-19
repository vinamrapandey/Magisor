import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'ai_provider.dart';
import 'gemini_provider.dart';
import 'claude_provider.dart';
import 'groq_provider.dart';

/// Holds the available AI providers and tracks which one is active.
///
/// The active choice is persisted so it survives restarts. The home screen
/// resolves [active] at request time, so swapping providers takes effect
/// immediately without rebuilding the capture pipeline.
class ProviderRegistry extends ChangeNotifier {
  static const _activeKey = 'magisor_active_provider';
  final _storage = const FlutterSecureStorage();

  final List<AIProvider> providers = [
    GeminiProvider(),
    ClaudeProvider(),
    GroqProvider(),
  ];

  late AIProvider _active = providers.first;
  AIProvider get active => _active;

  /// Resolve a provider by its display name, falling back to the active one.
  AIProvider byName(String name) => providers.firstWhere(
        (p) => p.providerName == name,
        orElse: () => _active,
      );

  /// Load the persisted active-provider choice. Call once at startup.
  Future<void> load() async {
    try {
      final name = await _storage.read(key: _activeKey);
      if (name != null) {
        final match = providers.where((p) => p.providerName == name);
        if (match.isNotEmpty) _active = match.first;
      }
    } catch (_) {
      // Secure storage unavailable — keep the default provider.
    }
    notifyListeners();
  }

  Future<void> setActive(String name) async {
    _active = byName(name);
    try {
      await _storage.write(key: _activeKey, value: _active.providerName);
    } catch (_) {
      // Persistence is best-effort; the in-memory choice still applies.
    }
    notifyListeners();
  }
}
