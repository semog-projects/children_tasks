import 'package:flutter/material.dart';

import '../data/models/task.dart';

/// Ícone + cor de acento de cada [TaskCategory], num único lugar.
/// A cor é um tom fixo usado como acento (ex.: `leading` de lista, chip);
/// para texto por cima, componha com o `colorScheme` da tela.
extension TaskCategoryStyle on TaskCategory {
  IconData get icon => switch (this) {
        TaskCategory.routine => Icons.event_repeat_rounded,
        TaskCategory.study => Icons.menu_book_rounded,
        TaskCategory.chores => Icons.cleaning_services_rounded,
        TaskCategory.hygiene => Icons.soap_rounded,
        TaskCategory.other => Icons.star_rounded,
      };

  Color get accent => switch (this) {
        TaskCategory.routine => const Color(0xFF5C6BC0), // índigo
        TaskCategory.study => const Color(0xFF26A69A), // verde-água
        TaskCategory.chores => const Color(0xFFFFA726), // laranja
        TaskCategory.hygiene => const Color(0xFF42A5F5), // azul
        TaskCategory.other => const Color(0xFFAB47BC), // roxo
      };
}
