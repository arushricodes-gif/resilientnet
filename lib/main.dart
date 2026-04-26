import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/app_theme.dart';
import 'screens/ops_dashboard.dart';
import 'screens/driver_view.dart';
import 'screens/customer_view.dart';

void main() {
  runApp(const ResilientNetApp());
}

class ResilientNetApp extends StatelessWidget {
  const ResilientNetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ResilientNet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.material,
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with SingleTickerProviderStateMixin {
  late TabController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 3, vsync: this);
    _controller.addListener(() {
      if (!_controller.indexIsChanging) {
        setState(() => _index = _controller.index);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: Column(
        children: [
          _TopBar(controller: _controller, index: _index),
          Expanded(
            child: TabBarView(
              controller: _controller,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                OpsDashboard(),
                DriverView(),
                CustomerView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TOP BAR — logo · tabs · status
// ============================================================

class _TopBar extends StatelessWidget {
  final TabController controller;
  final int index;

  const _TopBar({required this.controller, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            // Logo / brand
            _Brand(),
            const SizedBox(width: 32),

            // Tabs
            Expanded(
              child: _CustomTabs(
                controller: controller,
                activeIndex: index,
                tabs: const [
                  _TabItem(icon: Icons.hub_outlined, label: 'Ops'),
                  _TabItem(icon: Icons.local_shipping_outlined, label: 'Driver'),
                  _TabItem(icon: Icons.business_outlined, label: 'Customer'),
                ],
              ),
            ),

            // Right side status
            _StatusIndicator(),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Logo mark — concentric schematic crosshair
        SizedBox(
          width: 28, height: 28,
          child: CustomPaint(painter: _LogoMarkPainter()),
        ),
        const SizedBox(width: 10),
        // Serif wordmark — the hero typographic moment
        Text('ResilientNet',
            style: GoogleFonts.fraunces(
              fontSize: 19,
              fontWeight: FontWeight.w500,
              color: AppTheme.ink,
              letterSpacing: -0.5,
              height: 1,
            )),
        const SizedBox(width: 10),
        // Drawing-title revision block
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: AppTheme.border, width: 0.5),
          ),
          child: Text('DWG 001 · R0.1',
              style: GoogleFonts.ibmPlexMono(
                fontSize: 9,
                color: AppTheme.inkMuted,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              )),
        ),
      ],
    );
  }
}

class _LogoMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final p = Paint()
      ..color = AppTheme.ink
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;

    // Outer square bracket frame
    final bracketSize = 6.0;
    final outer = Offset(size.width - 2, size.height - 2);
    // Top-left bracket
    canvas.drawLine(const Offset(2, 2), Offset(2 + bracketSize, 2), p);
    canvas.drawLine(const Offset(2, 2), Offset(2, 2 + bracketSize), p);
    // Top-right
    canvas.drawLine(Offset(outer.dx, 2), Offset(outer.dx - bracketSize, 2), p);
    canvas.drawLine(Offset(outer.dx, 2), Offset(outer.dx, 2 + bracketSize), p);
    // Bottom-left
    canvas.drawLine(Offset(2, outer.dy), Offset(2 + bracketSize, outer.dy), p);
    canvas.drawLine(Offset(2, outer.dy), Offset(2, outer.dy - bracketSize), p);
    // Bottom-right
    canvas.drawLine(outer, Offset(outer.dx - bracketSize, outer.dy), p);
    canvas.drawLine(outer, Offset(outer.dx, outer.dy - bracketSize), p);

    // Inner crosshair
    final cross = Paint()
      ..color = AppTheme.accent
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(c.dx - 5, c.dy), Offset(c.dx + 5, c.dy), cross);
    canvas.drawLine(Offset(c.dx, c.dy - 5), Offset(c.dx, c.dy + 5), cross);
    canvas.drawCircle(c, 1.8, Paint()..color = AppTheme.accent);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ============================================================
// CUSTOM TABS (underline style — enterprise dashboard feel)
// ============================================================

class _TabItem {
  final IconData icon;
  final String label;
  const _TabItem({required this.icon, required this.label});
}

class _CustomTabs extends StatelessWidget {
  final TabController controller;
  final int activeIndex;
  final List<_TabItem> tabs;

  const _CustomTabs({
    required this.controller,
    required this.activeIndex,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: tabs.asMap().entries.map((entry) {
        final i = entry.key;
        final tab = entry.value;
        final active = i == activeIndex;
        return GestureDetector(
          onTap: () => controller.animateTo(i),
          behavior: HitTestBehavior.opaque,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              height: 56,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: active ? AppTheme.ink : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tab.icon, size: 16, color: active ? AppTheme.ink : AppTheme.inkMuted),
                  const SizedBox(width: 8),
                  Text(tab.label, style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active ? AppTheme.ink : AppTheme.inkMuted,
                  )),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ============================================================
// STATUS INDICATOR (top-right)
// ============================================================

class _StatusIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.okSoft,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppTheme.okBorder, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(
                  color: AppTheme.ok,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text('All systems live', style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.ok,
              )),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: AppTheme.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(Icons.notifications_none, size: 14, color: AppTheme.ink),
        ),
        const SizedBox(width: 8),
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: AppTheme.accent,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Center(
            child: Text('AK', style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            )),
          ),
        ),
      ],
    );
  }
}
