import 'package:flutter/material.dart';

/// Shared footer matching MPorT branding (centered).
///
/// MPorT Go
/// © 2026 MPorT. All rights reserved.
/// Made with ❤️ in Kincir Tengah
class AppFooter extends StatelessWidget {
  const AppFooter({
    super.key,
    this.compact = false,
    this.padding,
  });

  /// When true, uses tighter spacing (e.g. drawer / short lists).
  final bool compact;

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
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
              color: Colors.white.withValues(alpha: 0.08),
            ),
            SizedBox(height: compact ? 12 : 16),
            const Text(
              'MPorT Go',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '© 2026 MPorT. All rights reserved.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF9A9AA6),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 5),
            const Text.rich(
              TextSpan(
                style: TextStyle(
                  color: Color(0xFF777783),
                  fontSize: 11,
                ),
                children: [
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
