# V25 New brand artwork

- Replaced GO button logo, app launcher icons, and splash stills with the new M / GO Test Speed neon artwork.
- Black canvas converted to transparent so it matches the previous dark UI background style.
- Gauge shows a subtle brand watermark behind the arc while testing.
- Adaptive launcher: pure dark background (#06080F) + transparent foreground logo in the safe zone.
- Legacy mipmap icons and density splash logos regenerated (mdpi → xxxhdpi).

## Analyze fix (CI)
- Removed unused `_ecgDecor`, `_EcgLinePainter`, and `_MotionStreakPainter` left over after replacing the text gauge brand with the logo image.
- Clears `unused_element` warnings that failed `flutter analyze --no-fatal-infos`.
