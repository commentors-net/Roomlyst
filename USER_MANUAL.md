# Roomlyst — Complete User Manual & System Guide

Welcome to the official **Roomlyst User Manual**. This guide is divided into two distinct sections:
1. **[Part 1: The Everyday Homeowner & Designer Guide](#part-1--everyday-user-manual-non-technical)** — Written in plain, non-technical language for homeowners, renovators, and design enthusiasts who want to visualize, redesign, budget, and furnish their spaces effortlessly.
2. **[Part 2: The Technical & Professional Architecture Manual](#part-2--technical--developer-reference-manual)** — Written for software engineers, BIM managers, and technical professionals detailing the multi-tier sensor architecture, REST APIs, Single Canonical Room Model, RBAC security, and deployment pipelines.

---

# Part 1 — Everyday User Manual (Non-Technical)

### What is Roomlyst?
Roomlyst is an intelligent spatial AI app that turns your smartphone into an interior designer and renovation companion. You take a few photos or scan your room with your camera, and Roomlyst automatically:
- Identifies your walls, floor, doors, windows, and existing furniture.
- Lets you choose a style (like **Japandi**, **Modern Minimalist**, or **Industrial**) and creates photorealistic redesigns in seconds.
- Checks whether real furniture from popular retailers will physically fit through your doors and into your room.
- Estimates the cost of materials (paint, floor tiles, baseboards) and labor so you know your budget before spending a single dollar.
- Prepares a clear, shareable renovation package for your contractor.

---

## 1. Installing & Opening Roomlyst on Android

### Sideloading the App (APK)
1. Locate the generated APK file:
   `apps/mobile/build/app/outputs/flutter-apk/app-release.apk`
2. Transfer it to your Android phone via USB cable, Google Drive, or messaging.
3. On your phone, tap the file in your **Downloads** or **Files** app.
4. If prompted with *"For your security, your phone is not allowed to install unknown apps from this source"*:
   - Tap **Settings**.
   - Toggle **Allow from this source** to ON.
   - Tap **Install**.
5. Tap **Open** to launch Roomlyst.

---

## 2. Signing In (100% Free & No Card Required)

When you first launch Roomlyst, you are greeted with the welcome screen:

```
+------------------------------------------+
|                 [Logo]                   |
|                Roomlyst                  |
|  AI-Powered Interior Design & Renovation |
|                                          |
|  [ G  Continue with Google             ] |
|  [    Continue with Apple              ] |
|                                          |
|  100% Free authentication • No card req  |
|                                          |
|  ------------- OR EMAIL ---------------  |
|  [ Email Address                       ] |
|  [ Password                            ] |
|  [ Sign In                             ] |
|                                          |
|  [ Continue as Guest / Explore Demo    ] |
+------------------------------------------+
```

### Authentication Options:
- **Continue with Google**: One-tap sign in using your Google account. Completely free of charge.
- **Continue with Apple**: One-tap sign in using your Apple ID. Completely free of charge.
- **Email & Password**: Enter your email to register a new account or log in with existing credentials.
- **Continue as Guest / Explore Demo**: Want to test without creating an account? Tap this button to immediately explore sample rooms, budget calculators, and 3D furniture layouts with preloaded demo data.

---

## 3. Starting Your First Project

1. After signing in, you will arrive at the **Projects Dashboard**.
2. Tap the floating **+ (New Project)** button at the bottom right.
3. Enter a project name (e.g., *"Living Room Makeover"* or *"Master Bedroom"*).
4. Select your preferred currency (e.g., **MYR**, **SGD**, **USD**, **EUR**, **GBP**, **AUD**, **CAD**).
5. Tap **Create**. Your project workspace is ready!

---

## 4. Capturing Your Room (The "Magic" Scan)

Roomlyst works with any Android phone. You don't need expensive equipment, though phones with depth sensors provide even sharper accuracy.

### Preparing Your Room:
- **Turn on lights**: Bright, even lighting helps the AI detect floor edges and wall corners.
- **Tidy the floor**: Pick up clothes, boxes, or loose wires so the AI can measure your true floor area.
- **Keep permanent features visible**: Don't cover windows or main doorways.

### Choose Your Capture Mode:
Tap **Scan Room** inside your project:
1. **Guided Multi-Photo Mode (Recommended for everyone)**:
   - Stand in each corner of your room and take a photo aiming slightly downwards to include the floor and opposite walls.
   - The app's on-screen radar will show you green checkmarks as you cover all 4 corners.
2. **Video Walkthrough Sweep**:
   - Slowly sweep your camera across the room horizontally from left to right.
   - A smooth motion meter guides your panning speed.
3. **LiDAR / Depth Sensor Scan (Tier 1)**:
   - If your device has hardware depth sensing, a real-time point mesh will illuminate your room as you walk around.

### What Happens Next?
Roomlyst's AI instantly parses your room:
- Calculates your **Floor Area** ($m^2$ or sq ft) and **Ceiling Height**.
- Outlines every **Wall**, **Doorway**, and **Window**.
- Detects existing furniture (sofa, coffee table, TV console, cabinets).

---

## 5. Redesigning Your Space with AI

Once your scan is saved, tap **AI Redesign** to unleash your creativity:

### Step 1: Select Your Design Style
Choose from curated interior themes:
- **Japandi**: Warm wood, organic textures, serene neutrals, minimalist greenery.
- **Modern Minimalist**: Clean lines, monochromatic palette, hidden storage, uncluttered surfaces.
- **Industrial Chic**: Exposed brick, black steel accents, rustic reclaimed timber, raw concrete.
- **Scandinavian**: Airy light oak, cozy boucle fabrics, pastel accents, functional comfort.
- **Mid-Century Modern**: Iconic tapered legs, walnut timber, mustard/teal statement tones.
- **Luxury Contemporary**: Polished marble, brass trims, bespoke lighting, velvet finishes.

### Step 2: Choose What to Keep, Replace, or Remove
Tap on detected furniture pieces in the interactive room view:
- **KEEP (Lock)**: Love your existing sofa or hardwood floor? Mark it **Keep**, and the AI will preserve it untouched in every redesign.
- **REPLACE**: Want a modern dining table? Mark it **Replace**, and the AI will swap it for a stylish new piece matching your chosen style.
- **REMOVE**: Want to declutter an old cabinet? Mark it **Remove**, and the AI will open up that space cleanly.

### Step 3: Compare Before & After
- Tap **Generate Concepts**. In moments, Roomlyst generates photorealistic design variants.
- Use the **Interactive Split Slider** to drag your finger back and forth across the screen, seeing the transformation from your original room to your dream space.

---

## 6. Furnishing Your Room with Real Products

Tired of interior apps that show fantasy furniture you cannot buy? Roomlyst links directly to verified catalog items that actually exist!

1. Open the **Curated Catalogue & Fit** tab.
2. Browse furniture matching your design style.
3. **The Spans & Clearances Check**:
   - Tap **Check Fit** on any item (e.g., a 3-seater sofa).
   - Roomlyst compares the item's dimensions against your room's walkways, ceiling clearance, and doorway entry width.
   - **Green Badge (Perfect Fit)**: Item fits with generous circulation space.
   - **Yellow Badge (Tight Fit / Verification Warning)**: Item will fit, but verify your doorway diagonal before ordering.
   - **Red Badge (Oversized)**: Item will block doors or overcrowd the room.
4. Tap **View Retailer** to open the merchant's store with transparent pricing.

---

## 7. Estimating Renovation Budgets & Quantities

Before hiring a contractor or ordering materials, know your numbers:

1. Tap **Material Takeoff**:
   - See exact surface area quantities: Floor Tiles ($m^2$), Wall Paint ($m^2$), Ceiling Paint, and Baseboards ($m$).
   - Built-in **Wastage Sliders**: Adjust cutting allowances (e.g., +10% on tiles, +8% on paint) with one swipe.
2. Tap **Renovation Budget Planner**:
   - Switch between **Economy**, **Moderate**, **Premium**, or **Luxury** tiers to see realistic total costs.
   - Transparent split: See exactly how much goes to **Materials** vs. **Contractor Labor**.
   - Built-in regional tax calculation (SST, GST, VAT) and safety contingency buffer (5%–20%).

---

## 8. Working with Contractors & Interior Designers

Roomlyst eliminates miscommunication between you, your designer, and your builder:

1. **Inviting a Designer**:
   - Tap **Ecosystem Handoff** $\rightarrow$ **Homeowner to Designer**.
   - Your room scans, style preferences, and budget goals are transferred cleanly into the designer's professional studio suite.
2. **Contractor Tendering**:
   - Tap **Contractor Handoff**.
   - Download or print the **Contractor-Ready Tender Package**: Includes trade schedules (Wet Works, Electrical, Carpentry, Painting), verified Bill of Quantities, and on-site checklist.
   - Receive and compare contractor bids side-by-side to choose the best price and timeline.

---

## 9. For Real Estate Agents & Sellers (Virtual Staging)

Selling or renting a property?
1. Open **Property Staging**:
   - **Empty Room Staging**: Furnish a vacant property with high-end designer furniture while locking structural walls.
   - **Declutter & Stage**: Remove dated tenant clutter and replace it with fresh, modern staging.
   - **Renovation Potential Flip**: Show buyers what the home could look like with cosmetic updates (new flooring, fresh paint) alongside estimated ROI and value uplift.
2. Export compliant **RESO MLS syndication bundles** and print-ready **Property Marketing Flyers** in one click.

---

# Part 2 — Technical & Developer Reference Manual

### System Architecture Overview

Roomlyst is engineered as a clean architecture monorepo:

```
Roomlyst/
├── packages/
│   └── room_model/              # Single Canonical Room Model (Pydantic v2 schemas)
├── services/
│   ├── api/                     # FastAPI ASGI backend, SQLite/PostgreSQL ORM
│   └── ai_worker/               # Computer vision, 3D geometry & generative pipelines
├── apps/
│   └── mobile/                  # Flutter 3.x cross-platform mobile client (Android / iOS)
└── tests/                       # Pytest end-to-end integration & unit test suite
```

---

## 1. The 5-Tier Adaptive Hardware Capability Engine

Roomlyst adheres strictly to the **Adaptive Device Capability Matrix** (`ADR-009` & Blueprint Section 32). Hardware is dynamically evaluated at runtime into 5 fallback tiers without requiring proprietary sensors for basic functionality:

| Tier | Hardware Profile | Capture Pipeline | Metric Accuracy | Provenance Code |
|------|------------------|------------------|-----------------|-----------------|
| **Tier 1** | iOS LiDAR / TrueDepth / ToF | Depth Mesh + ARKit anchor integration | $\pm 20\,\text{mm}$ (High Confidence) | `LIDAR_NATIVE` |
| **Tier 2** | ARKit / ARCore with VIO Depth | Dense Point Cloud + Plane Detection | $\pm 50\,\text{mm}$ | `AR_ASSISTED_VIO` |
| **Tier 3** | Standard AR without Depth sensor | Sparse Point Cloud + Visual Feature Tracking | $\pm 80\,\text{mm}$ | `AR_ASSISTED_RGB` |
| **Tier 4** | Standard RGB Camera (Sweep Video) | Keyframe Bundle Adjustment / Epipolar Geometry | $\pm 120\,\text{mm}$ | `VIDEO_SWEEP_PHOTOGRAMMETRY` |
| **Tier 5** | Single / Multi-Photo Monocular | Perspective vanishing lines + reference calibration | Estimated ($\pm 15\%$) | `MONOCULAR_REFERENCE_CALIBRATED` |

### Measurement Integrity Rule:
Whenever a measurement originates from Tier 4 or 5, Roomlyst marks the dimension as `requires_field_measurement = True` and sets verification status to `UNVERIFIED_ESTIMATE`. Critical commercial contracts (such as bespoke cabinetry or structural demolition) enforce a mandatory physical tape-measure confirmation sign-off before fabrication.

---

## 2. The Single Canonical Room Model

The core state of every room is modeled in `packages/room_model/schema.py` under `CanonicalRoomModel`:

```python
class CanonicalRoomModel(BaseModel):
    id: str
    project_id: str
    name: str
    room_shape: RoomShapeType
    provenance_tier: SensorAccuracyTier
    confidence_score: float
    dimensions: RoomDimensions
    surfaces: List[RoomSurface]
    openings: List[RoomOpening]
    objects: List[RoomObject]
    material_takeoff: Optional[MaterialTakeoffReport]
    renovation_plan: Optional[RenovationPlanVersion]
    visualizations: List[ProductPlacementVisualization]
```

### Key Schema Entities:
- **`RoomDimensions`**: Width ($m$), length ($m$), ceiling height ($m$), floor area ($m^2$), and wall perimeter ($m$).
- **`RoomOpening`**: Structural doors, windows, and archways with 3D coordinates, width, height, and boundary lock flags.
- **`RoomObject`**: Detected furniture items segmented with bounding polygons, category classification, and user action states (`KEEP`, `REPLACE`, `REMOVE`).
- **`MaterialTakeoffReport`**: Surface-area deductions (gross wall area minus door/window openings), dynamic waste percentages (5%–25%), packaging spec calculations, and uncertainty intervals.

---

## 3. Cross-Segment Workflow Orchestration & RBAC Security

Roomlyst supports multi-organization project collaboration across 6 distinct roles:
1. `HOMEOWNER` — Project owner, concept viewer, brief author.
2. `INTERIOR_DESIGNER` — Professional workspace manager, variant designer, specifier.
3. `CONTRACTOR` — Tender bidder, trade subcontractor, execution team.
4. `MERCHANT_SELLER` — Verified furniture catalogue merchant.
5. `PROPERTY_AGENT` — Real estate marketing professional, syndication manager.
6. `STUDIO_ADMIN` — Design firm administrator.

### Privacy Redaction Engine (`RoleScopedProjectView`):
To prevent commercial and privacy leaks across participants, the backend executes strict field-level redactions:
- **Contractors**: Redacts client billing margins, designer commissions, and competitor bids. Exposes trade packages, BOQ takeoff schedules, and confirmed/estimated checklists.
- **Merchants**: Redacts architectural floorplans, tender submissions, and total renovation budgets. Exposes specified product models and physical clearance attestations.
- **Property Agents**: Redacts internal trade labor rates and client PII. Exposes virtually staged photography pairs, RESO disclosure manifests, and marketing flyer HTML.

### Tamper-Evident Audit Logging (`EcosystemAuditEvent`):
Every handoff transition, tender submission, client approval, and data export is logged into an immutable audit stream capturing:
`event_id`, `project_id`, `actor_id`, `actor_name`, `actor_role`, `action`, `resource_type`, `resource_id`, `metadata`, `timestamp_iso`, and `sensitive_action`.

---

## 4. REST API Specification

FastAPI serves 145+ REST endpoints under `/api/v1`:

### Authentication & Profiles
- `POST /api/v1/auth/register`: Create user account with bcrypt password hashing.
- `POST /api/v1/auth/login`: Authenticate email/password credentials and return JWT bearer token.
- `POST /api/v1/auth/social-login`: One-tap authentication for Google and Apple Identity providers (zero API cost). Auto-provisions user record and issues JWT token.
- `GET /api/v1/auth/me`: Retrieve current user profile and role claims.

### Projects & Workspaces
- `POST /api/v1/projects`: Create a project workspace.
- `GET /api/v1/projects`: List projects with client filter.
- `GET /api/v1/projects/{id}/summary`: Multi-room roll-up of total floor area and cumulative budget.
- `POST /api/v1/projects/{id}/collaborators`: Invite collaborators with role permissions (`OWNER`, `LEAD_DESIGNER`, `COLLABORATOR`, `VIEWER_CLIENT`).

### Room Ingestion & Analysis
- `POST /api/v1/rooms`: Ingest room image / scan bundle.
- `GET /api/v1/rooms/{id}/model`: Retrieve Canonical Room Model.
- `POST /api/v1/rooms/{id}/reconstruct`: Execute multi-view photogrammetry / point cloud plane extraction.
- `PATCH /api/v1/rooms/{id}/model/corrections`: Submit user object overrides (Keep, Replace, Remove).

### AI Redesign & Variants
- `POST /api/v1/rooms/{id}/redesign`: Generate styled redesign variants.
- `GET /api/v1/rooms/{id}/variants`: Retrieve generated design variants.
- `POST /api/v1/rooms/{id}/variants/{variant_id}/comments`: Pin spatial annotations with $(X, Y)$ coordinate pins.

### Commerce & In-Room Fit
- `GET /api/v1/catalog/products`: Query merchant catalog with category and currency filters.
- `POST /api/v1/catalog/products/{id}/check-fit`: Evaluate doorway ingress clearance and destination room circulation margins.
- `POST /api/v1/commerce/track-click`: Track affiliate conversion click with encrypted referral token.

### Renovation Execution & Contractor Handoff
- `POST /api/v1/rooms/{id}/material-takeoff`: Calculate material takeoff quantities with waste factor sliders.
- `GET /api/v1/projects/{id}/contractor-brief`: Generate contractor tender package with 6 trade packages.
- `GET /api/v1/contractor-briefs/{id}/printable`: Standalone print-ready HTML5 tender brief.
- `POST /api/v1/projects/{id}/rfqs`: Publish RFQ for contractor bidding.
- `POST /api/v1/rfqs/{id}/bids`: Submit contractor bid with statutory licensing acknowledgement.
- `GET /api/v1/rfqs/{id}/compare`: Side-by-side multi-bid variance comparison.

### Property Staging & RESO Syndication
- `POST /api/v1/listings/{id}/stage-room`: Generate virtually staged room concept with indelible regulatory watermark.
- `POST /api/v1/listings/{id}/export-portal-bundle`: RESO-compliant syndication package pairing original and staged photos.
- `GET /api/v1/listings/{id}/marketing-flyer`: Standalone print-ready HTML5 property brochure.

---

## 5. Development & Deployment Procedures

### Environment Prerequisites:
- Python 3.10+
- Flutter SDK 3.41+
- Android SDK 34+ / Build Tools (Java 17 LTS)

### Starting the Backend Services:
```bash
# Navigate to repository root
cd D:\Jobs\workspace\Roomlyst

# Install dependencies (virtual environment recommended)
pip install -r requirements.txt

# Start FastAPI ASGI server
python -m uvicorn services.api.app.main:app --host 0.0.0.0 --port 8000 --reload
```

### Running Backend Tests:
```bash
# Run complete test suite (253 unit & integration tests)
python -m pytest tests/ -v
```

### Running Flutter Mobile App & Tests:
```bash
cd apps/mobile

# Run static analysis (0 issues gate)
flutter analyze

# Run complete mobile test suite (155 unit & widget tests)
flutter test

# Run app on connected Android device or desktop emulator
flutter run
```

### Building the Android Release APK:
```bash
cd apps/mobile
flutter build apk
# Output artifact:
# apps/mobile/build/app/outputs/flutter-apk/app-release.apk
```

---

## 6. Regulatory & Statutory Compliance

Roomlyst incorporates statutory safety and disclosure requirements:
- **RESO Real Estate Disclosure**: Mandatory watermark burning (*"VIRTUALLY STAGED — FOR ILLUSTRATIVE PURPOSES ONLY"*) prevents consumer deception under Malaysian BOVAEP (Act 242) and Singapore CEA guidelines.
- **Statutory Trade Notices**: Renovation plans include mandatory disclaimers requiring structural, electrical, and plumbing works to be performed exclusively by licensed trades with local municipal council permits (e.g. DBKL, BCA, OSHA).
- **GDPR / Privacy Sanitization**: EXIF metadata stripping removes GPS latitude/longitude coordinates and camera serial numbers before storing or processing room imagery.
