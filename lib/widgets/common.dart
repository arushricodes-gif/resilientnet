import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ============================================================
// SECTION CARD — white panel with border and optional header
// ============================================================

class SectionCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SectionCard({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(title!.toUpperCase(), style: AppTheme.callout.copyWith(
                              fontSize: 10, color: AppTheme.ink, letterSpacing: 1.4,
                            )),
                            const SizedBox(width: 8),
                            // Schematic rule (dashed line continuing the label)
                            Expanded(
                              child: CustomPaint(
                                size: const Size.fromHeight(1),
                                painter: _DashedHRule(),
                              ),
                            ),
                          ],
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(subtitle!, style: AppTheme.bodyMuted.copyWith(fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    trailing!,
                  ],
                ],
              ),
            ),
          if (title != null)
            Container(height: 0.5, color: AppTheme.border),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

// Dashed horizontal rule — schematic line for card headers
class _DashedHRule extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppTheme.borderStrong.withOpacity(0.5)
      ..strokeWidth = 0.5;

    const dash = 2.5, gap = 2.5;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), p);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ============================================================
// KPI CARD — terminal-style stat block
// ============================================================

class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? delta;
  final Color? accentColor;
  final IconData? icon;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.accentColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppTheme.ink;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border.all(color: AppTheme.border, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Label row — small mono callout
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 11, color: AppTheme.inkMuted),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      label.toUpperCase(),
                      style: AppTheme.callout.copyWith(
                        fontSize: 9.5,
                        letterSpacing: 1.3,
                        color: AppTheme.inkMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Serif number — big, confident
              Text(value, style: AppTheme.kpiNumber.copyWith(color: accent)),
              if (delta != null) ...[
                const SizedBox(height: 6),
                // Small mono caption with subtle divider above
                Container(
                  height: 0.5,
                  color: AppTheme.borderFaint,
                  margin: const EdgeInsets.only(bottom: 6),
                ),
                Text(delta!, style: AppTheme.monoSmall),
              ],
            ],
          ),
        ),
        // Schematic corner markers
        _kpiCorner(Alignment.topLeft),
        _kpiCorner(Alignment.topRight),
        _kpiCorner(Alignment.bottomLeft),
        _kpiCorner(Alignment.bottomRight),
      ],
    );
  }

  Widget _kpiCorner(Alignment a) {
    return Positioned(
      top: a.y < 0 ? -2 : null,
      bottom: a.y > 0 ? -2 : null,
      left: a.x < 0 ? -2 : null,
      right: a.x > 0 ? -2 : null,
      child: Container(
        width: 5, height: 5,
        decoration: BoxDecoration(
          color: AppTheme.canvas,
          border: Border.all(color: AppTheme.borderStrong, width: 0.6),
        ),
      ),
    );
  }
}

// ============================================================
// STATUS DOT — small colored indicator
// ============================================================

class StatusDot extends StatelessWidget {
  final Color color;
  final double size;
  const StatusDot({super.key, required this.color, this.size = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ============================================================
// BADGE / PILL
// ============================================================

class StatusBadge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final Color? borderColor;

  const StatusBadge({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
    this.borderColor,
  });

  factory StatusBadge.risk(String label) => StatusBadge(
        label: label,
        bg: AppTheme.riskSoft,
        fg: AppTheme.risk,
        borderColor: AppTheme.riskBorder,
      );

  factory StatusBadge.warn(String label) => StatusBadge(
        label: label,
        bg: AppTheme.warnSoft,
        fg: AppTheme.warn,
        borderColor: AppTheme.warnBorder,
      );

  factory StatusBadge.ok(String label) => StatusBadge(
        label: label,
        bg: AppTheme.okSoft,
        fg: AppTheme.ok,
        borderColor: AppTheme.okBorder,
      );

  factory StatusBadge.info(String label) => StatusBadge(
        label: label,
        bg: AppTheme.infoSoft,
        fg: AppTheme.info,
        borderColor: AppTheme.infoBorder,
      );

  factory StatusBadge.neutral(String label) => StatusBadge(
        label: label,
        bg: AppTheme.surfaceSubtle,
        fg: AppTheme.ink,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 0.5)
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ============================================================
// PRIMARY / SECONDARY BUTTON
// ============================================================

class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool danger;
  final bool expand;

  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.danger = false,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = danger ? AppTheme.risk : AppTheme.ink;
    final btn = Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Text(label, style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              )),
            ],
          ),
        ),
      ),
    );
    return btn;
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool expand;

  const SecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.border, width: 0.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: AppTheme.ink),
                const SizedBox(width: 6),
              ],
              Text(label, style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// RISK BAR — visual risk score indicator
// ============================================================

class RiskBar extends StatelessWidget {
  final double value; // 0..1
  final double width;
  const RiskBar({super.key, required this.value, this.width = 60});

  Color get _color {
    if (value >= 0.7) return AppTheme.risk;
    if (value >= 0.4) return AppTheme.warn;
    return AppTheme.ok;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: width, height: 4,
          decoration: BoxDecoration(
            color: AppTheme.border,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(value * 100).toStringAsFixed(0)}',
          style: AppTheme.mono.copyWith(fontSize: 11, color: _color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// ============================================================
// BANNER — informational banner (alert, notification)
// ============================================================

class InlineBanner extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color bg;
  final Color fg;
  final Color? borderColor;
  final Widget? action;

  const InlineBanner({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.bg,
    required this.fg,
    this.borderColor,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 0.5)
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(
                  color: fg,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                )),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: TextStyle(
                    color: fg.withOpacity(0.85),
                    fontSize: 12,
                    height: 1.4,
                  )),
                ],
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 10), action!],
        ],
      ),
    );
  }
}
