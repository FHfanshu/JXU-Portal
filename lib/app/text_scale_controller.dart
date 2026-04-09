import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TextScaleController {
  TextScaleController._();

  static final TextScaleController instance = TextScaleController._();

  static const _prefKey = 'text_scale_factor';
  static const double minScaleFactor = 0.7;
  static const double maxScaleFactor = 1.2;
  static const double scaleStep = 0.05;
  static const double defaultScaleFactor = 1.0;

  static int get sliderDivisions =>
      ((maxScaleFactor - minScaleFactor) / scaleStep).round();

  final ValueNotifier<double> textScaleFactor = ValueNotifier(
    defaultScaleFactor,
  );

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getDouble(_prefKey);
    textScaleFactor.value = normalizeScaleFactor(stored);
  }

  Future<void> setTextScaleFactor(double value) async {
    final normalized = normalizeScaleFactor(value);
    if (textScaleFactor.value == normalized) return;
    textScaleFactor.value = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefKey, normalized);
  }

  static double normalizeScaleFactor(double? value) {
    if (value == null) return defaultScaleFactor;
    final clamped = value.clamp(minScaleFactor, maxScaleFactor);
    final steps = ((clamped - minScaleFactor) / scaleStep).round();
    final normalized = minScaleFactor + (steps * scaleStep);
    return double.parse(normalized.toStringAsFixed(2));
  }

  @visibleForTesting
  void debugReset({double scaleFactor = defaultScaleFactor}) {
    textScaleFactor.value = normalizeScaleFactor(scaleFactor);
  }
}

class AppTextScaleScope extends StatelessWidget {
  const AppTextScaleScope({
    super.key,
    required this.scaleFactor,
    required this.child,
  });

  final double scaleFactor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final normalizedScaleFactor = TextScaleController.normalizeScaleFactor(
      scaleFactor,
    );
    final textScaler =
        normalizedScaleFactor == TextScaleController.defaultScaleFactor
        ? mediaQuery.textScaler
        : _RelativeTextScaler(
            base: mediaQuery.textScaler,
            factor: normalizedScaleFactor,
          );

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: textScaler),
      child: child,
    );
  }
}

class _RelativeTextScaler extends TextScaler {
  const _RelativeTextScaler({required this.base, required this.factor});

  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  double get textScaleFactor => scale(14) / 14;

  @override
  bool operator ==(Object other) {
    return other is _RelativeTextScaler &&
        other.base == base &&
        other.factor == factor;
  }

  @override
  int get hashCode => Object.hash(base, factor);
}
