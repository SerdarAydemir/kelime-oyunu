// lib/features/map/widgets/map_nodes.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/features/map/cubit/map_state.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// One node of the climb map, drawn per [kind] (README "Node states").
/// [onTap] null renders an inert node.
class MapNode extends StatelessWidget {
  const MapNode({
    required this.level,
    required this.kind,
    required this.onTap,
    this.showNumber = false,
    super.key,
  });

  final int level;
  final MapNodeKind kind;
  final VoidCallback? onTap;

  /// DEV_UNLOCK_ALL: number the upcoming / far nodes too.
  final bool showNumber;

  /// Diameter / side of the node for [kind] — used to centre it on the trail.
  static double sizeOf(MapNodeKind kind) => switch (kind) {
    MapNodeKind.done => 48,
    MapNodeKind.current => 68,
    MapNodeKind.upcoming => 44,
    MapNodeKind.far => 14,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = switch (kind) {
      MapNodeKind.done => l10n.levelDone(level),
      MapNodeKind.current => l10n.levelCurrent(level),
      MapNodeKind.upcoming || MapNodeKind.far => l10n.levelLocked(level),
    };
    final child = switch (kind) {
      MapNodeKind.done => _DoneCard(level: level),
      MapNodeKind.current => _CurrentNode(level: level),
      MapNodeKind.upcoming => _UpcomingNode(level: showNumber ? level : null),
      MapNodeKind.far => _FarNode(level: showNumber ? level : null),
    };
    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label: label,
      child: GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: child),
    );
  }
}

/// 48 dp r12 card on `board` with a 2 px amber border and a 2 × 2 mini grid:
/// clue / letter with the level number / letter / amber.
class _DoneCard extends StatelessWidget {
  const _DoneCard({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    Widget cell(Color color, [Widget? child]) => Container(
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      alignment: Alignment.center,
      child: child,
    );
    return Container(
      width: 48,
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.board,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.accent, width: 2),
      ),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          cell(tokens.cellClue),
          cell(
            tokens.cellLetter,
            Text(
              '$level',
              textScaler: TextScaler.noScaling,
              style: AppTypography.screenTitle.copyWith(fontSize: 11, color: tokens.ink),
            ),
          ),
          cell(tokens.cellLetter),
          cell(tokens.accent),
        ],
      ),
    );
  }
}

/// 68 dp amber circle: number Lora 24 + "BURADASIN", a pulsing ring (2 s)
/// and the amber glow.
class _CurrentNode extends StatefulWidget {
  const _CurrentNode({required this.level});

  final int level;

  @override
  State<_CurrentNode> createState() => _CurrentNodeState();
}

class _CurrentNodeState extends State<_CurrentNode> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = _pulse.value;
        return Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tokens.accent,
            // Pulse ring: expands and fades over the 2 s loop.
            border: Border.all(
              color: tokens.accent.withValues(alpha: 1 - t),
              width: 3 + 6 * t,
            ),
            boxShadow: [BoxShadow(color: tokens.accent.withValues(alpha: 0.5), blurRadius: 40)],
          ),
          child: child,
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${widget.level}',
            textScaler: TextScaler.noScaling,
            style: AppTypography.screenTitle.copyWith(fontSize: 24, color: tokens.accentInk),
          ),
          Text(
            l10n.here,
            textScaler: TextScaler.noScaling,
            style: AppTypography.buttonPrimary.copyWith(
              fontSize: 8,
              height: 1,
              color: tokens.accentInk,
            ),
          ),
        ],
      ),
    );
  }
}

/// 44 dp dashed circle with a lock (no number — unless DEV numbering).
class _UpcomingNode extends StatelessWidget {
  const _UpcomingNode({required this.level});

  final int? level;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return CustomPaint(
      painter: _DashedCirclePainter(color: tokens.faint),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: level == null
              ? Icon(Icons.lock, size: AppDimensions.iconS, color: tokens.faint)
              : Text(
                  '$level',
                  textScaler: TextScaler.noScaling,
                  style: AppTypography.nodeNumber.copyWith(color: tokens.text),
                ),
        ),
      ),
    );
  }
}

/// 14 dp faint dot; numbered (and larger hit area) only under DEV_UNLOCK_ALL.
class _FarNode extends StatelessWidget {
  const _FarNode({required this.level});

  final int? level;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (level == null) {
      return Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(shape: BoxShape.circle, color: tokens.faint),
      );
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(shape: BoxShape.circle, color: tokens.surface),
      alignment: Alignment.center,
      child: Text(
        '$level',
        textScaler: TextScaler.noScaling,
        style: AppTypography.label.copyWith(color: tokens.text),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addOval((Offset.zero & size).deflate(1));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, (d + 4).clamp(0, metric.length)), paint);
        d += 8;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter old) => color != old.color;
}
