# Roomlyst

> **AI-Powered Interior Design & Renovation Platform**
>
> Roomlyst helps users visualize and plan real-world interior improvements using ordinary smartphone photos or videos. It understands room structure, dimensions, furniture, and layout, generating realistic redesign suggestions while adapting dynamically to device capabilities—leveraging LiDAR when available and monocular camera AI when it is not.

---

## 🎯 Current Position: Phase 0 — Technical Validation / POC

As defined in `interior_ai_app_blueprint.md` Section 0.3 and Section 55:
- **Primary Goal:** Prove that a normal room photo can be understood, segmented, and redesigned while strictly preserving architectural structure (walls, windows, doors) and user-selected objects (e.g. keeping existing sofas or cabinets).
- **Current Milestones:**
  - **Milestone 0.1:** Benchmark & evaluation foundation with quality rubric.
  - **Milestone 0.2:** Room understanding spike (segmentation, depth, object detection, canonical model).
  - **Milestone 0.3:** Structure-preserving redesign spike with keep/replace/remove constraints.
  - **Milestone 0.4:** Internal POC interactive web application.

---

## 🏗️ Repository Architecture

Following Blueprint Section 42:

```text
roomlyst/
├── apps/
│   ├── poc-web/           # Internal POC web application (Milestone 0.4)
│   ├── admin-web/         # Support & cost inspection panel (Phase 1)
│   └── mobile/            # Flutter cross-platform mobile app (Phase 1+)
├── services/
│   ├── api/               # FastAPI backend & orchestration service
│   ├── ai-worker/         # CV pipelines: Quality check, Segmentation, Depth, Redesign
│   ├── reconstruction-worker/ # Multi-view SfM / 3D reconstruction (Phase 3)
│   └── notification-worker/   # Async task notification service
├── packages/
│   ├── room-model/        # Canonical Room Model v1 schemas & provenance logic
│   ├── api-contracts/     # Typed request/response DTOs
│   ├── config/            # Shared environment settings
│   └── telemetry/         # Observability & cost metrics
├── docs/
│   ├── adr/               # Architecture Decision Records
│   ├── ai-evaluation/     # Benchmark rubrics and datasets
│   └── progress.md        # Milestone tracking log
├── scripts/               # Benchmarking and development utilities
└── tests/                 # End-to-end and integration test suites
```

---

## 🚀 Quickstart

### Prerequisites
- Python 3.10+
- Node.js 18+ (for web UI)

### 1. Run the Backend API & POC Server
```bash
# Set PYTHONPATH to include packages and services
set PYTHONPATH=.;packages;services

# Run the API and POC server
python -m uvicorn services.api.app.main:app --host 127.0.0.1 --port 8000 --reload
```

Open your browser to:
- **POC Web Interface:** [http://127.0.0.1:8000](http://127.0.0.1:8000)
- **Interactive API Docs (Swagger):** [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)

### 2. Run Test Suite
```bash
python -m pytest tests/ -v
```

### 3. Run Benchmark Suite
```bash
python scripts/run_benchmark.py
```

---

## 🛡️ Core Principles
1. **No LiDAR requirement:** Fully functional on ordinary smartphone cameras.
2. **Progressive enhancement:** Automatically exploits LiDAR / AR when detected.
3. **Architecture preservation:** Windows, doors, and structural walls remain consistent.
4. **Transparent provenance:** All measurements track source and confidence score.
5. **User control:** Keep, replace, remove, and restyle any detected element.
