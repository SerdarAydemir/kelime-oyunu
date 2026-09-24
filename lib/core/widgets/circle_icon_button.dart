// lib/core/widgets/circle_icon_button.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';

/// The design's round icon button: a 40 dp `surface` circle (README "Global
/// rules": the ← back icon on every screen, the ⋯ on the game header).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.size = AppDimensions.iconButton,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: tokens.surface,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: 22, color: tokens.text),
          ),
        ),
      ),
    );
  }
}
