# Roomlyst AI Evaluation Rubric (Milestone 0.1)

> Aligned with `interior_ai_app_blueprint.md` Section 32 & Section 41 (Milestone 0.1).

---

## 1. Evaluation Dimensions

To prevent evaluating AI outputs purely on visual appeal ("looks pretty"), every redesign generation pipeline must be scored on these five core quantitative and qualitative dimensions:

| Dimension | Weight | Definition | Target Threshold |
|---|---|---|---|
| **1. Structural Preservation** | 35% | Consistency of architectural openings (windows, entryways, structural columns, ceiling boundaries) between input and output. | $\ge 0.90$ |
| **2. Object Constraint Adherence** | 25% | Strict compliance with user Keep / Replace / Remove / Restyle flags (e.g. kept sofa is preserved; removed cabinet is absent). | $\ge 0.90$ |
| **3. Photorealism & Geometry** | 20% | Plausibility of perspective vanishing lines, depth continuity, shadow coherence, and lack of visual artifacts. | $\ge 0.85$ (or 4.0/5.0) |
| **4. Inference Latency** | 10% | Wall-clock execution time from request receipt to variant delivery. | $\le 10,000 \text{ ms}$ (Cloud API) / $\le 3,000 \text{ ms}$ (Local ref) |
| **5. Compute & API Cost** | 10% | Total financial cost incurred per generation request (3 variants). | $\le \$0.05 \text{ USD}$ per request |

---

## 2. Scoring Methodology

### Dimension 1: Structural Preservation Score ($S_{struct}$)
- **1.0**: Window/door positions, framing, and wall boundaries exactly match the original spatial coordinates.
- **0.8**: Minor stylistic trim variation, but position and dimensions remain within 5% tolerance.
- **0.5**: Openings shifted or altered in size.
- **0.0**: Architectural elements hallucinated or destroyed (e.g. window turned into a wall).

### Dimension 2: Object Constraint Score ($S_{obj}$)
- **1.0**: All elements marked `KEEP` retain silhouette, fabric/material identity; all `REMOVE` elements cleanly inpainted out; all `REPLACE` elements replaced with styled alternatives.
- **0.7**: Minor artifact in kept item or incomplete removal.
- **0.3**: Kept item noticeably altered or replaced.
- **0.0**: Flagrant disregard of user selections.

### Dimension 3: Visual Realism ($S_{real}$)
- Visual coherence, lighting distribution matching window light sources, and lack of distorted floating items.

---

## 3. Exit Criteria for Phase 0
- At least 2 of 3 generated variants must score $\ge 0.85$ composite score on the benchmark test set.
- All benchmark test results must be recorded with timestamp, model name, provider, latency, and cost to allow reproducible comparisons across model updates.
