import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// FirebaseService — all Firestore listeners as clean Dart Stream<> objects.
///
/// Flutter widgets just wrap these in StreamBuilder<> and Firebase pushes
/// changes automatically — no polling, no setState, no refresh button.
///
/// SETUP:
///   1. flutter pub add firebase_core cloud_firestore firebase_messaging
///   2. flutterfire configure   (links your Firebase project)
///   3. call FirebaseService.init() in main() before runApp()
///
/// Firestore collections used:
///   disruptions/          — live disruption events from the poller
///   realtime_status/      — last poll time, active disruption count
///   processed_hashes/     — dedup store (backend only, not used here)

class DisruptionEvent {
  final String id;
  final String headline;
  final String source;
  final String type;
  final String? location;
  final double severity;
  final String affectedMode;
  final double confidence;
  final double cascadeProbability;
  final int shipmentsAtRisk;
  final List<String> affectedHubs;
  final double estimatedDelayHours;
  final int reroutesAvailable;
  final String status;
  final DateTime? createdAt;
  final bool isRealtime;

  const DisruptionEvent({
    required this.id,
    required this.headline,
    required this.source,
    required this.type,
    this.location,
    required this.severity,
    required this.affectedMode,
    required this.confidence,
    required this.cascadeProbability,
    required this.shipmentsAtRisk,
    required this.affectedHubs,
    required this.estimatedDelayHours,
    required this.reroutesAvailable,
    required this.status,
    this.createdAt,
    required this.isRealtime,
  });

  factory DisruptionEvent.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return DisruptionEvent(
      id: doc.id,
      headline: d['headline'] ?? '',
      source: d['source'] ?? 'Unknown',
      type: d['type'] ?? 'other',
      location: d['location'],
      severity: (d['severity'] ?? 0.5).toDouble(),
      affectedMode: d['affected_mode'] ?? 'unknown',
      confidence: (d['confidence'] ?? 0.7).toDouble(),
      cascadeProbability: (d['cascade_probability'] ?? 0.0).toDouble(),
      shipmentsAtRisk: d['shipments_at_risk'] ?? 0,
      affectedHubs: List<String>.from(d['affected_hubs'] ?? []),
      estimatedDelayHours: (d['estimated_delay_hours'] ?? 0.0).toDouble(),
      reroutesAvailable: d['reroutes_available'] ?? 0,
      status: d['status'] ?? 'active',
      createdAt: (d['created_at'] as Timestamp?)?.toDate(),
      isRealtime: d['is_realtime'] ?? false,
    );
  }

  /// Human-readable severity label
  String get severityLabel {
    if (severity >= 0.8) return 'CRITICAL';
    if (severity >= 0.6) return 'HIGH';
    if (severity >= 0.4) return 'MEDIUM';
    return 'LOW';
  }

  /// Color code for severity (as hex int — use Color(event.severityColor))
  int get severityColor {
    if (severity >= 0.8) return 0xFFFF3B30; // red
    if (severity >= 0.6) return 0xFFFF9500; // orange
    if (severity >= 0.4) return 0xFFFFCC00; // yellow
    return 0xFF34C759;                       // green
  }

  /// Icon name for disruption type
  String get typeIcon {
    switch (type) {
      case 'storm': return '🌀';
      case 'strike': return '✊';
      case 'accident': return '💥';
      case 'closure': return '🚫';
      case 'conflict': return '⚔️';
      default: return '⚠️';
    }
  }
}

class RealtimeStatus {
  final DateTime? lastUpdated;
  final String? lastHeadline;
  final double lastSeverity;
  final int activeDisruptions;

  const RealtimeStatus({
    this.lastUpdated,
    this.lastHeadline,
    required this.lastSeverity,
    required this.activeDisruptions,
  });

  factory RealtimeStatus.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return RealtimeStatus(
      lastUpdated: (d['last_updated'] as Timestamp?)?.toDate(),
      lastHeadline: d['last_headline'],
      lastSeverity: (d['last_severity'] ?? 0.0).toDouble(),
      activeDisruptions: d['active_disruptions'] ?? 0,
    );
  }
}

class FirebaseService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Live disruption feed ─────────────────────────────────────────────────────

  /// Stream of ALL active disruptions, ordered by severity (highest first).
  /// Use in StreamBuilder on the ops dashboard.
  static Stream<List<DisruptionEvent>> liveDisruptions({
    double severityMin = 0.0,
    int limit = 50,
  }) {
    return _db
        .collection('disruptions')
        .where('status', isEqualTo: 'active')
        .where('severity', isGreaterThanOrEqualTo: severityMin)
        .orderBy('severity', descending: true)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => DisruptionEvent.fromFirestore(doc))
            .toList());
  }

  /// Stream of disruptions affecting a specific shipment ID.
  /// Use in the customer view to show shipment-specific alerts.
  static Stream<List<DisruptionEvent>> disruptionsForShipment(String shipmentId) {
    // In a real system you'd query by shipmentId in a subcollection.
    // For now we return all active disruptions — filter on client side.
    return liveDisruptions().map((events) =>
        events.where((e) => e.shipmentsAtRisk > 0).toList());
  }

  /// Stream of critical disruptions only (severity >= 0.7).
  /// Used by the driver app to show urgent rerouting alerts.
  static Stream<List<DisruptionEvent>> criticalDisruptions() {
    return liveDisruptions(severityMin: 0.7);
  }

  // ── Realtime status (for header status bar) ──────────────────────────────────

  /// Stream of the latest poller status.
  /// Shows "Last updated 2 min ago — 3 active disruptions" in the app header.
  static Stream<RealtimeStatus> realtimeStatus() {
    return _db
        .collection('realtime_status')
        .doc('latest')
        .snapshots()
        .map((doc) => doc.exists
            ? RealtimeStatus.fromFirestore(doc)
            : const RealtimeStatus(lastSeverity: 0, activeDisruptions: 0));
  }

  // ── Single disruption ────────────────────────────────────────────────────────

  /// Stream a single disruption by ID (for a detail page).
  static Stream<DisruptionEvent?> disruption(String id) {
    return _db
        .collection('disruptions')
        .doc(id)
        .snapshots()
        .map((doc) => doc.exists ? DisruptionEvent.fromFirestore(doc) : null);
  }

  /// Stream the alternative routes for a specific disruption.
  static Stream<List<Map<String, dynamic>>> routesFor(String disruptionId) {
    return _db
        .collection('disruptions')
        .doc(disruptionId)
        .collection('routes')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => doc.data())
            .toList());
  }

  // ── One-time reads ────────────────────────────────────────────────────────────

  /// Get all disruptions once (for initial load or export).
  static Future<List<DisruptionEvent>> getDisruptionsOnce({int limit = 20}) async {
    final snap = await _db
        .collection('disruptions')
        .where('status', isEqualTo: 'active')
        .orderBy('severity', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((doc) => DisruptionEvent.fromFirestore(doc)).toList();
  }

  // ── Write ─────────────────────────────────────────────────────────────────────

  /// Acknowledge a disruption (ops team marks it as reviewed).
  static Future<void> acknowledgeDisruption(String id) {
    return _db.collection('disruptions').doc(id).update({
      'status': 'acknowledged',
      'acknowledged_at': FieldValue.serverTimestamp(),
    });
  }

  /// Resolve a disruption (ops team marks it as resolved).
  static Future<void> resolveDisruption(String id) {
    return _db.collection('disruptions').doc(id).update({
      'status': 'resolved',
      'resolved_at': FieldValue.serverTimestamp(),
    });
  }
}
