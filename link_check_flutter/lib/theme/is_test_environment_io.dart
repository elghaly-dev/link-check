import 'dart:io';

bool get isTestEnvironment => Platform.environment.containsKey('FLUTTER_TEST');
