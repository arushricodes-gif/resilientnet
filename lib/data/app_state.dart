import 'package:flutter/foundation.dart';
import 'disruption_library.dart';
import '../services/api_service.dart';

/// Single source of truth for the active disruption.
///
/// All three tabs (Ops, Driver, Customer) listen to this. When the user
/// triggers a disruption in Ops, this state updates and the other tabs
/// rebuild automatically via [ListenableBuilder].
///
/// The actual backend call also lives here so the result is shared.
class AppState extends ChangeNotifier {
  // ============================================================
  // Singleton — kept simple, no DI framework needed for hackathon
  // ============================================================
  AppState._();
  static final AppState instance = AppState._();

  // ============================================================
  // STATE
  // ============================================================

  /// The currently active disruption, or null if none.
  DisruptionScenario? _activeDisruption;
  DisruptionScenario? get activeDisruption => _activeDisruption;

  /// Has a disruption been triggered?
  bool get hasActiveDisruption => _activeDisruption != null;

  /// Number of shipments at risk (from backend response).
  /// Falls back to a reasonable demo number if backend offline.
  int _atRisk = 0;
  int get atRisk => _atRisk;

  /// Confidence score from backend (0-1)
  double? _confidence;
  double? get confidence => _confidence;

  /// Algorithm name returned by backend (e.g. "weighted_graph_propagation_v1" or "stgcn_v2_trained")
  String? _algorithm;
  String? get algorithm => _algorithm;

  /// True if the GNN was used (vs hand-crafted)
  bool get usedGnn => _algorithm?.contains('stgcn') ?? false;

  /// Loading state — backend call in progress
  bool _loading = false;
  bool get loading => _loading;

  /// True if the last backend call failed (UI shows "OFFLINE · DEMO MODE")
  bool _backendOffline = false;
  bool get backendOffline => _backendOffline;

  /// Has the optimizer been run?
  bool _rerouted = false;
  bool get rerouted => _rerouted;

  /// Number of reroutes after optimization
  int _reroutedCount = 12;
  int get reroutedCount => _reroutedCount;

  /// Money saved (display string)
  String _savings = '₹3.2L';
  String get savings => _savings;

  /// Top affected shipment IDs (for the optimizer call)
  List<String> _affectedIds = [];

  /// Driver decision: 'pending' | 'accepted' | 'declined'
  String _driverDecision = 'pending';
  String get driverDecision => _driverDecision;

  // ============================================================
  // WHAT-IF MODE STATE
  // ============================================================

  /// Is what-if mode active?
  bool _whatIfMode = false;
  bool get whatIfMode => _whatIfMode;

  /// Stacked disruptions in what-if mode (ordered by trigger time)
  final List<DisruptionScenario> _stackedScenarios = [];
  List<DisruptionScenario> get stackedScenarios =>
      List.unmodifiable(_stackedScenarios);

  /// Cumulative network stress (0.0 to 1.0) from all stacked disruptions
  double _networkStress = 0.0;
  double get networkStress => _networkStress;

  /// Percentage of shipments delayed without ResilientNet AI
  int get shipmentsDelayedWithoutAi {
    if (_stackedScenarios.isEmpty) return 0;
    // Without AI: every disruption cascades unchecked, every connected
    // shipment delayed. Sum up severity-weighted impact.
    double impact = 0;
    for (final s in _stackedScenarios) {
      impact += s.severity * 35;  // each disruption wrecks 35 * severity % of shipments
    }
    return impact.clamp(0, 95).round();
  }

  /// Percentage of shipments delayed WITH ResilientNet (much smaller)
  int get shipmentsDelayedWithAi {
    if (_stackedScenarios.isEmpty) return 0;
    // With AI: GNN predicts cascade, optimizer reroutes, we save most.
    // Mostly we absorb disruptions. Some still leak through.
    double impact = 0;
    for (final s in _stackedScenarios) {
      impact += s.severity * 6;  // 6 * severity % leak through even with AI
    }
    return impact.clamp(0, 40).round();
  }

  /// Shipments saved by ResilientNet (for the "value" story)
  int get shipmentsSavedByAi =>
      shipmentsDelayedWithoutAi - shipmentsDelayedWithAi;

  /// Estimated value preserved (lakhs) — shipments saved × avg shipment value
  String get valueSavedByAi {
    final lakhs = shipmentsSavedByAi * 0.8;  // ~₹80k per shipment saved
    if (lakhs >= 100) return '₹${(lakhs / 100).toStringAsFixed(1)}Cr';
    return '₹${lakhs.toStringAsFixed(1)}L';
  }

  /// Network status message based on stress
  String get stressLabel {
    if (_networkStress < 0.25) return 'STABLE';
    if (_networkStress < 0.50) return 'STRESSED';
    if (_networkStress < 0.75) return 'CRITICAL';
    return 'BREAKING POINT';
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  /// Trigger a disruption from the library. Calls the appropriate backend
  /// engine (GNN or hand-crafted) and updates state.
  Future<void> triggerDisruption(DisruptionScenario scenario) async {
    _activeDisruption = scenario;
    _loading = true;
    _backendOffline = false;
    _rerouted = false;
    _reroutedCount = 12;
    _savings = '₹3.2L';
    _driverDecision = 'pending';
    notifyListeners();

    try {
      if (scenario.engine == BackendEngine.gnn) {
        final r = await ApiService.predictCascadeGnn(
          hubName: scenario.hubId,
          severity: scenario.severity,
        );
        _atRisk = r.totalAtRisk;
        _confidence = 1.0 - r.modelValMae;  // approximate "confidence" for GNN
        _algorithm = r.algorithm;
        _affectedIds = r.affectedNodes
            .take(20)
            .map((n) => 'NODE-${n.nodeId}')
            .toList();
      } else {
        final r = await ApiService.predictCascade(
          hubId: scenario.hubId,
          severity: scenario.severity,
          eventType: scenario.type.name,
        );
        _atRisk = r.totalAtRisk;
        _confidence = r.confidence;
        _algorithm = r.algorithm;
        _affectedIds = r.affectedShipments
            .take(20)
            .map((s) => s.shipmentId)
            .toList();
      }
      _loading = false;
    } catch (e) {
      // Backend unreachable — graceful degrade with demo numbers
      _atRisk = _demoAtRiskFor(scenario);
      _confidence = 0.85;
      _algorithm = scenario.engine == BackendEngine.gnn
          ? 'stgcn_v2_trained (demo)'
          : 'weighted_graph_propagation_v1 (demo)';
      _backendOffline = true;
      _loading = false;
    }
    notifyListeners();
  }

  /// Run route optimizer on the affected shipments
  Future<void> runOptimizer() async {
    if (_activeDisruption == null) return;
    _loading = true;
    notifyListeners();

    try {
      final r = await ApiService.optimizeRoutes(
        affectedShipmentIds: _affectedIds.isNotEmpty
            ? _affectedIds.where((id) => id.startsWith('SHP')).toList()
            : ['SHP-0042', 'SHP-0118', 'SHP-0203'],
        blockedHubIds: _activeDisruption!.engine == BackendEngine.handcrafted
            ? [_activeDisruption!.hubId]
            : [],  // GNN doesn't use the same hub IDs
      );
      _reroutedCount = 12 + r.count;
      final lakhs = r.totalSavingsInr / 100000;
      _savings = '₹${lakhs.toStringAsFixed(1)}L';
      _rerouted = true;
      _loading = false;
    } catch (e) {
      // Demo fallback
      _reroutedCount = 12 + _demoAtRiskFor(_activeDisruption!);
      _savings = '₹${(7 + _demoAtRiskFor(_activeDisruption!) * 0.4).toStringAsFixed(1)}L';
      _rerouted = true;
      _backendOffline = true;
      _loading = false;
    }
    notifyListeners();
  }

  /// Driver accepts the proposed reroute
  void acceptReroute() {
    _driverDecision = 'accepted';
    notifyListeners();
  }

  /// Driver declines the reroute
  void declineReroute() {
    _driverDecision = 'declined';
    notifyListeners();
  }

  /// Reset everything — back to "no disruption" state
  void reset() {
    _activeDisruption = null;
    _atRisk = 0;
    _confidence = null;
    _algorithm = null;
    _loading = false;
    _backendOffline = false;
    _rerouted = false;
    _reroutedCount = 12;
    _savings = '₹3.2L';
    _affectedIds = [];
    _driverDecision = 'pending';
    _stackedScenarios.clear();
    _networkStress = 0.0;
    notifyListeners();
  }

  // ============================================================
  // WHAT-IF MODE ACTIONS
  // ============================================================

  /// Switch between live and what-if mode. Clears all state.
  void setWhatIfMode(bool enabled) {
    _whatIfMode = enabled;
    _activeDisruption = null;
    _atRisk = 0;
    _confidence = null;
    _algorithm = null;
    _loading = false;
    _backendOffline = false;
    _rerouted = false;
    _reroutedCount = 12;
    _savings = '₹3.2L';
    _affectedIds = [];
    _driverDecision = 'pending';
    _stackedScenarios.clear();
    _networkStress = 0.0;
    notifyListeners();
  }

  /// In what-if mode: add a disruption to the stack (or remove if already there).
  /// In live mode: replace active disruption (via triggerDisruption).
  void stackOrUnstack(DisruptionScenario scenario) {
    final idx = _stackedScenarios.indexWhere((s) => s.id == scenario.id);
    if (idx >= 0) {
      // Already stacked — remove it
      _stackedScenarios.removeAt(idx);
    } else {
      // Add it
      _stackedScenarios.add(scenario);
    }
    _recomputeStress();
    notifyListeners();
  }

  /// Clear all stacked what-if disruptions
  void clearStack() {
    _stackedScenarios.clear();
    _networkStress = 0.0;
    notifyListeners();
  }

  void _recomputeStress() {
    if (_stackedScenarios.isEmpty) {
      _networkStress = 0.0;
      return;
    }
    // Stress is non-linear: first disruption adds a lot, each subsequent
    // adds less (network has some slack, but eventually saturates)
    double stress = 0;
    for (int i = 0; i < _stackedScenarios.length; i++) {
      final s = _stackedScenarios[i];
      final decayFactor = 1.0 / (1.0 + i * 0.3);
      stress += s.severity * 0.22 * decayFactor;
    }
    _networkStress = stress.clamp(0.0, 1.0);
  }

  // ============================================================
  // HELPERS
  // ============================================================

  /// Severity-proportional at-risk count for offline demo mode
  int _demoAtRiskFor(DisruptionScenario s) {
    return (15 + s.severity * 75).round();
  }
}
