import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin,
    this.color = AppColors.surface,
    this.borderRadius = AppRadii.panel,
    this.borderColor = AppColors.border,
    this.boxShadow,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color color;
  final double borderRadius;
  final Color borderColor;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final effectiveShadow = boxShadow ?? [
      BoxShadow(
        color: Colors.black.withAlpha((255 * 0.18).round()),
        blurRadius: 22,
        offset: const Offset(0, 10),
      ),
    ];

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withAlpha((255 * 0.96).round()),
            color.withAlpha((255 * 0.88).round()),
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor.withAlpha((255 * 0.8).round())),
        boxShadow: effectiveShadow,
      ),
      child: child,
    );
  }
}

class AppMetricCard extends StatelessWidget {
  const AppMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    super.key,
    this.accent = AppColors.primary,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: AppRadii.control,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withAlpha((255 * 0.15).round()),
              borderRadius: BorderRadius.circular(AppRadii.compact),
            ),
            child: Icon(icon, color: accent, size: 21),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
