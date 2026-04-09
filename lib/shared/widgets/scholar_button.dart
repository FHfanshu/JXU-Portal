import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// ScholarButton: Primary action button with Wine Red gradient + StadiumBorder.
class ScholarButton extends StatelessWidget {
  const ScholarButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.expanded = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  final bool expanded;

  factory ScholarButton.text({
    Key? key,
    required VoidCallback? onPressed,
    required String text,
    IconData? icon,
    bool expanded,
  }) = _ScholarButtonText;

  @override
  Widget build(BuildContext context) {
    final button = Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(100),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: icon != null
                ? Row(
                    mainAxisSize: expanded
                        ? MainAxisSize.max
                        : MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      child,
                    ],
                  )
                : child,
          ),
        ),
      ),
    );

    if (expanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

class _ScholarButtonText extends ScholarButton {
  _ScholarButtonText({
    super.key,
    required super.onPressed,
    required String text,
    super.icon,
    super.expanded,
  }) : super(
         child: Text(
           text,
           style: const TextStyle(
             color: Colors.white,
             fontWeight: FontWeight.w600,
           ),
         ),
       );
}

/// Secondary button: surface-container-high bg, primary text.
class ScholarSecondaryButton extends StatelessWidget {
  const ScholarSecondaryButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.expanded = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  final bool expanded;

  factory ScholarSecondaryButton.text({
    Key? key,
    required VoidCallback? onPressed,
    required String text,
    IconData? icon,
    bool expanded,
  }) = _ScholarSecondaryButtonText;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final button = Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(100),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: icon != null
                ? Row(
                    mainAxisSize: expanded
                        ? MainAxisSize.max
                        : MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: cs.primary, size: 18),
                      const SizedBox(width: 8),
                      child,
                    ],
                  )
                : child,
          ),
        ),
      ),
    );

    if (expanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

class _ScholarSecondaryButtonText extends ScholarSecondaryButton {
  _ScholarSecondaryButtonText({
    super.key,
    required super.onPressed,
    required String text,
    super.icon,
    super.expanded,
  }) : super(
         child: Builder(
           builder: (context) => Text(
             text,
             style: TextStyle(
               color: Theme.of(context).colorScheme.primary,
               fontWeight: FontWeight.w600,
             ),
           ),
         ),
       );
}
