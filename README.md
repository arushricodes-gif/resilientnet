# ResilientNet

> Resilient logistics and dynamic supply chain optimization.
> Predict cascades before they happen · reroute before shipments are late.

A real-time supply chain disruption detection and response platform. When something goes wrong at one hub — a storm, strike, port closure, accident — our system predicts which shipments across the entire network will be affected, and automatically reroutes them before delays cascade.

---

## Repo Structure

```
resilientnet/
├── lib/                        Flutter app (the frontend)
│   ├── main.dart              Top tab bar
│   ├── screens/               Ops · Driver · Customer
│   ├── widgets/               Schematic design system
│   ├── theme/                 Drafting notebook aesthetic
│   ├── data/fake_data.dart    Demo data
│   └── services/api_service.dart  HTTP client → backend
│
├── pubspec.yaml               Flutter config
│
├── resilientnet_backend/       FastAPI backend (the API)
│   ├── app/
│   │   ├── main.py            5 endpoints
│   │   ├── cascade_engine.py  Hand-crafted graph algorithm (15 hubs)
│   │   ├── gnn_cascade.py     Trained ST-GCN model (20 hubs)
│   │   ├── gnn_model.py       PyTorch model class
│   │   ├── gnn_graph.py       South India hub graph
│   │   ├── gemini_client.py   News parser
│   │   ├── route_optimizer.py Alternative routing
│   │   └── ...
│   ├── data/                  hubs.json + shipments.json
│   ├── models/
│   │   └── stgcn_improved.pt  Trained model (164 KB, val_mae=0.033)
│   └── requirements.txt
│
└── resilientnet/               ML training code (the brain)
    ├── train_improved.py       Improved training script
    ├── data/                   Synthetic disruption simulator
    ├── models/                 ST-GCN architecture
    └── ...
```

---

## Quick Start

### Frontend (Flutter)

```bash
flutter pub get
flutter run -d chrome
```

Opens at http://localhost:port_flutter_chooses with three tabs.

### Backend (Python)

```bash
cd resilientnet_backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

Set up Gemini key (one-time):
```bash
cp .env.example .env
# Edit .env and paste your Gemini key from https://aistudio.google.com/apikey
```

Run:
```bash
uvicorn app.main:app --reload --port 8080
```

Open http://localhost:8080/docs for the interactive API tester.

### Verify End-to-End

1. Backend running on :8080 (you should see `[GNN] Loaded trained model · val_mae=0.0329`)
2. Flutter running on whatever Chrome port
3. Click "Cyclone — Mumbai Port" in the Ops tab
4. The "LIVE · X% conf" badge should appear in the cascade alert bar (proof it's calling the real backend)

---

## Tech Stack

| Layer | Tech |
|-------|------|
| Frontend | Flutter 3.10+ (web) |
| Backend API | Python · FastAPI · uvicorn |
| Cascade engine 1 | NetworkX graph algorithm (interpretable) |
| Cascade engine 2 | ST-GCN trained neural network (PyTorch + PyTorch Geometric) |
| News parsing | Gemini 1.5 Flash |
| Route optimization | NetworkX shortest-path |

---

## The Two Cascade Engines

### `/predict_cascade` — Hand-crafted
- Uses 15 international hubs (matches Flutter UI)
- Interpretable: every risk factor has business meaning (priority, distance, reliability, depth decay)
- Deterministic, fast, no ML dependencies

### `/predict_cascade_gnn` — Trained ST-GCN
- Uses 20 South India hubs (Kerala/TN/AP/Karnataka/Telangana)
- Learned from synthetic cascade data
- LSTM temporal encoder + 3 GCN spatial layers
- Validation MAE: 0.033

Both available simultaneously. Pitch can use either.

---

## Team

| Role | Owner | Responsibilities |
|------|-------|------------------|
| Frontend | A | UI, screens, design |
| Firebase / Cloud | B | Deployment, auth |
| ML / Backend | C | GNN training, FastAPI, optimization |
| Demo / Pitch | D | Slides, script, video |

---

## Status

### Done
- [x] Flutter frontend, 3 tabs, schematic design
- [x] Python FastAPI backend with hand-crafted cascade
- [x] Trained ST-GCN integrated as second cascade engine
- [x] Gemini news parser (with keyword fallback)
- [x] Route optimizer
- [x] Frontend wired to backend (Ops tab calls /predict_cascade live)
- [x] Demo-mode fallback if backend offline (graceful)

### Next Up
- [ ] Wire Driver + Customer tabs to real backend data
- [ ] Deploy backend to Cloud Run for public demo URL
- [ ] Pitch deck
- [ ] Backup demo recording

---

## Demo Flow

1. **Open Ops tab** — 200 active shipments, all green
2. **Click "Cyclone — Mumbai Port"** — Flutter calls backend, real cascade engine runs
3. **See LIVE badge appear** — proof of real backend call
4. **Click "Run optimizer"** — backend computes reroutes
5. **Switch to Driver tab** — accept reroute on phone view
6. **Switch to Customer tab** — same ETA, proactive notification
7. **Closer:** "Predict. Propagate. Prevent."

---

## License

Hackathon project. All rights reserved by the team.
