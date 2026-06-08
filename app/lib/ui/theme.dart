import 'package:flutter/material.dart';

ThemeData buildAppTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFFFF7A1A),
    brightness: Brightness.dark,
  ),
  scaffoldBackgroundColor: const Color(0xFF0A0A0B),
);
