import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/fake_data.dart';
import '../data/app_state.dart';
import '../widgets/common.dart';

class CustomerView extends StatelessWidget {
  const CustomerView({super.key});

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
                        'CUSTOMER APP · MOBILE',
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
                            ? _buildActiveView(state)
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
  // IDLE — no active disruption (shows clean, on-track order)
  // ============================================================
  Widget _buildIdleView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StatusBar(),
        _CustomerHeader(),
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
                          Text('Order on track',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.ok,
                              )),
                          const SizedBox(height: 2),
                          Text('No disruptions detected for your shipment',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.ok.withOpacity(0.85),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text('YOUR ORDER',
                  style: AppTheme.caption
                      .copyWith(fontSize: 10, letterSpacing: 0.8)),
              const SizedBox(height: 6),
              Text('Order ${FakeData.customerOrderId}',
                  style: AppTheme.h3.copyWith(fontSize: 14)),
              const SizedBox(height: 4),
              Text(FakeData.customerCargo, style: AppTheme.bodyMuted),
              const SizedBox(height: 16),
              const _OrderTimeline(active: 1),
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
                        'Trigger a disruption from the Ops tab to see how we proactively notify the customer.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.inkMuted,
                          height: 1.4,
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
  // ACTIVE DISRUPTION — same event, customer-friendly framing
  // ============================================================
  Widget _buildActiveView(AppState state) {
    final scenario = state.activeDisruption!;
    final impact = scenario.customerImpact;

    // If driver has accepted, show "protected" state, otherwise show "rerouting"
    final isProtected = state.driverDecision == 'accepted' || state.rerouted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StatusBar(),
        _CustomerHeader(),

        // Notification banner — tone reflects whether we've contained it
        Container(
          color: isProtected ? AppTheme.okSoft : AppTheme.infoSoft,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isProtected
                    ? Icons.shield_outlined
                    : Icons.notifications_active_outlined,
                size: 16,
                color: isProtected ? AppTheme.ok : AppTheme.info,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isProtected
                          ? 'Your delivery is protected'
                          : impact.notificationHeadline,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isProtected ? AppTheme.ok : AppTheme.info,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      impact.notificationBody,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.5,
                        color: (isProtected ? AppTheme.ok : AppTheme.info)
                            .withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('YOUR ORDER',
                  style: AppTheme.caption
                      .copyWith(fontSize: 10, letterSpacing: 0.8)),
              const SizedBox(height: 6),
              Text(impact.cargoDescription,
                  style: AppTheme.h3.copyWith(fontSize: 14)),
              const SizedBox(height: 2),
              Text('To: ${impact.customerName}', style: AppTheme.bodyMuted),
              const SizedBox(height: 16),

              // Arrival display — same ETA preserved
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: AppTheme.inkMuted),
                        const SizedBox(width: 6),
                        Text('EXPECTED ARRIVAL',
                            style: AppTheme.caption.copyWith(fontSize: 10)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(impact.arrivalDisplay,
                        style: AppTheme.h2.copyWith(fontSize: 18)),
                    const SizedBox(height: 4),
                    Text(impact.trustFooter,
                        style: TextStyle(
                          fontSize: 11,
                          color: isProtected ? AppTheme.ok : AppTheme.inkMuted,
                          fontWeight: FontWeight.w500,
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text('TRACKING',
                  style: AppTheme.caption
                      .copyWith(fontSize: 10, letterSpacing: 0.8)),
              const SizedBox(height: 8),
              _OrderTimeline(active: isProtected ? 2 : 1, rerouted: true),

              const SizedBox(height: 16),

              // Trust footer — shows the system is doing work for them
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentSoft,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                      color: AppTheme.accent.withOpacity(0.3), width: 0.5),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: AppTheme.accentDark),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.usedGnn
                            ? 'Predicted ${state.atRisk} affected hops via ML model · cascade contained'
                            : 'Detected disruption in ${state.confidence != null ? "${(state.confidence! * 100).toInt()}%" : "high"} confidence · cascade contained',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppTheme.accentDark,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                      child: SecondaryButton(
                    label: 'Contact support',
                    icon: Icons.support_agent_outlined,
                    expand: true,
                    onTap: () {},
                  )),
                  const SizedBox(width: 10),
                  Expanded(
                      child: SecondaryButton(
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
            const Icon(Icons.signal_cellular_alt,
                size: 10, color: AppTheme.inkMuted),
            const SizedBox(width: 4),
            Text('5G · 87%', style: AppTheme.monoSmall),
          ]),
        ],
      ),
    );
  }
}

class _CustomerHeader extends StatelessWidget {
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
                Text('SHIPMENTS',
                    style: AppTheme.caption
                        .copyWith(fontSize: 10, letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Text(FakeData.customerName,
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
              child: Text('AH',
                  style: TextStyle(
                    color: AppTheme.accentDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  )),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTimeline extends StatelessWidget {
  final int active;
  final bool rerouted;
  const _OrderTimeline({required this.active, this.rerouted = false});

  @override
  Widget build(BuildContext context) {
    final steps = rerouted
        ? ['Order placed', 'Disruption detected · rerouting', 'On the way (alt route)', 'Out for delivery']
        : ['Order placed', 'In transit', 'Out for delivery', 'Delivered'];

    return Column(
      children: List.generate(steps.length, (i) {
        final isDone = i < active;
        final isActive = i == active;
        final color = isDone || isActive ? AppTheme.ok : AppTheme.inkSubtle;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      color: isDone || isActive ? color : AppTheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 1.2),
                    ),
                    child: isDone
                        ? const Icon(Icons.check, size: 9, color: Colors.white)
                        : null,
                  ),
                  if (i < steps.length - 1)
                    Container(
                      width: 1.5, height: 18,
                      color: isDone ? color : AppTheme.border,
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 0),
                  child: Text(
                    steps[i],
                    style: TextStyle(
                      fontSize: 12,
                      color: isDone || isActive ? AppTheme.ink : AppTheme.inkSubtle,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
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
          _navItem(Icons.local_shipping_outlined, 'Orders', true),
          _navItem(Icons.search, 'Track', false),
          _navItem(Icons.notifications_outlined, 'Alerts', false),
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
        Text(label,
            style: TextStyle(
              fontSize: 10,
              color: c,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            )),
      ],
    );
  }
}
