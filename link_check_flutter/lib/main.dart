import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'client.dart';
import 'screens/link_check_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeClient();
  runApp(const LinkCheckApp());
}

ThemeData _buildTheme(Brightness brightness) {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2563EB),
      brightness: brightness,
    ),
    useMaterial3: true,
  );
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme),
  );
}

class LinkCheckApp extends StatelessWidget {
  const LinkCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Link Check',
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const LinkCheckHomePage(),
    );
  }
}

class LinkCheckHomePage extends StatelessWidget {
  const LinkCheckHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Link Check'),
        centerTitle: false,
      ),
      body: const LinkCheckScreen(),
    );
  }
}
