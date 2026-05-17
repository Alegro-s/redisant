import 'package:flutter/material.dart';

int flutterColorToEngineArgb(Color c) {
  final r = (c.r * 255.0).round() & 0xff;
  final g = (c.g * 255.0).round() & 0xff;
  final b = (c.b * 255.0).round() & 0xff;
  final a = (c.a * 255.0).round() & 0xff;
  return (r << 24) | (g << 16) | (b << 8) | a;
}

Color engineArgbToFlutterColor(int hex) {
  final r = (hex >> 24) & 0xff;
  final g = (hex >> 16) & 0xff;
  final b = (hex >> 8) & 0xff;
  final a = hex & 0xff;
  return Color.fromARGB(a, r, g, b);
}
