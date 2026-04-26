import 'dart:convert';
import 'package:http/http.dart' as http;

/// Talks to the ResilientNet Python backend.
///
/// Backend runs on http://localhost:8080 by default (uvicorn dev server).
/// When deployed to Cloud Run, change baseUrl to the public URL.
///
/// Every method returns typed data and handles errors gracefully —
/// if the backend is unreachable, methods return null or throw a
/// recognisable [BackendException] so the UI can show a friendly state.
class ApiService {
  // For Web/iOS use 127.0.0.1. For Android emulator use 10.0.2.2.
  static const String baseUrl = 'http://127.0.0.1:8080';

  // ============================================================
  // HEALTH CHECK
  // ============================================================

  /// Returns true if the backend is alive. Used by the UI to show
  /// "backend connected" / "backend offline" indicators.
  static Future<bool> ping() async {
    try {
      final r = await http
          .get(Uri.parse('$baseUrl/'))
          .timeout(const Duration(seconds: 3));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // CASCADE PREDICTION (hand-crafted engine)
  // ============================================================

  /// POST /predict_cascade
  /// Uses the hand-crafted cascade engine on the international hub graph.
  ///
  /// [hubId] is one of the HUB-XX IDs (matches Flutter fake_data.dart hubs).
  static Future<CascadeResult> predictCascade({
    required String hubId,
    required double severity,
    String eventType = 'unknown',
  }) async {
    final r = await http.post(
      Uri.parse('$baseUrl/predict_cascade'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'hub_id': hubId,
        'severity': severity,
        'event_type': eventType,
      }),
    );
    if (r.statusCode != 200) {
      throw BackendException('predict_cascade failed (${r.statusCode})', r.body);
    }
    return CascadeResult.fromJson(jsonDecode(r.body));
  }

  // ============================================================
  // CASCADE PREDICTION (trained ST-GCN GNN)
  // ============================================================

  /// POST /predict_cascade_gnn
  /// Uses the trained ST-GCN model on the South India hub graph.
  ///
  /// [hubName] can be 'Kochi Port', 'Chennai Port', 'Bengaluru Warehouse', etc.
  /// Partial matches like 'Kochi' work too.
  static Future<GnnCascadeResult> predictCascadeGnn({
    required String hubName,
    required double severity,
  }) async {
    final r = await http.post(
      Uri.parse('$baseUrl/predict_cascade_gnn'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'hub_id': hubName,
        'severity': severity,
      }),
    );
    if (r.statusCode != 200) {
      throw BackendException('predict_cascade_gnn failed (${r.statusCode})',
          r.body);
    }
    return GnnCascadeResult.fromJson(jsonDecode(r.body));
  }

  // ============================================================
  // NEWS PARSING (Gemini)
  // ============================================================

  /// POST /parse_news
  /// Sends a news headline to Gemini, gets back structured disruption.
  static Future<ParsedDisruption> parseNews(String headline) async {
    final r = await http.post(
      Uri.parse('$baseUrl/parse_news'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'headline': headline}),
    );
    if (r.statusCode != 200) {
      throw BackendException('parse_news failed (${r.statusCode})', r.body);
    }
    return ParsedDisruption.fromJson(jsonDecode(r.body));
  }

  // ============================================================
  // ROUTE OPTIMIZATION
  // ============================================================

  static Future<OptimizeResult> optimizeRoutes({
    required List<String> affectedShipmentIds,
    required List<String> blockedHubIds,
  }) async {
    final r = await http.post(
      Uri.parse('$baseUrl/optimize_routes'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'affected_shipment_ids': affectedShipmentIds,
        'blocked_hub_ids': blockedHubIds,
      }),
    );
    if (r.statusCode != 200) {
      throw BackendException('optimize_routes failed (${r.statusCode})',
          r.body);
    }
    return OptimizeResult.fromJson(jsonDecode(r.body));
  }

  // ============================================================
  // REAL-TIME EVENTS — live news from backend poller
  // ============================================================

  /// GET /realtime/events
  /// Returns the latest disruption events detected by the background poller.
  /// These are REAL headlines from NewsAPI, processed through Gemini + GNN.
  static Future<List<RealtimeEvent>> fetchRealtimeEvents({
    int limit = 20,
  }) async {
    try {
      final r = await http
          .get(Uri.parse('$baseUrl/realtime/events?limit=$limit'))
          .timeout(const Duration(seconds: 5));
      if (r.statusCode != 200) return [];
      final data = jsonDecode(r.body);
      final events = data['events'] as List? ?? [];
      return events.map((e) => RealtimeEvent.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// POST /realtime/simulate
  /// Inject a headline and immediately run the full pipeline.
  /// Returns the processed result including cascade + routes.
  static Future<Map<String, dynamic>?> simulateHeadline(
      String headline, {
      double? severityOverride,
      String? locationOverride,
  }) async {
    try {
      final r = await http.post(
        Uri.parse('$baseUrl/realtime/simulate'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'headline': headline,
          if (severityOverride != null) 'severity_override': severityOverride,
          if (locationOverride != null) 'location_override': locationOverride,
          'write_to_firebase': false,
        }),
      ).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// POST /realtime/poll_now — trigger an immediate poll cycle
  static Future<void> pollNow() async {
    try {
      await http
          .post(Uri.parse('$baseUrl/realtime/poll_now'))
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }
}

// ============================================================
// EXCEPTIONS
// ============================================================

class BackendException implements Exception {
  final String message;
  final String body;
  BackendException(this.message, this.body);
  @override
  String toString() => 'BackendException: $message · $body';
}

// ============================================================
// RESPONSE TYPES — hand-crafted cascade engine
// ============================================================

class CascadeResult {
  final int totalAtRisk;
  final List<AffectedShipment> affectedShipments;
  final List<String> affectedHubs;
  final double confidence;
  final String algorithm;

  CascadeResult({
    required this.totalAtRisk,
    required this.affectedShipments,
    required this.affectedHubs,
    required this.confidence,
    required this.algorithm,
  });

  factory CascadeResult.fromJson(Map<String, dynamic> j) => CascadeResult(
        totalAtRisk: j['total_at_risk'] ?? 0,
        affectedShipments: (j['affected_shipments'] as List? ?? [])
            .map((s) => AffectedShipment.fromJson(s))
            .toList(),
        affectedHubs: List<String>.from(j['affected_hubs'] ?? []),
        confidence: (j['confidence'] ?? 0.0).toDouble(),
        algorithm: j['algorithm'] ?? 'unknown',
      );
}

class AffectedShipment {
  final String shipmentId;
  final double riskScore;
  final int propagationDepth;
  final String reason;

  AffectedShipment({
    required this.shipmentId,
    required this.riskScore,
    required this.propagationDepth,
    required this.reason,
  });

  factory AffectedShipment.fromJson(Map<String, dynamic> j) => AffectedShipment(
        shipmentId: j['shipment_id'] ?? '',
        riskScore: (j['risk_score'] ?? 0.0).toDouble(),
        propagationDepth: j['propagation_depth'] ?? 0,
        reason: j['reason'] ?? '',
      );
}

// ============================================================
// RESPONSE TYPES — GNN cascade engine
// ============================================================

class GnnCascadeResult {
  final List<GnnAffectedNode> affectedNodes;
  final String disruptionSourceName;
  final double severity;
  final int totalAtRisk;
  final String algorithm;
  final double modelValMae;

  GnnCascadeResult({
    required this.affectedNodes,
    required this.disruptionSourceName,
    required this.severity,
    required this.totalAtRisk,
    required this.algorithm,
    required this.modelValMae,
  });

  factory GnnCascadeResult.fromJson(Map<String, dynamic> j) {
    final src = j['disruption_source'] ?? {};
    return GnnCascadeResult(
      affectedNodes: (j['affected_nodes'] as List? ?? [])
          .map((n) => GnnAffectedNode.fromJson(n))
          .toList(),
      disruptionSourceName: src['name'] ?? '',
      severity: (src['severity'] ?? 0.0).toDouble(),
      totalAtRisk: j['total_at_risk'] ?? 0,
      algorithm: j['algorithm'] ?? 'unknown',
      modelValMae: (j['model_val_mae'] ?? 0.0).toDouble(),
    );
  }
}

class GnnAffectedNode {
  final int nodeId;
  final String name;
  final String state;
  final double predictedDelay;
  final int distanceHops;
  final String nodeType;

  GnnAffectedNode({
    required this.nodeId,
    required this.name,
    required this.state,
    required this.predictedDelay,
    required this.distanceHops,
    required this.nodeType,
  });

  factory GnnAffectedNode.fromJson(Map<String, dynamic> j) => GnnAffectedNode(
        nodeId: j['node_id'] ?? 0,
        name: j['name'] ?? '',
        state: j['state'] ?? '',
        predictedDelay: (j['predicted_delay'] ?? 0.0).toDouble(),
        distanceHops: j['distance_hops'] ?? 0,
        nodeType: j['node_type'] ?? 'unknown',
      );
}

// ============================================================
// RESPONSE TYPES — News parser (Gemini)
// ============================================================

class ParsedDisruption {
  final String type;
  final String? location;
  final double severity;
  final String affectedMode;
  final double confidence;

  ParsedDisruption({
    required this.type,
    this.location,
    required this.severity,
    required this.affectedMode,
    required this.confidence,
  });

  factory ParsedDisruption.fromJson(Map<String, dynamic> j) => ParsedDisruption(
        type: j['type'] ?? 'unknown',
        location: j['location'],
        severity: (j['severity'] ?? 0.0).toDouble(),
        affectedMode: j['affected_mode'] ?? 'unknown',
        confidence: (j['confidence'] ?? 0.0).toDouble(),
      );
}

// ============================================================
// RESPONSE TYPES — Route optimizer
// ============================================================

class OptimizeResult {
  final List<Reroute> reroutes;
  final int count;
  final int totalSavingsInr;

  OptimizeResult({
    required this.reroutes,
    required this.count,
    required this.totalSavingsInr,
  });

  factory OptimizeResult.fromJson(Map<String, dynamic> j) => OptimizeResult(
        reroutes: (j['reroutes'] as List? ?? [])
            .map((r) => Reroute.fromJson(r))
            .toList(),
        count: j['count'] ?? 0,
        totalSavingsInr: j['total_savings_inr'] ?? 0,
      );
}

class Reroute {
  final String shipmentId;
  final List<String> originalRoute;
  final List<String> newRoute;
  final double addedDistanceKm;
  final double addedHours;
  final int savingsInr;
  final String reason;

  Reroute({
    required this.shipmentId,
    required this.originalRoute,
    required this.newRoute,
    required this.addedDistanceKm,
    required this.addedHours,
    required this.savingsInr,
    required this.reason,
  });

  factory Reroute.fromJson(Map<String, dynamic> j) => Reroute(
        shipmentId: j['shipment_id'] ?? '',
        originalRoute: List<String>.from(j['original_route'] ?? []),
        newRoute: List<String>.from(j['new_route'] ?? []),
        addedDistanceKm: (j['added_distance_km'] ?? 0.0).toDouble(),
        addedHours: (j['added_hours'] ?? 0.0).toDouble(),
        savingsInr: j['savings_inr'] ?? 0,
        reason: j['reason'] ?? '',
      );
}


// ============================================================
// REALTIME EVENT — from /realtime/events
// ============================================================

class RealtimeEvent {
  final String id;
  final String headline;
  final String source;
  final String type;
  final String? location;
  final double severity;
  final int shipmentsAtRisk;
  final int reroutesAvailable;
  final double estimatedDelayHours;
  final bool isRealtime;

  const RealtimeEvent({
    required this.id,
    required this.headline,
    required this.source,
    required this.type,
    this.location,
    required this.severity,
    required this.shipmentsAtRisk,
    required this.reroutesAvailable,
    required this.estimatedDelayHours,
    required this.isRealtime,
  });

  factory RealtimeEvent.fromJson(Map<String, dynamic> j) => RealtimeEvent(
        id: j["id"] ?? j["event_id"] ?? "",
        headline: j["headline"] ?? j["gemini"]?["headline"] ?? "",
        source: j["source"] ?? j["gemini"]?["source"] ?? "NewsAPI",
        type: j["type"] ?? j["gemini"]?["type"] ?? "other",
        location: j["location"] ?? j["gemini"]?["location"],
        severity: (j["severity"] ?? j["gemini"]?["severity"] ?? 0.5).toDouble(),
        shipmentsAtRisk: j["shipments_at_risk"] ?? 0,
        reroutesAvailable: j["reroutes_available"] ?? 0,
        estimatedDelayHours:
            (j["estimated_delay_hours"] ?? 0.0).toDouble(),
        isRealtime: j["is_realtime"] ?? true,
      );

  String get severityLabel {
    if (severity >= 0.8) return "CRITICAL";
    if (severity >= 0.6) return "HIGH";
    if (severity >= 0.4) return "MEDIUM";
    return "LOW";
  }

  String get typeIcon {
    switch (type) {
      case "storm": return "🌀";
      case "strike": return "✊";
      case "accident": return "💥";
      case "closure": return "🚫";
      case "conflict": return "⚔️";
      default: return "⚠️";
    }
  }
}
