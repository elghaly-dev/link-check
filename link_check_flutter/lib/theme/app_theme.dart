import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'is_test_environment.dart';

ThemeData buildAppTheme(Brightness brightness) {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2563EB),
      brightness: brightness,
    ),
    useMaterial3: true,
  );
  if (isTestEnvironment) {
    return base;
  }
  return base.copyWith(textTheme: GoogleFonts.interTextTheme(base.textTheme));
}
