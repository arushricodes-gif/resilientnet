/// All demo data in one place.
///
/// When you wire Firebase on Day 3, replace reads from this class
/// with StreamBuilder wrapping FirebaseFirestore.instance.collection(...).
/// The UI doesn't change — only the data source.

class Hub {
  final String id, name, type;
  final double lat, lng;
  final bool disrupted;

  const Hub({
    required this.id, required this.name, required this.type,
    required this.lat, required this.lng, this.disrupted = false,
  });
}

class Shipment {
  final String id, cargo, origin, destination, cargoType;
  final int priority, valueInr;
  final double riskScore;
  final String status;
  final String eta;

  const Shipment({
    required this.id,
    required this.cargo,
    required this.origin,
    required this.destination,
    required this.cargoType,
    required this.priority,
    required this.valueInr,
    required this.riskScore,
    required this.status,
    required this.eta,
  });
}

class TimelineEvent {
  final String title, time;
  final bool done, highlight;

  const TimelineEvent({
    required this.title, required this.time,
    this.done = false, this.highlight = false,
  });
}

class DisruptionEvent {
  final String type, location, time;
  final double severity;
  final int affectedCount;

  const DisruptionEvent({
    required this.type, required this.location, required this.time,
    required this.severity, required this.affectedCount,
  });
}

class FakeData {
  // ============================================================
  // KPIs
  // ============================================================
  static int activeShipments = 200;
  static int atRisk = 0;
  static int reroutedToday = 12;
  static String savingsToday = '₹3.2L';
  static double networkHealth = 0.94;

  // ============================================================
  // HUBS — real Indian + international logistics geography
  // ============================================================
  static const hubs = <Hub>[
    Hub(id: 'HUB-00', name: 'Mumbai Port',    type: 'port',      lat: 18.95, lng: 72.85),
    Hub(id: 'HUB-01', name: 'JNPT',           type: 'port',      lat: 18.95, lng: 72.95),
    Hub(id: 'HUB-02', name: 'Chennai Port',   type: 'port',      lat: 13.09, lng: 80.30),
    Hub(id: 'HUB-03', name: 'Kolkata Port',   type: 'port',      lat: 22.54, lng: 88.33),
    Hub(id: 'HUB-04', name: 'Delhi ICD',      type: 'icd',       lat: 28.61, lng: 77.23),
    Hub(id: 'HUB-05', name: 'Bengaluru DC',   type: 'warehouse', lat: 12.97, lng: 77.59),
    Hub(id: 'HUB-06', name: 'Pune Hub',       type: 'warehouse', lat: 18.52, lng: 73.85),
    Hub(id: 'HUB-07', name: 'Hyderabad DC',   type: 'warehouse', lat: 17.39, lng: 78.49),
    Hub(id: 'HUB-08', name: 'Ahmedabad Hub',  type: 'warehouse', lat: 23.03, lng: 72.58),
    Hub(id: 'HUB-09', name: 'Singapore',      type: 'port',      lat:  1.27, lng: 103.85),
    Hub(id: 'HUB-10', name: 'Jebel Ali',      type: 'port',      lat: 24.98, lng:  55.06),
    Hub(id: 'HUB-11', name: 'Rotterdam',      type: 'port',      lat: 51.95, lng:   4.14),
    Hub(id: 'HUB-12', name: 'Delhi Air',      type: 'airport',   lat: 28.57, lng:  77.10),
    Hub(id: 'HUB-13', name: 'Mumbai Air',     type: 'airport',   lat: 19.09, lng:  72.87),
    Hub(id: 'HUB-14', name: 'Frankfurt Air',  type: 'airport',   lat: 50.04, lng:   8.56),
  ];

  // ============================================================
  // SHIPMENTS — sample of active cargo
  // ============================================================
  static const shipments = <Shipment>[
    Shipment(
      id: 'SHP-0042',
      cargo: '12 cartons · electronics',
      origin: 'Bengaluru DC',
      destination: 'Chennai Port',
      cargoType: 'electronics',
      priority: 3,
      valueInr: 2400000,
      riskScore: 0.82,
      status: 'in_transit',
      eta: '5:55 PM today',
    ),
    Shipment(
      id: 'SHP-0118',
      cargo: '50 tonnes · insulin vials',
      origin: 'Mumbai Port',
      destination: 'Rotterdam',
      cargoType: 'medical',
      priority: 1,
      valueInr: 45000000,
      riskScore: 0.91,
      status: 'rerouted',
      eta: '12 Feb 18:00',
    ),
    Shipment(
      id: 'SHP-0203',
      cargo: '200 containers · auto parts',
      origin: 'Chennai Port',
      destination: 'Frankfurt Air',
      cargoType: 'machinery',
      priority: 2,
      valueInr: 82000000,
      riskScore: 0.67,
      status: 'in_transit',
      eta: '14 Feb 09:30',
    ),
    Shipment(
      id: 'SHP-0455',
      cargo: '30 tonnes · food staples',
      origin: 'JNPT',
      destination: 'Jebel Ali',
      cargoType: 'food',
      priority: 1,
      valueInr: 6500000,
      riskScore: 0.45,
      status: 'in_transit',
      eta: '9 Feb 22:15',
    ),
    Shipment(
      id: 'SHP-0789',
      cargo: '80 crates · textiles',
      origin: 'Ahmedabad Hub',
      destination: 'Singapore',
      cargoType: 'textiles',
      priority: 3,
      valueInr: 1800000,
      riskScore: 0.31,
      status: 'in_transit',
      eta: '11 Feb 14:20',
    ),
    Shipment(
      id: 'SHP-0912',
      cargo: '15 pallets · vaccines',
      origin: 'Delhi Air',
      destination: 'Frankfurt Air',
      cargoType: 'medical',
      priority: 1,
      valueInr: 28000000,
      riskScore: 0.28,
      status: 'in_transit',
      eta: '8 Feb 03:45',
    ),
  ];

  // ============================================================
  // DRIVER DATA
  // ============================================================
  static const driverName = 'Ravi Kumar';
  static const driverVehicle = 'TN-09-AB-4521';
  static const driverShipment = 'SHP-0042';
  static const driverProgress = 0.42;
  static const driverKmDone = 146;
  static const driverKmLeft = 196;

  // Original route (now risky)
  static const originalRoute = {
    'name': 'NH-48 direct',
    'distance': '196 km',
    'eta': '6:20 PM',
    'risk': 87,
    'issue': 'flooding ahead',
  };

  // Proposed reroute
  static const newRoute = {
    'name': 'via Hosur + NH-44',
    'distance': '184 km',
    'eta': '5:55 PM',
    'risk': 12,
    'issue': 'clear weather',
  };

  // ============================================================
  // CUSTOMER DATA
  // ============================================================
  static const customerCompany = 'Apollo Hospitals · Chennai';
  static const customerShipmentId = 'SHP-0042';
  static const customerShipmentDesc = 'Medical equipment · 12 cartons';
  static const customerArrival = 'Today, 5:55 PM';

  // Aliases used by the new customer_view.dart
  static const customerName = customerCompany;
  static const customerOrderId = customerShipmentId;
  static const customerCargo = customerShipmentDesc;

  static const timeline = <TimelineEvent>[
    TimelineEvent(title: 'Picked up · Bengaluru DC',  time: 'Yesterday 9:14 PM', done: true),
    TimelineEvent(title: 'Departed Hosur hub',       time: 'Today 1:32 PM',      done: true),
    TimelineEvent(title: 'Smart reroute applied',    time: 'Today 2:47 PM',      done: true, highlight: true),
    TimelineEvent(title: 'Out for delivery',         time: 'Expected 5:10 PM',   done: false),
    TimelineEvent(title: 'Delivered',                time: 'Expected 5:55 PM',   done: false),
  ];

  // ============================================================
  // DISRUPTION FEED (Ops panel)
  // ============================================================
  static final disruptionFeed = <DisruptionEvent>[
    DisruptionEvent(
      type: 'storm',
      location: 'Mumbai Port area',
      time: '2 min ago',
      severity: 0.82,
      affectedCount: 23,
    ),
    DisruptionEvent(
      type: 'strike',
      location: 'Chennai port union',
      time: '47 min ago',
      severity: 0.55,
      affectedCount: 8,
    ),
    DisruptionEvent(
      type: 'accident',
      location: 'NH-48 km 142',
      time: '1 hr ago',
      severity: 0.38,
      affectedCount: 3,
    ),
  ];

  // ============================================================
  // LIVE NEWS HEADLINES (Ops panel — for Gemini demo)
  // ============================================================
  static const newsHeadlines = [
    'Red Sea shipping halted after fresh Houthi drone strike near Bab-el-Mandeb',
    'Mumbai port partial closure as Cyclone Tauktae regains strength offshore',
    'Dockworkers at Chennai port begin 48-hour strike over wage dispute',
    'Heavy monsoon flooding blocks NH-48 between Bengaluru and Chennai',
    'Suez Canal traffic slows after grounded vessel reported near km 151',
  ];

  // ============================================================
  // AT-RISK SHIPMENTS (surfaces in Ops panel after disruption)
  // ============================================================
  static const atRiskShipments = <Shipment>[
    Shipment(id: 'SHP-0118', cargo: 'insulin vials',     origin: 'Mumbai Port',  destination: 'Rotterdam',  cargoType: 'medical',  priority: 1, valueInr: 45000000, riskScore: 0.91, status: 'at_risk',  eta: '12 Feb'),
    Shipment(id: 'SHP-0042', cargo: 'electronics',        origin: 'Bengaluru DC', destination: 'Chennai',    cargoType: 'electronics', priority: 3, valueInr: 2400000,  riskScore: 0.82, status: 'at_risk',  eta: 'today'),
    Shipment(id: 'SHP-0203', cargo: 'auto parts',         origin: 'Chennai Port', destination: 'Frankfurt',  cargoType: 'machinery', priority: 2, valueInr: 82000000, riskScore: 0.67, status: 'at_risk',  eta: '14 Feb'),
    Shipment(id: 'SHP-0455', cargo: 'food staples',       origin: 'JNPT',         destination: 'Jebel Ali',  cargoType: 'food',     priority: 1, valueInr: 6500000,  riskScore: 0.45, status: 'at_risk',  eta: '9 Feb'),
  ];
}
