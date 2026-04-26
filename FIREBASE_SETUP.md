# Firebase Setup Guide for ResilientNet

## What Firebase Does in This Project

| Feature | Firebase Service | What it enables |
|---|---|---|
| Live disruption feed | **Firestore** | Flutter gets push updates in <1s, no polling |
| Push notifications | **FCM** | Drivers get alerted on their phones |
| Auto-cleanup | **Cloud Functions** | Old disruptions auto-resolve after 6h |
| Scheduled polling | **Cloud Scheduler** | Backend polls NewsAPI even when server scales to zero |

---

## Step 1: Create Firebase Project

1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Click **Add project** → name it `resilientnet`
3. Enable **Google Analytics** (optional)

---

## Step 2: Set Up Firestore

1. In Firebase Console → **Firestore Database** → **Create database**
2. Choose **Production mode** → pick region `asia-south1` (Mumbai)
3. Add these security rules:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Disruptions — readable by all authenticated users
    match /disruptions/{id} {
      allow read: if request.auth != null;
      allow write: if false; // only backend writes via service account
      
      match /routes/{routeId} {
        allow read: if request.auth != null;
      }
    }
    
    // Realtime status — public read
    match /realtime_status/{doc} {
      allow read: if true;
      allow write: if false;
    }
  }
}
```

---

## Step 3: Get Service Account Key (for Python backend)

1. Firebase Console → **Project Settings** → **Service Accounts**
2. Click **Generate new private key** → download JSON
3. Rename it `serviceAccountKey.json`
4. Place it in `resilientnet_backend/` (it's in `.gitignore` — don't commit it!)
5. Set in your `.env`:
   ```
   FIREBASE_CREDS_PATH=serviceAccountKey.json
   ```

---

## Step 4: Connect Flutter App

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Link your Flutter app to Firebase
cd resilientnet/   # the Flutter project root
flutterfire configure --project=your-project-id
```

This generates `lib/firebase_options.dart` automatically.

Then update `lib/main.dart` to initialize Firebase before `runApp()`:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ResilientNetApp());
}
```

---

## Step 5: Add Live Widgets to Your Screens

### Ops Dashboard — add the live feed panel:
```dart
import '../widgets/live_disruption_feed.dart';

// In your ops dashboard body:
LiveDisruptionFeed(
  severityMin: 0.4,  // show medium and above
  onTap: (event) {
    // navigate to disruption detail
  },
)
```

### Any screen — add the status bar:
```dart
// In your AppBar:
AppBar(
  title: Text('ResilientNet Ops'),
  bottom: PreferredSize(
    preferredSize: Size.fromHeight(28),
    child: LiveStatusBar(),
  ),
)
```

### Customer view — shipment-specific alerts:
```dart
ShipmentAlertCard(shipmentId: 'SHP-0042')
```

---

## Step 6: Deploy Cloud Functions (optional but recommended)

```bash
cd firebase/functions
npm install
firebase login
firebase use your-project-id
firebase deploy --only functions
```

This activates:
- **FCM push notifications** when critical disruptions are detected
- **Auto-resolve** of disruptions older than 6 hours
- **Scheduled polling** so the backend works even when scaled to zero

---

## Step 7: Set Environment Variables

In `resilientnet_backend/.env`:
```env
GEMINI_API_KEY=your_gemini_key
NEWS_API_KEY=your_newsapi_key        # free at newsapi.org (500 req/day)
FIREBASE_CREDS_PATH=serviceAccountKey.json
POLL_INTERVAL_SEC=300                # 5 minutes
```

---

## Running the Full System

```bash
# Terminal 1: Start the backend (auto-starts the poller)
cd resilientnet_backend
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8080

# Terminal 2: Run Flutter
cd ..   # back to resilientnet/
flutter run -d chrome

# Optional: Run poller standalone (without the full server)
python -m app.realtime_poller
```

---

## Demo Mode (no API keys needed)

If `NEWS_API_KEY` is not set, the poller runs in **demo mode** — it uses
realistic simulated Indian logistics headlines that rotate randomly.
This is great for demos without using your API quota.

Use `POST /realtime/simulate` to inject any headline instantly:
```bash
curl -X POST http://localhost:8080/realtime/simulate \
  -H "Content-Type: application/json" \
  -d '{
    "headline": "Chennai Port workers begin indefinite strike over wages",
    "severity_override": 0.85,
    "location_override": "Chennai Port"
  }'
```
Flutter updates live within 1 second.

---

## Architecture Overview

```
NewsAPI (every 5 min)
    ↓
realtime_poller.py
    ├── Gemini: headline → structured event (type, severity, location)
    ├── GNN: event → cascade prediction (which shipments at risk)
    └── OR-Tools: cascade → optimal reroutes
         ↓
    Firestore: disruptions/{id}
         ↓ (StreamBuilder — <1 second)
    Flutter: LiveDisruptionFeed, ShipmentAlertCard, LiveStatusBar
         ↓ (Firestore trigger)
    Cloud Functions → FCM → Driver's phone notification
```
