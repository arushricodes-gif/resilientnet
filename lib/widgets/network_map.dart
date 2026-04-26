import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';
import '../data/fake_data.dart';

/// Schematic network map using CustomPainter.
///
/// Day 1 placeholder that looks production-quality. Replace with
/// google_maps_flutter on Day 2 if you want real cartography, but this
/// actually reads as cleaner for a dashboard aesthetic.
class NetworkMap extends StatelessWidget {
  final String? disruptedHubId;
  final bool showCascade;

  const NetworkMap({
    super.key,
    this.disruptedHubId,
    this.showCascade = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.borderStrong, width: 0.5),
      ),
      child: ClipRect(
        child: Stack(
          children: [
            // Subtle grid background
            Positioned.fill(
              child: CustomPaint(painter: _GridPainter()),
            ),
            // Main network
            Positioned.fill(
              child: CustomPaint(
                painter: _NetworkPainter(
                  hubs: FakeData.hubs,
                  disruptedHubId: disruptedHubId,
                  showCascade: showCascade,
                ),
              ),
            ),
            // Top-left label — drawing title block style
            Positioned(
              top: 10, left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border.all(color: AppTheme.borderStrong, width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('FIG 01',
                        style: AppTheme.monoSmall.copyWith(
                          fontSize: 9, color: AppTheme.inkMuted,
                        )),
                    Container(
                      width: 0.5, height: 12,
                      color: AppTheme.border,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    Text('SUPPLY NETWORK · REV 0.1',
                        style: AppTheme.callout.copyWith(
                          fontSize: 9.5, color: AppTheme.ink,
                          letterSpacing: 1.2,
                        )),
                  ],
                ),
              ),
            ),
            // Coords display top-right
            Positioned(
              top: 10, right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border.all(color: AppTheme.border, width: 0.5),
                ),
                child: Text(
                  'N 15 · E 35',
                  style: AppTheme.monoSmall.copyWith(fontSize: 9),
                ),
              ),
            ),
            // Legend bottom-right
            Positioned(
              bottom: 12, right: 14,
              child: _Legend(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  Widget _item(Color c, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mini crosshair
        CustomPaint(
          size: const Size(10, 10),
          painter: _MiniCrossPainter(color: c),
        ),
        const SizedBox(width: 8),
        Text(label.toUpperCase(), style: AppTheme.callout.copyWith(
          fontSize: 9, color: AppTheme.inkMuted,
          letterSpacing: 1.1,
        )),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.borderStrong, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _item(AppTheme.accent, 'Hub'),
          _item(AppTheme.risk, 'Disrupted'),
          _item(AppTheme.warn, 'At risk'),
        ],
      ),
    );
  }
}

class _MiniCrossPainter extends CustomPainter {
  final Color color;
  _MiniCrossPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..strokeWidth = 1;
    canvas.drawLine(Offset(0, s.height / 2), Offset(s.width, s.height / 2), p);
    canvas.drawLine(Offset(s.width / 2, 0), Offset(s.width / 2, s.height), p);
    canvas.drawCircle(Offset(s.width / 2, s.height / 2), 1.2, Paint()..color = color);
  }
  @override
  bool shouldRepaint(_) => false;
}

// ============================================================
// Grid painter — subtle background
// ============================================================

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Warm paper base
    final bg = Paint()..color = AppTheme.canvasSubtle;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    // Minor grid lines
    final minor = Paint()
      ..color = AppTheme.gridLine
      ..strokeWidth = 0.3;

    // Major grid lines every 5 steps
    final major = Paint()
      ..color = AppTheme.gridLine.withOpacity(0.28)
      ..strokeWidth = 0.5;

    const step = 24.0;
    int i = 0;
    for (double x = 0; x < size.width; x += step) {
      final isMajor = i % 5 == 0;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height),
          isMajor ? major : minor);
      i++;
    }
    i = 0;
    for (double y = 0; y < size.height; y += step) {
      final isMajor = i % 5 == 0;
      canvas.drawLine(Offset(0, y), Offset(size.width, y),
          isMajor ? major : minor);
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}

// ============================================================
// Network painter — hubs, edges, disruption effects
// ============================================================

class _NetworkPainter extends CustomPainter {
  final List<Hub> hubs;
  final String? disruptedHubId;
  final bool showCascade;

  _NetworkPainter({
    required this.hubs,
    this.disruptedHubId,
    this.showCascade = false,
  });

  // Map lat/lng to canvas coordinates.
  // Focus bounds: roughly the Indian subcontinent with room for international hubs.
  Offset _project(double lat, double lng, Size size) {
    // Bounds covering India + Singapore + Dubai + Europe
    const minLng = 60.0, maxLng = 110.0;
    const minLat = 0.0,  maxLat = 55.0;

    final x = ((lng - minLng) / (maxLng - minLng)) * size.width;
    final y = size.height - ((lat - minLat) / (maxLat - minLat)) * size.height;

    // Inset 40px from edges
    return Offset(
      x.clamp(40.0, size.width - 40),
      y.clamp(40.0, size.height - 40),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw edges between major hub pairs
    final edgePaint = Paint()
      ..color = AppTheme.border
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final majorEdges = <List<String>>[
      ['HUB-00', 'HUB-09'], // Mumbai -> Singapore
      ['HUB-00', 'HUB-10'], // Mumbai -> Dubai
      ['HUB-10', 'HUB-11'], // Dubai -> Rotterdam
      ['HUB-02', 'HUB-09'], // Chennai -> Singapore
      ['HUB-00', 'HUB-04'], // Mumbai -> Delhi
      ['HUB-05', 'HUB-02'], // Bengaluru -> Chennai
      ['HUB-06', 'HUB-00'], // Pune -> Mumbai
      ['HUB-07', 'HUB-05'], // Hyd -> Bengaluru
      ['HUB-08', 'HUB-00'], // Ahmedabad -> Mumbai
      ['HUB-03', 'HUB-04'], // Kolkata -> Delhi
      ['HUB-12', 'HUB-14'], // Delhi Air -> Frankfurt Air
      ['HUB-13', 'HUB-14'], // Mumbai Air -> Frankfurt Air
    ];

    for (final edge in majorEdges) {
      final a = hubs.firstWhere((h) => h.id == edge[0]);
      final b = hubs.firstWhere((h) => h.id == edge[1]);
      final ap = _project(a.lat, a.lng, size);
      final bp = _project(b.lat, b.lng, size);

      // Dashed line for visual style
      _drawDashedLine(canvas, ap, bp, edgePaint);
    }

    // 2. Draw disruption blast radius if active
    if (disruptedHubId != null) {
      final hub = hubs.firstWhere((h) => h.id == disruptedHubId);
      final p = _project(hub.lat, hub.lng, size);

      if (showCascade) {
        // Multiple pulse rings for cascade effect
        for (int i = 0; i < 3; i++) {
          final radius = 30.0 + i * 20;
          final alpha = 0.15 - i * 0.04;
          canvas.drawCircle(p, radius, Paint()
            ..color = AppTheme.risk.withOpacity(alpha)
            ..style = PaintingStyle.fill);
        }
      }
    }

    // 3. Draw hubs as schematic crosshair markers (drafting-style)
    for (final hub in hubs) {
      final p = _project(hub.lat, hub.lng, size);
      final isDisrupted = hub.id == disruptedHubId;

      final Color markerColor = isDisrupted ? AppTheme.risk : AppTheme.accent;
      final double size2 = isDisrupted ? 9 : 7;

      // Paper-colored background square to clear grid behind marker
      canvas.drawRect(
        Rect.fromCenter(center: p, width: size2 * 2, height: size2 * 2),
        Paint()..color = AppTheme.surface,
      );

      // Crosshair lines
      final cross = Paint()
        ..color = markerColor
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.square;
      canvas.drawLine(Offset(p.dx - size2, p.dy), Offset(p.dx + size2, p.dy), cross);
      canvas.drawLine(Offset(p.dx, p.dy - size2), Offset(p.dx, p.dy + size2), cross);

      // Center dot
      canvas.drawCircle(p, 1.8, Paint()..color = markerColor);

      // Outer circle for disrupted hub (target ring)
      if (isDisrupted) {
        canvas.drawCircle(p, size2 + 3, Paint()
          ..color = markerColor
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke);
      }

      // Label — only for major hubs to avoid clutter
      final majorHubs = {'HUB-00', 'HUB-02', 'HUB-04', 'HUB-05',
                        'HUB-09', 'HUB-10', 'HUB-11'};
      if (majorHubs.contains(hub.id)) {
        final shortName = hub.name.replaceAll(' Port', '').replaceAll(' DC', '');
        // Hub ID in mono — subscript
        final idPainter = TextPainter(
          text: TextSpan(
            text: hub.id,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w500,
              fontFamilyFallback: const ['monospace'],
              color: AppTheme.inkSubtle,
              letterSpacing: 0.3,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        idPainter.layout();
        idPainter.paint(canvas, Offset(p.dx + size2 + 4, p.dy - 10));

        // Hub name
        final tp = TextPainter(
          text: TextSpan(
            text: shortName,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDisrupted ? AppTheme.risk : AppTheme.ink,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(canvas, Offset(p.dx + size2 + 4, p.dy + 1));
      }
    }

    // 4. Draw simulated "in-transit" markers as tiny square symbols (not dots)
    final rng = math.Random(42);
    final transitPaint = Paint()
      ..color = AppTheme.inkMuted
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 20; i++) {
      final edge = majorEdges[rng.nextInt(majorEdges.length)];
      final a = hubs.firstWhere((h) => h.id == edge[0]);
      final b = hubs.firstWhere((h) => h.id == edge[1]);
      final ap = _project(a.lat, a.lng, size);
      final bp = _project(b.lat, b.lng, size);
      final t = rng.nextDouble();
      final p = Offset.lerp(ap, bp, t)!;
      canvas.drawRect(
        Rect.fromCenter(center: p, width: 3, height: 3),
        transitPaint,
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 3.0;
    const dashSpace = 3.0;
    final distance = (end - start).distance;
    final direction = (end - start) / distance;
    double covered = 0;
    while (covered < distance) {
      final dashEnd = math.min(covered + dashWidth, distance);
      canvas.drawLine(
        start + direction * covered,
        start + direction * dashEnd,
        paint,
      );
      covered += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _NetworkPainter oldDelegate) =>
      oldDelegate.disruptedHubId != disruptedHubId ||
      oldDelegate.showCascade != showCascade;
}
