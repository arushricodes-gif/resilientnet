/// The disruption library.
///
/// Each [DisruptionScenario] describes a complete event from all three
/// perspectives (Ops, Driver, Customer). When the user picks a disruption
/// in the Ops tab, the same event flows to Driver and Customer views with
/// persona-appropriate framing.
///
/// 12 scenarios covering the main supply chain disruption categories.

enum DisruptionType { storm, strike, closure, accident, fire, fuel, customs, conflict, mechanical, flood }

enum BackendEngine { gnn, handcrafted }

class DisruptionScenario {
  /// Stable ID — used as state key, never change after release
  final String id;

  /// Short user-facing label for buttons
  final String shortLabel;

  /// The disruption type (cyclone, strike, etc)
  final DisruptionType type;

  /// Which backend engine to call. The GNN only knows South-India hubs;
  /// hand-crafted handles international + north India.
  final BackendEngine engine;

  /// Hub identifier passed to the backend.
  /// For [BackendEngine.handcrafted]: HUB-XX format (e.g. "HUB-00")
  /// For [BackendEngine.gnn]: full hub name (e.g. "Kochi Port")
  final String hubId;

  /// Severity 0-1 sent to backend
  final double severity;

  /// News-style headline (looks like it came from a real source)
  final String newsHeadline;

  /// Where in the world this is happening (for map labels, customer notifications)
  final String location;

  /// "Cyclone — Mumbai Port" — what shows on Ops alert bar
  String get opsLabel => '${_typeLabel()} — $location';

  /// What the affected driver sees (single shipment perspective)
  final DriverImpact driverImpact;

  /// What the affected customer sees (single shipment perspective)
  final CustomerImpact customerImpact;

  /// Optional context for the disruption injector tile
  final String tagline;

  const DisruptionScenario({
    required this.id,
    required this.shortLabel,
    required this.type,
    required this.engine,
    required this.hubId,
    required this.severity,
    required this.newsHeadline,
    required this.location,
    required this.driverImpact,
    required this.customerImpact,
    required this.tagline,
  });

  String _typeLabel() {
    switch (type) {
      case DisruptionType.storm: return 'Cyclone';
      case DisruptionType.strike: return 'Strike';
      case DisruptionType.closure: return 'Closure';
      case DisruptionType.accident: return 'Accident';
      case DisruptionType.fire: return 'Fire';
      case DisruptionType.fuel: return 'Fuel shortage';
      case DisruptionType.customs: return 'Customs delay';
      case DisruptionType.conflict: return 'Conflict';
      case DisruptionType.mechanical: return 'Equipment failure';
      case DisruptionType.flood: return 'Flooding';
    }
  }
}

/// Driver-side view of the disruption — shows on the Driver tab when active.
class DriverImpact {
  /// Banner text in driver app
  final String alertHeadline;

  /// Detail line under banner
  final String alertDetail;

  /// Original route description
  final String originalRouteLabel;
  final String originalRouteEta;
  final int originalRouteRiskPercent;
  final String originalRouteIssue;

  /// Proposed alternative route
  final String newRouteLabel;
  final String newRouteEta;
  final int newRouteRiskPercent;
  final String newRouteIssue;

  /// Vehicle/cargo context in this scenario (if you want to vary it)
  final String shipmentContext;

  const DriverImpact({
    required this.alertHeadline,
    required this.alertDetail,
    required this.originalRouteLabel,
    required this.originalRouteEta,
    required this.originalRouteRiskPercent,
    required this.originalRouteIssue,
    required this.newRouteLabel,
    required this.newRouteEta,
    required this.newRouteRiskPercent,
    required this.newRouteIssue,
    this.shipmentContext = 'Active shipment on this route',
  });
}

/// Customer-side view of the disruption — shows on Customer tab when active.
class CustomerImpact {
  /// Headline of the proactive notification
  final String notificationHeadline;

  /// Body text — explains the disruption and what we're doing
  final String notificationBody;

  /// Cargo description for the order header
  final String cargoDescription;

  /// Receiving entity (hospital, factory, etc.)
  final String customerName;

  /// Updated arrival display (usually unchanged, that's the value prop)
  final String arrivalDisplay;

  /// Status footer text
  final String trustFooter;

  const CustomerImpact({
    required this.notificationHeadline,
    required this.notificationBody,
    required this.cargoDescription,
    required this.customerName,
    required this.arrivalDisplay,
    required this.trustFooter,
  });
}

// ============================================================
// THE LIBRARY — 12 scenarios
// ============================================================

class DisruptionLibrary {
  static const List<DisruptionScenario> all = [
    // ---- 1. CYCLONE — MUMBAI ----
    DisruptionScenario(
      id: 'cyclone_mumbai',
      shortLabel: 'Cyclone — Mumbai Port',
      tagline: 'Major west coast event',
      type: DisruptionType.storm,
      engine: BackendEngine.handcrafted,
      hubId: 'HUB-00',
      severity: 0.9,
      newsHeadline: 'Cyclone Tauktae regains strength offshore, Mumbai port partial closure imminent',
      location: 'Mumbai Port',
      driverImpact: DriverImpact(
        alertHeadline: 'Reroute recommended',
        alertDetail: 'Cyclone winds reaching Mumbai · road conditions worsening',
        originalRouteLabel: 'Mumbai → Pune (NH-48)',
        originalRouteEta: '2:30 PM',
        originalRouteRiskPercent: 91,
        originalRouteIssue: 'high winds + flooding',
        newRouteLabel: 'via Lonavala detour',
        newRouteEta: '3:15 PM',
        newRouteRiskPercent: 18,
        newRouteIssue: 'inland route, sheltered',
        shipmentContext: 'Pharmaceuticals · 12 cartons',
      ),
      customerImpact: CustomerImpact(
        notificationHeadline: 'Cyclone Tauktae detected · we are rerouting',
        notificationBody: 'Mumbai Port is at risk from incoming cyclone winds. We\'ve switched your shipment to an inland route via Lonavala. Original arrival time preserved within 45 minutes.',
        cargoDescription: 'Medical supplies · 12 cartons',
        customerName: 'Apollo Hospitals · Pune',
        arrivalDisplay: 'Today, 3:15 PM',
        trustFooter: '1 storm event handled · ETA preserved',
      ),
    ),

    // ---- 2. STRIKE — CHENNAI ----
    DisruptionScenario(
      id: 'strike_chennai',
      shortLabel: 'Strike — Chennai',
      tagline: 'Dockworker walkout',
      type: DisruptionType.strike,
      engine: BackendEngine.handcrafted,
      hubId: 'HUB-02',
      severity: 0.6,
      newsHeadline: 'Dockworkers at Chennai port begin 48-hour strike over wage dispute',
      location: 'Chennai Port',
      driverImpact: DriverImpact(
        alertHeadline: 'Destination port closed',
        alertDetail: 'Chennai dockworkers on strike · cannot offload',
        originalRouteLabel: 'Chennai Port (direct)',
        originalRouteEta: '4:00 PM',
        originalRouteRiskPercent: 95,
        originalRouteIssue: 'no offloading possible',
        newRouteLabel: 'redirect to Vizag Port',
        newRouteEta: '11:30 PM (next day)',
        newRouteRiskPercent: 22,
        newRouteIssue: 'longer route, port operational',
        shipmentContext: 'Containerised auto parts',
      ),
      customerImpact: CustomerImpact(
        notificationHeadline: 'Strike at Chennai · routing via Vizag',
        notificationBody: 'A 48-hour dockworker strike has paused operations at Chennai Port. Your shipment is being redirected to Vizag Port and will arrive via overland route.',
        cargoDescription: 'Auto parts · 200 containers',
        customerName: 'Tata Motors · Hosur',
        arrivalDisplay: 'Tomorrow, 11:30 PM',
        trustFooter: '+18 hours due to labour action · still SLA-compliant',
      ),
    ),

    // ---- 3. RED SEA / JEBEL ALI CONFLICT ----
    DisruptionScenario(
      id: 'closure_redsea',
      shortLabel: 'Closure — Red Sea',
      tagline: 'Houthi attack',
      type: DisruptionType.conflict,
      engine: BackendEngine.handcrafted,
      hubId: 'HUB-10',
      severity: 0.95,
      newsHeadline: 'Red Sea shipping halted after fresh Houthi drone strike near Bab-el-Mandeb',
      location: 'Jebel Ali / Red Sea',
      driverImpact: DriverImpact(
        alertHeadline: 'Sea route compromised',
        alertDetail: 'Red Sea unsafe · vessel insurance void in conflict zone',
        originalRouteLabel: 'Mumbai → Suez → Rotterdam',
        originalRouteEta: '14 days',
        originalRouteRiskPercent: 97,
        originalRouteIssue: 'active conflict zone',
        newRouteLabel: 'Cape of Good Hope route',
        newRouteEta: '21 days',
        newRouteRiskPercent: 12,
        newRouteIssue: 'longer but secure',
        shipmentContext: 'Insulin shipment · 50 tonnes',
      ),
      customerImpact: CustomerImpact(
        notificationHeadline: 'Red Sea route protected · using Cape route',
        notificationBody: 'Due to ongoing security concerns in the Red Sea, your shipment is being routed around the Cape of Good Hope. Critical medical cargo will be air-freighted on the final leg to maintain your delivery window.',
        cargoDescription: 'Insulin vials · 50 tonnes',
        customerName: 'Rotterdam Medical Distribution',
        arrivalDisplay: 'Feb 12, 6:00 PM',
        trustFooter: '+7 days at sea · final mile via air to recover ETA',
      ),
    ),

    // ---- 4. CYCLONE — KOCHI (GNN) ----
    DisruptionScenario(
      id: 'cyclone_kochi',
      shortLabel: 'Cyclone — Kochi',
      tagline: 'Kerala coast event',
      type: DisruptionType.storm,
      engine: BackendEngine.gnn,
      hubId: 'Kochi Port',
      severity: 0.9,
      newsHeadline: 'Cyclonic storm Maha makes landfall near Kochi · ports shut',
      location: 'Kochi Port',
      driverImpact: DriverImpact(
        alertHeadline: 'Coastal route flooded',
        alertDetail: 'Cyclone Maha bringing heavy rain · NH-66 partially submerged',
        originalRouteLabel: 'Kochi → Kozhikode (NH-66)',
        originalRouteEta: '5:45 PM',
        originalRouteRiskPercent: 88,
        originalRouteIssue: 'water on roads',
        newRouteLabel: 'inland via Coimbatore',
        newRouteEta: '7:20 PM',
        newRouteRiskPercent: 15,
        newRouteIssue: 'longer but dry',
        shipmentContext: 'Spices export · 80 crates',
      ),
      customerImpact: CustomerImpact(
        notificationHeadline: 'Cyclone in Kochi · using inland corridor',
        notificationBody: 'Cyclone Maha is making landfall near Kochi. Your shipment is being routed inland through Coimbatore to avoid coastal flooding. Slight delay expected.',
        cargoDescription: 'Spice export consignment',
        customerName: 'McCormick · Bengaluru',
        arrivalDisplay: 'Today, 7:20 PM',
        trustFooter: '+1.5 hours due to inland detour',
      ),
    ),

    // ---- 5. STRIKE — CHENNAI VIA GNN ----
    DisruptionScenario(
      id: 'strike_chennai_gnn',
      shortLabel: 'Strike — Chennai (ML)',
      tagline: 'Same as above, ML engine',
      type: DisruptionType.strike,
      engine: BackendEngine.gnn,
      hubId: 'Chennai Port',
      severity: 0.7,
      newsHeadline: 'Port workers across Tamil Nadu join Chennai strike, second day',
      location: 'Chennai Port (GNN)',
      driverImpact: DriverImpact(
        alertHeadline: 'Strike spreading across TN',
        alertDetail: 'GNN model detects cascade across Tamil Nadu coast',
        originalRouteLabel: 'Chennai Port direct',
        originalRouteEta: '6:00 PM',
        originalRouteRiskPercent: 93,
        originalRouteIssue: 'strike active',
        newRouteLabel: 'reroute via Tirupati Depot',
        newRouteEta: '9:30 PM',
        newRouteRiskPercent: 25,
        newRouteIssue: 'unaffected hub',
        shipmentContext: 'Electronics consignment',
      ),
      customerImpact: CustomerImpact(
        notificationHeadline: 'Strike spreading · ML routed through Tirupati',
        notificationBody: 'Our ML model has detected the strike is spreading across Tamil Nadu ports. Your shipment is being redirected to Tirupati Depot for last-mile delivery.',
        cargoDescription: 'Electronics · 25 crates',
        customerName: 'Reliance Digital · Chennai',
        arrivalDisplay: 'Tonight, 9:30 PM',
        trustFooter: 'ML cascade prediction · 0.033 MAE',
      ),
    ),

    // ---- 6. NH-48 ACCIDENT ----
    DisruptionScenario(
      id: 'accident_nh48',
      shortLabel: 'Accident — NH-48',
      tagline: 'Highway closed',
      type: DisruptionType.accident,
      engine: BackendEngine.handcrafted,
      hubId: 'HUB-05',
      severity: 0.5,
      newsHeadline: 'Multi-vehicle pileup blocks NH-48 between Bengaluru and Chennai',
      location: 'NH-48 corridor',
      driverImpact: DriverImpact(
        alertHeadline: 'Highway blocked ahead',
        alertDetail: 'NH-48 multi-vehicle accident at km 142 · 6 hr delay expected',
        originalRouteLabel: 'NH-48 direct',
        originalRouteEta: '4:30 PM',
        originalRouteRiskPercent: 87,
        originalRouteIssue: 'blocked highway',
        newRouteLabel: 'via NH-44 + state highways',
        newRouteEta: '5:55 PM',
        newRouteRiskPercent: 14,
        newRouteIssue: 'clear roads',
        shipmentContext: 'Mixed retail goods',
      ),
      customerImpact: CustomerImpact(
        notificationHeadline: 'Highway accident · alternate route in use',
        notificationBody: 'A multi-vehicle accident has closed NH-48 ahead of your delivery vehicle. We\'ve rerouted via NH-44 with minimal delay.',
        cargoDescription: 'Retail goods · 12 cartons',
        customerName: 'Big Bazaar · Chennai',
        arrivalDisplay: 'Today, 5:55 PM',
        trustFooter: '+25 min due to detour · still on time',
      ),
    ),

    // ---- 7. FUEL SHORTAGE — DELHI ----
    DisruptionScenario(
      id: 'fuel_delhi',
      shortLabel: 'Fuel shortage — Delhi',
      tagline: 'Trucking impacted',
      type: DisruptionType.fuel,
      engine: BackendEngine.handcrafted,
      hubId: 'HUB-04',
      severity: 0.55,
      newsHeadline: 'Diesel shortage in Delhi NCR delays freight movement, oil cos confirm low stocks',
      location: 'Delhi ICD',
      driverImpact: DriverImpact(
        alertHeadline: 'Fuel reserves critical',
        alertDetail: 'Delhi region fuel shortage · book reserve at next stop',
        originalRouteLabel: 'Delhi → Mumbai direct',
        originalRouteEta: '2 days',
        originalRouteRiskPercent: 78,
        originalRouteIssue: 'no fuel availability',
        newRouteLabel: 'rail handoff at Jaipur',
        newRouteEta: '2.5 days',
        newRouteRiskPercent: 19,
        newRouteIssue: 'rail unaffected',
        shipmentContext: 'FMCG distribution truck',
      ),
      customerImpact: CustomerImpact(
        notificationHeadline: 'Delhi fuel shortage · switching to rail',
        notificationBody: 'A regional fuel shortage is affecting trucking in Delhi NCR. Your consignment is being moved to rail freight at Jaipur for the long haul. Adds half a day.',
        cargoDescription: 'FMCG mixed pallets',
        customerName: 'D-Mart Distribution · Mumbai',
        arrivalDisplay: 'Day after tomorrow, evening',
        trustFooter: 'Mode shift to rail · +12 hours',
      ),
    ),

    // ---- 8. WAREHOUSE FIRE — BENGALURU ----
    DisruptionScenario(
      id: 'fire_bengaluru',
      shortLabel: 'Fire — Bengaluru DC',
      tagline: 'Warehouse incident',
      type: DisruptionType.fire,
      engine: BackendEngine.handcrafted,
      hubId: 'HUB-05',
      severity: 0.7,
      newsHeadline: 'Bengaluru distribution centre evacuated after electrical fire, no casualties',
      location: 'Bengaluru DC',
      driverImpact: DriverImpact(
        alertHeadline: 'Origin DC evacuated',
        alertDetail: 'Bengaluru DC closed for fire safety inspection',
        originalRouteLabel: 'Pickup at Bengaluru DC',
        originalRouteEta: 'tomorrow 9 AM',
        originalRouteRiskPercent: 96,
        originalRouteIssue: 'building closed',
        newRouteLabel: 'pickup from Hosur backup',
        newRouteEta: 'tomorrow 1 PM',
        newRouteRiskPercent: 16,
        newRouteIssue: 'satellite warehouse',
        shipmentContext: 'Outbound parcels (mixed)',
      ),
      customerImpact: CustomerImpact(
        notificationHeadline: 'Origin DC affected · using satellite warehouse',
        notificationBody: 'A fire incident at our Bengaluru distribution centre has temporarily paused outbound shipments. Your order is being fulfilled from our Hosur backup warehouse.',
        cargoDescription: 'Online order · 1 parcel',
        customerName: 'Customer · Mumbai',
        arrivalDisplay: 'Day after tomorrow',
        trustFooter: '+4 hours due to alternate origin',
      ),
    ),

    // ---- 9. CUSTOMS DELAY — ROTTERDAM ----
    DisruptionScenario(
      id: 'customs_rotterdam',
      shortLabel: 'Customs — Rotterdam',
      tagline: 'Inspection backlog',
      type: DisruptionType.customs,
      engine: BackendEngine.handcrafted,
      hubId: 'HUB-11',
      severity: 0.4,
      newsHeadline: 'Rotterdam customs inspections doubled following EU directive · 48hr backlog',
      location: 'Rotterdam Port',
      driverImpact: DriverImpact(
        alertHeadline: 'Customs queue extended',
        alertDetail: 'Rotterdam doing 100% physical inspections · 48hr queue',
        originalRouteLabel: 'Rotterdam direct entry',
        originalRouteEta: '10 days',
        originalRouteRiskPercent: 65,
        originalRouteIssue: 'customs queue',
        newRouteLabel: 'via Antwerp (preclearance)',
        newRouteEta: '10.5 days',
        newRouteRiskPercent: 21,
        newRouteIssue: 'faster clearance',
        shipmentContext: 'Auto parts container',
      ),
      customerImpact: CustomerImpact(
        notificationHeadline: 'Customs backlog · routing via Antwerp',
        notificationBody: 'EU has mandated full inspections at Rotterdam, creating a 48-hour backlog. We\'re routing your shipment through Antwerp where preclearance is faster.',
        cargoDescription: 'Industrial equipment',
        customerName: 'BMW Manufacturing · Munich',
        arrivalDisplay: 'In 10 days',
        trustFooter: '+12 hours via alternate port',
      ),
    ),

    // ---- 10. SINGAPORE CRANE BREAKDOWN ----
    DisruptionScenario(
      id: 'crane_singapore',
      shortLabel: 'Crane fail — Singapore',
      tagline: 'Container handling halt',
      type: DisruptionType.mechanical,
      engine: BackendEngine.handcrafted,
      hubId: 'HUB-09',
      severity: 0.45,
      newsHeadline: 'Singapore PSA terminal hit by crane breakdown · partial congestion',
      location: 'Singapore',
      driverImpact: DriverImpact(
        alertHeadline: 'Transshipment hub congested',
        alertDetail: 'Singapore PSA running at 60% capacity · expect delay',
        originalRouteLabel: 'transship at Singapore',
        originalRouteEta: '6 days',
        originalRouteRiskPercent: 72,
        originalRouteIssue: '60% port capacity',
        newRouteLabel: 'transship at Port Klang instead',
        newRouteEta: '6.5 days',
        newRouteRiskPercent: 24,
        newRouteIssue: 'unaffected hub',
        shipmentContext: 'Multi-customer LCL container',
      ),
      customerImpact: CustomerImpact(
        notificationHeadline: 'Singapore congestion · transship via Port Klang',
        notificationBody: 'A crane breakdown at Singapore PSA is causing port congestion. We\'re re-routing your shipment\'s transshipment to Port Klang instead.',
        cargoDescription: 'LCL consignment · 2 pallets',
        customerName: 'Importer · Sydney',
        arrivalDisplay: 'In 6.5 days',
        trustFooter: '+12 hours · alternative transshipment',
      ),
    ),

    // ---- 11. MONSOON FLOODING ----
    DisruptionScenario(
      id: 'flood_monsoon',
      shortLabel: 'Flooding — NH-48',
      tagline: 'Heavy monsoon',
      type: DisruptionType.flood,
      engine: BackendEngine.handcrafted,
      hubId: 'HUB-05',
      severity: 0.6,
      newsHeadline: 'Heavy monsoon flooding submerges NH-48 between Bengaluru and Chennai',
      location: 'NH-48 corridor',
      driverImpact: DriverImpact(
        alertHeadline: 'Highway under water',
        alertDetail: 'Flash flooding on NH-48 · road impassable for 6+ hours',
        originalRouteLabel: 'NH-48 standard',
        originalRouteEta: 'today 5 PM',
        originalRouteRiskPercent: 92,
        originalRouteIssue: 'water level rising',
        newRouteLabel: 'inland via Hosur',
        newRouteEta: 'today 7:30 PM',
        newRouteRiskPercent: 17,
        newRouteIssue: 'higher elevation route',
        shipmentContext: 'Time-sensitive consumer goods',
      ),
      customerImpact: CustomerImpact(
        notificationHeadline: 'Monsoon flooding · alternate elevated route',
        notificationBody: 'Heavy monsoon rains have flooded NH-48. Your shipment has been rerouted via the higher-elevation Hosur road. Brief delay.',
        cargoDescription: 'Consumer electronics',
        customerName: 'Croma · Chennai',
        arrivalDisplay: 'Today, 7:30 PM',
        trustFooter: '+2.5 hours · weather-protected route',
      ),
    ),

    // ---- 12. SUEZ CANAL CONGESTION ----
    DisruptionScenario(
      id: 'suez_grounding',
      shortLabel: 'Grounding — Suez',
      tagline: 'Vessel blocking',
      type: DisruptionType.closure,
      engine: BackendEngine.handcrafted,
      hubId: 'HUB-10',
      severity: 0.85,
      newsHeadline: 'Suez Canal traffic slows after grounded vessel reported near km 151',
      location: 'Suez Canal',
      driverImpact: DriverImpact(
        alertHeadline: 'Suez transit halted',
        alertDetail: 'Vessel grounded at km 151 · global shipping queue building',
        originalRouteLabel: 'Suez Canal transit',
        originalRouteEta: '12 days',
        originalRouteRiskPercent: 89,
        originalRouteIssue: 'channel blocked',
        newRouteLabel: 'Cape route + air final-mile',
        newRouteEta: '15 days',
        newRouteRiskPercent: 18,
        newRouteIssue: 'longer but moving',
        shipmentContext: 'Container ship · multi-customer',
      ),
      customerImpact: CustomerImpact(
        notificationHeadline: 'Suez blocked · Cape route activated',
        notificationBody: 'A grounded vessel has stopped all Suez Canal traffic. Your shipment is taking the longer Cape of Good Hope route. We\'re using air-freight on the final leg to recover most of the time.',
        cargoDescription: 'Pharmaceutical batch',
        customerName: 'Sanofi · Frankfurt',
        arrivalDisplay: 'In 15 days',
        trustFooter: '+3 days · final-mile air to recover',
      ),
    ),
  ];

  /// Find scenario by ID. Returns null if not found.
  static DisruptionScenario? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Find by news headline match (used by news feed click handler)
  static DisruptionScenario? byHeadlineMatch(String headline) {
    final lower = headline.toLowerCase();
    for (final s in all) {
      if (s.newsHeadline.toLowerCase() == lower) return s;
    }
    // Partial match fallback
    for (final s in all) {
      // pull out a few keywords and see if they're all in the headline
      final keywords = _keywordsFor(s);
      if (keywords.any((k) => lower.contains(k))) return s;
    }
    return null;
  }

  static List<String> _keywordsFor(DisruptionScenario s) {
    switch (s.id) {
      case 'cyclone_mumbai': return ['mumbai', 'tauktae', 'cyclone'];
      case 'cyclone_kochi':  return ['kochi', 'maha', 'kerala'];
      case 'strike_chennai': return ['chennai', 'dockworkers', 'strike'];
      case 'strike_chennai_gnn': return ['tamil nadu', 'second day'];
      case 'closure_redsea': return ['houthi', 'red sea', 'bab-el-mandeb'];
      case 'accident_nh48':  return ['nh-48', 'pileup', 'multi-vehicle'];
      case 'fuel_delhi':     return ['delhi', 'diesel', 'fuel'];
      case 'fire_bengaluru': return ['bengaluru', 'fire', 'electrical'];
      case 'customs_rotterdam': return ['rotterdam', 'customs'];
      case 'crane_singapore': return ['singapore', 'crane', 'psa'];
      case 'flood_monsoon':  return ['monsoon', 'flooding', 'submerges'];
      case 'suez_grounding': return ['suez', 'grounded', 'km 151'];
      default: return [];
    }
  }

  /// All news headlines (for the live news feed)
  static List<String> get allHeadlines => all.map((s) => s.newsHeadline).toList();

  /// Quick-trigger buttons for the disruption injector. Use a curated subset.
  static List<DisruptionScenario> get quickTriggers => [
    all[0], // cyclone Mumbai
    all[2], // Red Sea
    all[1], // Chennai strike
    all[3], // Kochi cyclone (GNN)
    all[5], // NH-48 accident
    all[7], // Bengaluru fire
  ];
}
