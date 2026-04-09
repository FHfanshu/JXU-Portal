import 'package:flutter/material.dart';

/// Ship-Card: The signature component of the Academic Voyager design system.
///
/// - Top-left/right radius: 16dp
/// - Bottom-left/right radius: 8dp
/// - No border, uses surface tonal differences
/// - Background: surface-container-lowest
class ShipCard extends StatelessWidget {
  const ShipCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.color,
    this.gradient,
    this.elevation = 0,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final Gradient? gradient;
  final double elevation;
  final Clip clipBehavior;

  static const BorderRadius _borderRadius = BorderRadius.only(
    topLeft: Radius.circular(16),
    topRight: Radius.circular(16),
    bottomLeft: Radius.circular(8),
    bottomRight: Radius.circular(8),
  );

  @override
  Widget build(BuildContext context) {
    final surfaceColor =
        color ?? Theme.of(context).colorScheme.surfaceContainerLowest;

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? surfaceColor : null,
        gradient: gradient,
        borderRadius: _borderRadius,
        boxShadow: elevation > 0
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: elevation * 4,
                  offset: Offset(0, elevation),
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: _borderRadius,
        child: ClipRRect(
          borderRadius: _borderRadius,
          clipBehavior: clipBehavior,
          child: InkWell(
            onTap: onTap,
            borderRadius: _borderRadius,
            child: content,
          ),
        ),
      );
    }

    return Padding(padding: margin, child: content);
  }
}
