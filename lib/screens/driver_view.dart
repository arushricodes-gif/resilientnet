import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/fake_data.dart';
import '../data/app_state.dart';
import '../data/disruption_library.dart';
import '../widgets/common.dart';

class DriverView extends StatelessWidget {
  const DriverView({super.key});

  /// Generate a scenario-appropriate shipment ID so the driver
  /// never sees the same "SHP-0042" for every disruption.
  String _shipmentIdFor(dynamic scenario) {
    final h = scenario.id.hashCode.abs() % 9000 + 1000;  // stable per-scenario
    return 'SHP-$h';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final state = AppState.instance;
        return Container(
          color: AppTheme.canvas,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Text(
                        'DRIVER APP · MOBILE',
                        style: AppTheme.caption.copyWith(
                          fontSize: 10, letterSpacing: 1.2,
                          color: AppTheme.inkMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AppTheme.borderStrong, width: 0.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: state.hasActiveDisruption
                            ? _buildActiveDisruptionView(state)
                            : _buildIdleView(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // IDLE VIEW — no active disruption
  // ============================================================
  Widget _buildIdleView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StatusBar(),
        _DriverHeader(),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.okSoft,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.okBorder, width: 0.5),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 18, color: AppTheme.ok),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('All routes clear', style: TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700,
                            color: AppTheme.ok,
                          )),
                          const SizedBox(height: 2),
                          Text('No disruptions detected on your routes', style: TextStyle(
                            fontSize: 12, color: AppTheme.ok.withOpacity(0.85),
                          )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text('TODAY\'S TRIP', style: AppTheme.caption.copyWith(
                fontSize: 10, letterSpacing: 0.8,
              )),
              const SizedBox(height: 6),
              Text(
                '${FakeData.driverShipment} · ${FakeData.shipments[0].cargo}',
                style: AppTheme.h3.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const _ProgressCard(),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: AppTheme.inkMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Trigger a disruption from the Ops tab to see how a reroute reaches the driver.',
                        style: TextStyle(
                          fontSize: 11, color: AppTheme.inkMuted, height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const _BottomNav(),
      ],
    );
  }

  // ============================================================
  // ACTIVE DISRUPTION VIEW — reacts to AppState
  // ============================================================
  Widget _buildActiveDisruptionView(AppState state) {
    final scenario = state.activeDisruption!;
    final impact = scenario.driverImpact;
    final decision = state.driverDecision;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StatusBar(),
        _DriverHeader(),

        // Banner — varies based on driver decision
        if (decision == 'pending')
          _AlertBanner(
            headline: impact.alertHeadline,
            detail: impact.alertDetail,
          )
        else if (decision == 'accepted')
          _ResultBanner(
            accent: AppTheme.ok, bg: AppTheme.okSoft, border: AppTheme.okBorder,
            icon: Icons.check_circle_outline,
            title: 'Route accepted',
            subtitle: 'Navigation refreshing · ops notified',
          )
        else
          _ResultBanner(
            accent: AppTheme.risk, bg: AppTheme.riskSoft, border: AppTheme.riskBorder,
            icon: Icons.warning_amber_rounded,
            title: 'Reroute declined',
            subtitle: 'Stay alert · ops aware of your decision',
          ),

        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('CURRENT SHIPMENT', style: AppTheme.caption.copyWith(
                fontSize: 10, letterSpacing: 0.8,
              )),
              const SizedBox(height: 6),
              Text(
                '${_shipmentIdFor(scenario)} · ${impact.shipmentContext}',
                style: AppTheme.h3.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 16),
              _ScenarioProgressCard(scenario: scenario),
              const SizedBox(height: 18),

              Text('COMPARE ROUTES', style: AppTheme.caption.copyWith(
                fontSize: 10, letterSpacing: 0.8,
              )),
              const SizedBox(height: 8),
              _RouteCard(
                badge: 'ORIGINAL',
                name: impact.originalRouteLabel,
                eta: 'ETA ${impact.originalRouteEta}',
                issue: impact.originalRouteIssue,
                risk: impact.originalRouteRiskPercent,
                isBad: true,
              ),
              const SizedBox(height: 8),
              _RouteCard(
                badge: 'PROPOSED',
                name: impact.newRouteLabel,
                eta: 'ETA ${impact.newRouteEta}',
                issue: impact.newRouteIssue,
                risk: impact.newRouteRiskPercent,
                isBad: false,
                highlighted: decision == 'pending',
              ),
              const SizedBox(height: 16),

              if (decision == 'pending')
                Row(
                  children: [
                    Expanded(child: SecondaryButton(
                      label: 'Decline',
                      expand: true,
                      onTap: state.declineReroute,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _AcceptButton(
                      onTap: state.acceptReroute,
                    )),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(child: SecondaryButton(
                      label: 'View on map',
                      icon: Icons.map_outlined,
                      expand: true,
                      onTap: () {},
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: SecondaryButton(
                      label: 'Reset demo',
                      icon: Icons.refresh,
                      expand: true,
                      onTap: state.reset,
                    )),
                  ],
                ),
            ],
          ),
        ),

        const _BottomNav(),
      ],
    );
  }
}

// ============================================================
// SHARED SUB-WIDGETS
// ============================================================

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surfaceSubtle,
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('2:47 PM', style: AppTheme.monoSmall),
          Row(children: [
            const Icon(Icons.signal_cellular_alt, size: 10, color: AppTheme.inkMuted),
            const SizedBox(width: 4),
            Text('5G · 87%', style: AppTheme.monoSmall),
          ]),
        ],
      ),
    );
  }
}

class _DriverHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DRIVER', style: AppTheme.caption.copyWith(
                  fontSize: 10, letterSpacing: 0.8,
                )),
                const SizedBox(height: 2),
                Text('${FakeData.driverName} · ${FakeData.driverVehicle}',
                    style: AppTheme.h3.copyWith(fontSize: 13.5)),
              ],
            ),
          ),
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppTheme.accentSoft, shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('RV', style: TextStyle(
                color: AppTheme.accentDark,
                fontWeight: FontWeight.w700, fontSize: 12.5,
              )),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final String headline;
  final String detail;
  const _AlertBanner({required this.headline, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.warnSoft,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const StatusDot(color: AppTheme.warn, size: 7),
            const SizedBox(width: 8),
            Text(headline, style: TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.warn,
            )),
          ]),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 15),
            child: Text(detail, style: TextStyle(fontSize: 11.5, color: AppTheme.warn)),
          ),
        ],
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  final Color accent, bg, border;
  final IconData icon;
  final String title, subtitle;
  const _ResultBanner({
    required this.accent, required this.bg, required this.border,
    required this.icon, required this.title, required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: accent,
              )),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(
                fontSize: 11.5, color: accent.withOpacity(0.85),
              )),
            ],
          )),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('FROM', style: AppTheme.caption.copyWith(fontSize: 10)),
                  const SizedBox(height: 2),
                  Text(FakeData.shipments[0].origin, style: AppTheme.h3.copyWith(fontSize: 13)),
                ],
              )),
              Icon(Icons.arrow_forward, size: 14, color: AppTheme.inkMuted),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('TO', style: AppTheme.caption.copyWith(fontSize: 10)),
                  const SizedBox(height: 2),
                  Text(FakeData.shipments[0].destination, style: AppTheme.h3.copyWith(fontSize: 13)),
                ],
              )),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: FakeData.driverProgress,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.ok,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${FakeData.driverKmDone} km done', style: AppTheme.monoSmall),
              Text('${FakeData.driverKmLeft} km left', style: AppTheme.monoSmall),
            ],
          ),
        ],
      ),
    );
  }
}

/// Scenario-specific progress card — parses the scenario's original route
/// to show dynamic from/to instead of hardcoded Bengaluru → Chennai.
class _ScenarioProgressCard extends StatelessWidget {
  final dynamic scenario;  // DisruptionScenario (typed as dynamic to avoid import cycle)
  const _ScenarioProgressCard({required this.scenario});

  /// Parse a route label like "Mumbai → Pune (NH-48)" into ("Mumbai", "Pune")
  /// Handles formats:
  ///   "Mumbai → Pune (NH-48)"      -> Mumbai, Pune
  ///   "Chennai Port (direct)"       -> Chennai Port, (delivery)
  ///   "NH-48 direct"                -> origin hub, (delivery)
  ///   "Pickup at Bengaluru DC"      -> Bengaluru DC, (delivery)
  ///   "transship at Singapore"      -> Singapore, (next hop)
  (String, String) _parseRoute(String label) {
    // Has → → parse "A → B (something)"
    if (label.contains('→')) {
      final parts = label.split('→');
      final from = parts[0].trim();
      var to = parts[1].trim();
      // Strip parenthetical
      final idx = to.indexOf('(');
      if (idx > 0) to = to.substring(0, idx).trim();
      return (from, to);
    }
    // "Pickup at X" -> X is origin
    if (label.toLowerCase().startsWith('pickup at ')) {
      return (label.substring('pickup at '.length).trim(), 'Delivery point');
    }
    // "transship at X" -> X is next hop
    if (label.toLowerCase().startsWith('transship at ')) {
      return (scenario.location, label.substring('transship at '.length).trim());
    }
    // Fallback: location is origin
    return (scenario.location, 'Delivery point');
  }

  @override
  Widget build(BuildContext context) {
    final (from, to) = _parseRoute(scenario.driverImpact.originalRouteLabel);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('FROM', style: AppTheme.caption.copyWith(fontSize: 10)),
                  const SizedBox(height: 2),
                  Text(from, style: AppTheme.h3.copyWith(fontSize: 13)),
                ],
              )),
              Icon(Icons.arrow_forward, size: 14, color: AppTheme.inkMuted),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('TO', style: AppTheme.caption.copyWith(fontSize: 10)),
                  const SizedBox(height: 2),
                  Text(to, style: AppTheme.h3.copyWith(fontSize: 13)),
                ],
              )),
            ],
          ),
          const SizedBox(height: 12),
          // Generic progress bar - the actual values don't really matter
          // for the demo narrative; we want to show "partway through trip"
          Stack(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: 0.42,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.ok,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('In transit · original ETA ${scenario.driverImpact.originalRouteEta}',
                  style: AppTheme.monoSmall),
              Text('risk ${scenario.driverImpact.originalRouteRiskPercent}%',
                  style: AppTheme.monoSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final String badge, name, eta, issue;
  final int risk;
  final bool isBad, highlighted;

  const _RouteCard({
    required this.badge, required this.name, required this.eta,
    required this.issue, required this.risk,
    this.isBad = false, this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isBad ? AppTheme.risk : AppTheme.ok;
    final bg = isBad ? AppTheme.riskSoft : AppTheme.okSoft;
    final border = isBad ? AppTheme.riskBorder : AppTheme.okBorder;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: highlighted ? accent : border,
          width: highlighted ? 1.5 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(badge, style: TextStyle(
                  fontSize: 9.5, fontWeight: FontWeight.w700,
                  color: accent, letterSpacing: 0.6,
                )),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(name, style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: accent,
                ), overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('risk $risk%', style: TextStyle(
                fontSize: 11, color: accent, fontWeight: FontWeight.w600,
              )),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: Text('$eta · $issue', style: TextStyle(
              fontSize: 11, color: accent.withOpacity(0.85),
            )),
          ),
        ],
      ),
    );
  }
}

class _AcceptButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AcceptButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.ok,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Text('Accept reroute', style: TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.navigation, 'Trip', true),
          _navItem(Icons.inbox_outlined, 'Inbox', false),
          _navItem(Icons.qr_code, 'POD', false),
          _navItem(Icons.person_outline, 'Profile', false),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active) {
    final c = active ? AppTheme.ink : AppTheme.inkSubtle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: c),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(
          fontSize: 10, color: c,
          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
        )),
      ],
    );
  }
}
