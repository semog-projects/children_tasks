import 'package:flutter/material.dart';

import 'avatar_colors.dart';

/// Avatar circular de uma criança: a inicial do nome sobre a cor do perfil,
/// com texto de contraste garantido. Um único lugar para esse padrão.
class ChildAvatar extends StatelessWidget {
  const ChildAvatar({
    super.key,
    required this.name,
    this.colorHex,
    this.radius,
  });

  final String name;
  final String? colorHex;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final background = colorFromHex(colorHex);
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      child: Text(
        initial,
        style: TextStyle(
          color: onAvatarColor(background),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
