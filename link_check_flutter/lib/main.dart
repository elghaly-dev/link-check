import 'package:flutter/material.dart';

import 'client.dart';
import 'screens/link_check_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/public_footer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeClient();
  runApp(const LinkCheckApp());
}

class LinkCheckApp extends StatelessWidget {
  const LinkCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Link Check',
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
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
      appBar: AppBar(title: const Text('Link Check'), centerTitle: false),
      body: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: LinkCheckScreen()),
          PublicFooter(),
        ],
      ),
    );
  }
}
