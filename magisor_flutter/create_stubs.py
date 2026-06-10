import os

stubs = {
    "lib/app.dart": "import 'package:flutter/material.dart';\n\n/// Main application widget with theming and routing.\nclass MagisorApp extends StatelessWidget {\n  const MagisorApp({super.key});\n\n  @override\n  Widget build(BuildContext context) {\n    return MaterialApp(\n      title: 'Magisor',\n      home: const Scaffold(),\n    );\n  }\n}",
    "lib/core/providers/ai_provider.dart": "/// Abstract base class for all AI providers.\nabstract class AIProvider {\n  String get providerName;\n}",
    "lib/core/providers/gemini_provider.dart": "import 'ai_provider.dart';\n\n/// Gemini AI implementation.\nclass GeminiProvider extends AIProvider {\n  @override\n  String get providerName => 'Gemini';\n}",
    "lib/core/providers/claude_provider.dart": "import 'ai_provider.dart';\n\n/// Claude AI implementation.\nclass ClaudeProvider extends AIProvider {\n  @override\n  String get providerName => 'Claude';\n}",
    "lib/core/providers/openai_provider.dart": "import 'ai_provider.dart';\n\n/// OpenAI implementation.\nclass OpenAIProvider extends AIProvider {\n  @override\n  String get providerName => 'OpenAI';\n}",
    "lib/core/providers/groq_provider.dart": "import 'ai_provider.dart';\n\n/// Groq AI implementation.\nclass GroqProvider extends AIProvider {\n  @override\n  String get providerName => 'Groq';\n}",
    "lib/core/services/auth_service.dart": "/// Wraps Firebase Authentication.\nclass AuthService {\n}",
    "lib/core/services/capture_service.dart": "/// Handles native screen capture.\nclass CaptureService {\n}",
    "lib/core/services/ocr_service.dart": "/// Handles ML Kit and native OCR.\nclass OcrService {\n}",
    "lib/core/services/shake_detector_service.dart": "/// Listens to global mouse events to detect shake gestures.\nclass ShakeDetectorService {\n}",
    "lib/core/services/storage_service.dart": "/// Wraps Firestore and SQLite for saving items.\nclass StorageService {\n}",
    "lib/core/services/env_service.dart": "/// Wraps flutter_dotenv for configuration variables.\nclass EnvService {\n}",
    "lib/core/models/magisor_response.dart": "/// Represents a structured AI response.\nclass MagisorResponse {\n}",
    "lib/core/models/saved_item.dart": "/// Represents a user saved item (screenshot + context).\nclass SavedItem {\n}",
    "lib/core/models/user_settings.dart": "/// Represents local user preferences.\nclass UserSettings {\n}",
    "lib/ui/theme/glass_theme.dart": "/// Provides glassmorphic theme data.\nclass GlassTheme {\n}",
    "lib/ui/theme/app_colors.dart": "import 'package:flutter/material.dart';\n\n/// Defines standard colors used in the glassmorphic design.\nclass AppColors {\n  static const backgroundPrimary = Color(0xFF0A0A0F);\n}",
    "lib/ui/widgets/radial_menu.dart": "import 'package:flutter/material.dart';\n\n/// A glassmorphic radial pie menu.\nclass RadialMenu extends StatelessWidget {\n  const RadialMenu({super.key});\n  @override\n  Widget build(BuildContext context) => const SizedBox();\n}",
    "lib/ui/widgets/action_bubble.dart": "import 'package:flutter/material.dart';\n\n/// A single bubble in the radial menu.\nclass ActionBubble extends StatelessWidget {\n  const ActionBubble({super.key});\n  @override\n  Widget build(BuildContext context) => const SizedBox();\n}",
    "lib/ui/widgets/glass_card.dart": "import 'package:flutter/material.dart';\n\n/// A reusable frosted glass card.\nclass GlassCard extends StatelessWidget {\n  const GlassCard({super.key});\n  @override\n  Widget build(BuildContext context) => const SizedBox();\n}",
    "lib/ui/widgets/ai_result_overlay.dart": "import 'package:flutter/material.dart';\n\n/// Overlay displaying AI processing state and results.\nclass AIResultOverlay extends StatelessWidget {\n  const AIResultOverlay({super.key});\n  @override\n  Widget build(BuildContext context) => const SizedBox();\n}",
    "lib/ui/screens/onboarding/welcome_screen.dart": "import 'package:flutter/material.dart';\n\n/// Initial welcome screen.\nclass WelcomeScreen extends StatelessWidget {\n  const WelcomeScreen({super.key});\n  @override\n  Widget build(BuildContext context) => const Scaffold();\n}",
    "lib/ui/screens/onboarding/auth_screen.dart": "import 'package:flutter/material.dart';\n\n/// Login and Signup screen.\nclass AuthScreen extends StatelessWidget {\n  const AuthScreen({super.key});\n  @override\n  Widget build(BuildContext context) => const Scaffold();\n}",
    "lib/ui/screens/onboarding/provider_setup_screen.dart": "import 'package:flutter/material.dart';\n\n/// Setup screen for AI provider API keys.\nclass ProviderSetupScreen extends StatelessWidget {\n  const ProviderSetupScreen({super.key});\n  @override\n  Widget build(BuildContext context) => const Scaffold();\n}",
    "lib/ui/screens/home_screen.dart": "import 'package:flutter/material.dart';\n\n/// Main desktop and mobile hidden overlay screen.\nclass HomeScreen extends StatelessWidget {\n  const HomeScreen({super.key});\n  @override\n  Widget build(BuildContext context) => const Scaffold();\n}",
    "lib/ui/screens/saved_screen.dart": "import 'package:flutter/material.dart';\n\n/// Displays user's saved items.\nclass SavedScreen extends StatelessWidget {\n  const SavedScreen({super.key});\n  @override\n  Widget build(BuildContext context) => const Scaffold();\n}",
    "lib/ui/screens/history_screen.dart": "import 'package:flutter/material.dart';\n\n/// Displays historical AI session logs.\nclass HistoryScreen extends StatelessWidget {\n  const HistoryScreen({super.key});\n  @override\n  Widget build(BuildContext context) => const Scaffold();\n}",
    "lib/ui/screens/settings/settings_screen.dart": "import 'package:flutter/material.dart';\n\n/// App settings.\nclass SettingsScreen extends StatelessWidget {\n  const SettingsScreen({super.key});\n  @override\n  Widget build(BuildContext context) => const Scaffold();\n}",
    "lib/ui/screens/settings/provider_settings_screen.dart": "import 'package:flutter/material.dart';\n\n/// AI Provider specific settings.\nclass ProviderSettingsScreen extends StatelessWidget {\n  const ProviderSettingsScreen({super.key});\n  @override\n  Widget build(BuildContext context) => const Scaffold();\n}",
}

for path, content in stubs.items():
    with open(path, 'w') as f:
        f.write(content)

print("All stubs generated successfully.")
