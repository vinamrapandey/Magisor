import 'package:flutter/material.dart';
import 'ui/theme/glass_theme.dart';
import 'ui/screens/home_screen.dart';

class MagisorApp extends StatelessWidget {
  const MagisorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Magisor',
      theme: GlassTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}