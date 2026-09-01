import 'package:childrentasks/src/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppTheme usa a fonte Nunito e uma escala tipográfica própria', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Nunito');
      expect(theme.textTheme.bodyMedium?.fontSize, 15);
      expect(theme.textTheme.headlineSmall?.fontWeight, FontWeight.w800);
      expect(theme.appBarTheme.titleTextStyle?.fontFamily, 'Nunito');
    }
  });

  test('claro e escuro compartilham a mesma semente', () {
    expect(AppTheme.light().colorScheme.brightness, Brightness.light);
    expect(AppTheme.dark().colorScheme.brightness, Brightness.dark);
  });
}
