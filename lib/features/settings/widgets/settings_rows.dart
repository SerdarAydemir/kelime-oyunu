// lib/features/settings/widgets/settings_rows.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';

/// Section label ("OYUN", "HESAP"): 600 11, letter-spacing 3, 55 %.
class SettingsSectionLabel extends StatelessWidget {
  const SettingsSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.space4,
        AppDimensions.space20,
        AppDimensions.space4,
        AppDimensions.space8,
      ),
      child: Text(
        text,
        style: AppTypography.overline.copyWith(color: context.tokens.text.withValues(alpha: 0.66)),
      ),
    );
  }
}

/// A group of rows: `surface` background, r18, 1 px `border`, dividers.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusListCard),
        border: Border.all(color: tokens.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: tokens.border),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One row: label 700 15 (+ sub 500 12 at 60 %) and a trailing control or
/// chevron. Tappable when [onTap] is set.
class SettingsRow extends StatelessWidget {
  const SettingsRow({required this.label, this.sub, this.trailing, this.onTap, super.key});

  final String label;
  final String? sub;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space18, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTypography.buttonSecondary.copyWith(color: tokens.text)),
                  if (sub != null)
                    Text(
                      sub!,
                      style: AppTypography.bodySmall.copyWith(
                        color: tokens.text.withValues(alpha: 0.66),
                      ),
                    ),
                ],
              ),
            ),
            // A wide control (the appearance pill) scales down at large
            // system fonts rather than pushing past the row.
            if (trailing != null)
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: trailing,
                ),
              ),
            if (trailing == null && onTap != null)
              Icon(Icons.chevron_right, color: tokens.text.withValues(alpha: 0.66)),
          ],
        ),
      ),
    );
  }
}

/// 48 × 28 toggle: on = amber track, `accentInk` knob right; off = `toggleOff`
/// track, `knob` left.
class SettingsToggle extends StatelessWidget {
  const SettingsToggle({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 48,
          height: 28,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? tokens.accent : tokens.toggleOff,
            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
          ),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? tokens.accentInk : tokens.knob,
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented pill (Açık / Koyu / Sistem): active segment amber, 700 12,
/// 6 × 12 padding.
class SegmentedPill<T> extends StatelessWidget {
  const SegmentedPill({
    required this.options,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// (value, label) pairs in display order.
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: tokens.toggleOff,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (value, label) in options)
            GestureDetector(
              onTap: () => onSelected(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space12,
                  vertical: AppDimensions.space6,
                ),
                decoration: BoxDecoration(
                  color: value == selected ? tokens.accent : null,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                ),
                child: Text(
                  label,
                  style: AppTypography.label.copyWith(
                    fontWeight: FontWeight.w700,
                    color: value == selected ? tokens.accentInk : tokens.text,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
