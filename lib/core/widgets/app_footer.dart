import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shared footer matching MPorT branding (centered).
class AppFooter extends StatelessWidget {
  const AppFooter({
    super.key,
    this.compact = false,
    this.padding,
  });

  final bool compact;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final vertical = compact ? 12.0 : 18.0;
    return Padding(
      padding: padding ?? EdgeInsets.fromLTRB(16, vertical, 16, vertical),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 1,
              color: p.divider,
            ),
            SizedBox(height: compact ? 12 : 16),
            Text(
              'MPorT Go',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: p.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '© 2026 MPorT. All rights reserved.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: p.textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 5),
            Text.rich(
              TextSpan(
                style: TextStyle(
                  color: p.textMuted,
                  fontSize: 11,
                ),
                children: const [
                  TextSpan(text: 'Made with '),
                  TextSpan(
                    text: '❤️',
                    style: TextStyle(color: Color(0xFFE53935)),
                  ),
                  TextSpan(text: ' in Kincir Tengah'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
