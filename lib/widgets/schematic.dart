import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Blueprint grid background — paints a subtle drafting grid.
///
/// Wrap any scaffold or canvas with this for the "drafting notebook" feel.
class BlueprintGrid extends StatelessWidget {
  final Widget child;
  final bool showMajorLines;

  const BlueprintGrid({
    super.key,
    required this.child,
    this.showMajorLines = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _GridPainter(showMajor: showMajorLines),
          ),
        ),
        child,
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  final bool showMajor;
  _GridPainter({required this.showMajor});

  @override
  void paint(Canvas canvas, Size size) {
    const step = AppTheme.gridStep;

    // Minor grid — very faint
    final minor = Paint()
      ..color = AppTheme.gridLine
      ..strokeWidth = 0.3;

    // Major grid — slightly stronger, every 5 steps
    final major = Paint()
      ..color = AppTheme.gridLine.withOpacity(0.18)
      ..strokeWidth = 0.5;

    for (double x = 0; x < size.width; x += step) {
      final isMajor = (x / step).round() % 5 == 0;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        showMajor && isMajor ? major : minor,
      );
    }
    for (double y = 0; y < size.height; y += step) {
      final isMajor = (y / step).round() % 5 == 0;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        showMajor && isMajor ? major : minor,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ============================================================
// SCHEMATIC FRAME — a card/panel with corner brackets instead of rounded rect
// ============================================================

class SchematicFrame extends StatelessWidget {
  final Widget child;
  final Color? borderColor;
  final bool showCorners;
  final EdgeInsetsGeometry padding;

  const SchematicFrame({
    super.key,
    required this.child,
    this.borderColor,
    this.showCorners = true,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final bc = borderColor ?? AppTheme.border;
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border.all(color: bc, width: 0.5),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          padding: padding,
          child: child,
        ),
        if (showCorners) ..._corners(bc),
      ],
    );
  }

  List<Widget> _corners(Color c) {
    return [
      _Corner(alignment: Alignment.topLeft, color: c),
      _Corner(alignment: Alignment.topRight, color: c),
      _Corner(alignment: Alignment.bottomLeft, color: c),
      _Corner(alignment: Alignment.bottomRight, color: c),
    ];
  }
}

class _Corner extends StatelessWidget {
  final Alignment alignment;
  final Color color;
  const _Corner({required this.alignment, required this.color});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: alignment.y < 0 ? -2 : null,
      bottom: alignment.y > 0 ? -2 : null,
      left: alignment.x < 0 ? -2 : null,
      right: alignment.x > 0 ? -2 : null,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: AppTheme.canvas,
          border: Border.all(color: color, width: 0.8),
        ),
      ),
    );
  }
}

// ============================================================
// REVISION LABEL — small mono text in top corner of frames
// ============================================================

class RevisionLabel extends StatelessWidget {
  final String text;
  const RevisionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.canvas,
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Text(text, style: AppTheme.monoSmall.copyWith(fontSize: 9)),
    );
  }
}

// ============================================================
// DIMENSION LINE — schematic measurement indicator
// ============================================================

class DimensionLine extends StatelessWidget {
  final String label;
  final double width;
  const DimensionLine({super.key, required this.label, this.width = 100});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: Size(width, 6),
            painter: _DimPainter(),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTheme.monoSmall.copyWith(fontSize: 9)),
        ],
      ),
    );
  }
}

class _DimPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppTheme.inkSubtle
      ..strokeWidth = 0.5;

    canvas.drawLine(Offset(0, 3), Offset(size.width, 3), p);
    canvas.drawLine(const Offset(0, 0), const Offset(0, 6), p);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, 6), p);
  }

  @override
  bool shouldRepaint(_) => false;
}
