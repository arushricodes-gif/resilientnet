import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

/// Drop-in widgets for the live Firebase disruption feed.
///
/// Usage:
///   // On the ops dashboard — full feed
///   LiveDisruptionFeed()
///
///   // On the customer shipment page — scoped to one shipment
///   ShipmentAlertCard(shipmentId: 'SHP-0042')
///
///   // In the app header — just the status bar
///   LiveStatusBar()

// ── LiveDisruptionFeed ────────────────────────────────────────────────────────

/// Full live feed of all active disruptions.
/// Wrap this in a Scaffold body or a panel on the ops dashboard.
class LiveDisruptionFeed extends StatelessWidget {
  final double severityMin;
  final int limit;
  final void Function(DisruptionEvent)? onTap;

  const LiveDisruptionFeed({
    super.key,
    this.severityMin = 0.0,
    this.limit = 50,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DisruptionEvent>>(
      stream: FirebaseService.liveDisruptions(
        severityMin: severityMin,
        limit: limit,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Connecting to live feed...'),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return _ErrorCard(
            message: 'Firebase connection error: ${snapshot.error}',
            hint: 'Check that Firebase is configured and serviceAccountKey.json is set.',
          );
        }

        final events = snapshot.data ?? [];

        if (events.isEmpty) {
          return const _EmptyFeed();
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: events.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _DisruptionCard(
            event: events[i],
            onTap: onTap != null ? () => onTap!(events[i]) : null,
          ),
        );
      },
    );
  }
}

// ── ShipmentAlertCard ─────────────────────────────────────────────────────────

/// Shows disruption alerts for a specific shipment.
/// Drop this into the customer view shipment detail page.
class ShipmentAlertCard extends StatelessWidget {
  final String shipmentId;

  const ShipmentAlertCard({super.key, required this.shipmentId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DisruptionEvent>>(
      stream: FirebaseService.disruptionsForShipment(shipmentId),
      builder: (context, snapshot) {
        final events = snapshot.data ?? [];

        if (events.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text('No disruptions affecting this shipment',
                    style: TextStyle(color: Colors.green)),
              ],
            ),
          );
        }

        // Show the most severe disruption as a banner
        final worst = events.reduce((a, b) => a.severity > b.severity ? a : b);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Color(worst.severityColor).withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Color(worst.severityColor).withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(worst.typeIcon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      worst.headline,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _SeverityBadge(severity: worst.severity, label: worst.severityLabel),
                ],
              ),
              if (worst.reroutesAvailable > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '✅ ${worst.reroutesAvailable} alternative route${worst.reroutesAvailable > 1 ? 's' : ''} available',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (events.length > 1) ...[
                const SizedBox(height: 4),
                Text(
                  '+${events.length - 1} more disruption${events.length > 2 ? 's' : ''} in region',
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── LiveStatusBar ─────────────────────────────────────────────────────────────

/// Compact status bar for the app header / AppBar bottom.
/// Shows "🔴 3 active disruptions · updated 2 min ago"
class LiveStatusBar extends StatelessWidget {
  const LiveStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RealtimeStatus>(
      stream: FirebaseService.realtimeStatus(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 24,
            child: Center(
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final status = snapshot.data!;
        final count = status.activeDisruptions;
        final hasDisruptions = count > 0;

        String timeAgo = '';
        if (status.lastUpdated != null) {
          final diff = DateTime.now().difference(status.lastUpdated!);
          if (diff.inMinutes < 1) {
            timeAgo = 'just now';
          } else if (diff.inMinutes < 60) {
            timeAgo = '${diff.inMinutes}m ago';
          } else {
            timeAgo = '${diff.inHours}h ago';
          }
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: hasDisruptions
                ? Colors.red.withOpacity(0.1)
                : Colors.green.withOpacity(0.1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pulsing dot
              _PulsingDot(color: hasDisruptions ? Colors.red : Colors.green),
              const SizedBox(width: 6),
              Text(
                hasDisruptions
                    ? '$count active disruption${count > 1 ? 's' : ''}'
                    : 'No disruptions detected',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: hasDisruptions ? Colors.red[700] : Colors.green[700],
                ),
              ),
              if (timeAgo.isNotEmpty) ...[
                Text(
                  ' · updated $timeAgo',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
              const Spacer(),
              // LIVE badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Internal widgets ──────────────────────────────────────────────────────────

class _DisruptionCard extends StatelessWidget {
  final DisruptionEvent event;
  final VoidCallback? onTap;

  const _DisruptionCard({required this.event, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Color(event.severityColor);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.typeIcon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      event.headline,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SeverityBadge(severity: event.severity, label: event.severityLabel),
                ],
              ),
              const SizedBox(height: 8),
              // Stats row
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  if (event.location != null)
                    _Chip(icon: Icons.location_on, text: event.location!),
                  _Chip(icon: Icons.local_shipping,
                      text: '${event.shipmentsAtRisk} shipments at risk'),
                  if (event.reroutesAvailable > 0)
                    _Chip(
                      icon: Icons.alt_route,
                      text: '${event.reroutesAvailable} reroutes',
                      color: Colors.green[700],
                    ),
                  if (event.estimatedDelayHours > 0)
                    _Chip(
                      icon: Icons.schedule,
                      text: '+${event.estimatedDelayHours.toStringAsFixed(1)}h delay',
                      color: Colors.orange[700],
                    ),
                ],
              ),
              const SizedBox(height: 6),
              // Footer
              Row(
                children: [
                  Text(
                    event.source,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  const Spacer(),
                  if (event.isRealtime)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  final double severity;
  final String label;

  const _SeverityBadge({required this.severity, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = Color(DisruptionEvent(
      id: '', headline: '', source: '', type: '', severity: severity,
      affectedMode: '', confidence: 0, cascadeProbability: 0,
      shipmentsAtRisk: 0, affectedHubs: [], estimatedDelayHours: 0,
      reroutesAvailable: 0, status: '', isRealtime: false,
    ).severityColor);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color.withOpacity(0.9),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _Chip({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.grey[600]!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 11, color: c)),
      ],
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.green[300]),
          const SizedBox(height: 12),
          const Text(
            'No active disruptions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'The system is monitoring in real time',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final String hint;

  const _ErrorCard({required this.message, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 48, color: Colors.orange),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(hint,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
