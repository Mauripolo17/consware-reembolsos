import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LiquidGlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool useBackdropBlur;
  final Color? backgroundColor;
  final Color? borderColor;

  const LiquidGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = 20,
    this.useBackdropBlur = false,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: backgroundColor ?? AppTheme.glassStrongFill,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? AppTheme.glassBorder,
        width: 1.2,
      ),
      boxShadow: const <BoxShadow>[
        BoxShadow(
          color: Color(0x142563EB),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
        BoxShadow(
          color: Color(0x0A0F172A),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ],
    );

    final content = Container(
      padding: padding,
      decoration: decoration,
      child: child,
    );

    if (!useBackdropBlur) {
      return content;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: content,
      ),
    );
  }
}
