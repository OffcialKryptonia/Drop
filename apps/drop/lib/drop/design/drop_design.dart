import 'package:flutter/material.dart';

import '../../utils/Colors.dart';

/// DROP design system: colours, spacing and the shared widgets used by the
/// onboarding, login and sign-up screens. Keep new passenger-facing UI on these
/// tokens so every screen looks like one product.

bool dropIsDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

class DropColors {
  DropColors._();

  /// The brand orange used for buttons and highlights (shared with the rest of the app).
  static Color get primary => primaryColor;

  /// The two ends of the logo gradient. Use only for hero moments, never for buttons.
  static const Color amber = Color(0xFFFF9A00);
  static const Color ember = Color(0xFFFF3B00);

  static const Color ink = Color(0xFF14110F);
  static const Color paper = Color(0xFFFFFFFF);
  static const Color warmWhite = Color(0xFFFFF8F4);
  static const Color night = Color(0xFF000000);
  static const Color nightSurface = Color(0xFF1A1715);
  static const Color success = Color(0xFF1FA463);

  static Color background(BuildContext c) => dropIsDark(c) ? night : paper;
  static Color surface(BuildContext c) => dropIsDark(c) ? nightSurface : warmWhite;
  static Color text(BuildContext c) => dropIsDark(c) ? paper : ink;
  static Color mutedText(BuildContext c) => dropIsDark(c) ? const Color(0xFFB9B2AC) : const Color(0xFF6B6560);
  static Color hairline(BuildContext c) => dropIsDark(c) ? const Color(0x1FFFFFFF) : const Color(0x14000000);
}

class DropSpacing {
  DropSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class DropRadius {
  DropRadius._();

  static const double field = 14;
  static const double button = 14;
  static const double card = 24;
}

/// The official DROP logo. Picks the dark-text or white-text version from the
/// current theme. Pass [markOnly] for the "D" symbol on its own.
class DropLogo extends StatelessWidget {
  const DropLogo({super.key, this.width, this.height, this.markOnly = false});

  final double? width;
  final double? height;
  final bool markOnly;

  @override
  Widget build(BuildContext context) {
    final String asset = markOnly
        ? 'images/brand/drop_mark.png'
        : (dropIsDark(context) ? 'images/brand/drop_logo_on_dark.png' : 'images/brand/drop_logo_on_light.png');
    return Image.asset(
      asset,
      width: width,
      height: height,
      fit: BoxFit.contain,
      semanticLabel: 'DROP',
    );
  }
}

class DropPrimaryButton extends StatelessWidget {
  const DropPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: DropColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: DropColors.primary.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DropRadius.button)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label),
                  if (icon != null) ...[
                    const SizedBox(width: 8),
                    Icon(icon, size: 20),
                  ],
                ],
              ),
      ),
    );
  }
}

class DropSecondaryButton extends StatelessWidget {
  const DropSecondaryButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: DropColors.text(context),
          side: BorderSide(color: DropColors.hairline(context).withValues(alpha: 0.25), width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DropRadius.button)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
