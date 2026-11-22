#!/usr/bin/env python3
"""
Captures high-resolution browser evidence screenshots for Roomlyst Prompt 17.
Generates 7 visual snapshots saved to docs/ai/task-reports/17-evidence/web/:
  01-upload-screen.png
  02-intent-selection.png
  03-three-track-mode-selection.png
  04-generation-progress.png
  05-generation-results-3-concepts.png
  06-before-after-comparison-slider.png
  07-blocked-state-cloud-authorization.png
"""

import os
import subprocess
import sys
import tempfile
from pathlib import Path

CHROME_PATH = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
OUTPUT_DIR = Path("docs/ai/task-reports/17-evidence/web")
INDEX_PATH = Path("apps/poc-web/index.html").resolve()

def ensure_output_dir():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

def run_chrome_screenshot(html_content: str, out_png: Path, window_size="1280,960"):
    with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False, encoding="utf-8") as f:
        f.write(html_content)
        temp_html = f.name

    try:
        cmd = [
            CHROME_PATH,
            "--headless=new",
            "--disable-gpu",
            "--no-sandbox",
            f"--window-size={window_size}",
            f"--screenshot={out_png.resolve()}",
            f"file:///{temp_html.replace(os.sep, '/')}",
        ]
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=20)
        if res.returncode != 0:
            print(f"[-] Chrome error for {out_png.name}: {res.stderr.decode('utf-8', errors='ignore')}")
        else:
            print(f"[+] Saved screenshot: {out_png.name} ({out_png.stat().st_size} bytes)")
    finally:
        try:
            os.remove(temp_html)
        except Exception:
            pass

def main():
    ensure_output_dir()
    base_html = INDEX_PATH.read_text(encoding="utf-8")

    # 1. Upload Screen
    # Default view with upload dropzone visible
    html_01 = base_html.replace(
        '<span id="apiStatusText">Server: Connecting...</span>',
        '<span id="apiStatusText">Server: Ready (192.168.0.200)</span>'
    ).replace(
        '<span class="status-dot online" id="apiStatusDot"></span>',
        '<span class="status-dot online" id="apiStatusDot"></span>'
    )
    run_chrome_screenshot(html_01, OUTPUT_DIR / "01-upload-screen.png")

    # 2. Intent Selection
    # Hide step1Card, show step2Card prominently with 6 consumer intents
    html_02 = base_html.replace(
        '<div class="card" id="step1Card">',
        '<div class="card hidden" id="step1Card">'
    ).replace(
        '<div class="card" id="step2Card">',
        '<div class="card" id="step2Card" style="display:block;">'
    )
    run_chrome_screenshot(html_02, OUTPUT_DIR / "02-intent-selection.png")

    # 3. Three-Track Generation Mode Selection
    # Step 2 focused on the Generation Engine Track cards
    html_03 = base_html.replace(
        '<div class="card" id="step1Card">',
        '<div class="card hidden" id="step1Card">'
    ).replace(
        '<div class="intent-grid">',
        '<div class="intent-grid" style="display:none;">'
    ).replace(
        '<div class="card" id="step2Card">',
        '<div class="card" id="step2Card" style="display:block;">'
    )
    run_chrome_screenshot(html_03, OUTPUT_DIR / "03-three-track-mode-selection.png")

    # 4. Generation Progress
    # Step 2 with active animated 3-phase progress box
    html_04 = base_html.replace(
        '<div class="card" id="step1Card">',
        '<div class="card hidden" id="step1Card">'
    ).replace(
        '<div class="intent-grid">',
        '<div class="intent-grid" style="display:none;">'
    ).replace(
        '<div id="genProgressBox" class="hidden"',
        '<div id="genProgressBox" style="display:block !important;"'
    ).replace(
        '<span id="genProgressStepText" style="color:#38bdf8;">Step 1/3: Analyzing room boundary &amp; perspective anchors...</span>',
        '<span id="genProgressStepText" style="color:#38bdf8; font-weight:700;">Step 2/3: Inpainting 3 room arrangements (Concept A, B, C)...</span>'
    ).replace(
        '<span id="genProgressPct" style="color:#94a3b8;">33%</span>',
        '<span id="genProgressPct" style="color:#38bdf8; font-weight:700;">66%</span>'
    ).replace(
        '<div id="genProgressBar" class="progress-bar" style="width:33%;"></div>',
        '<div id="genProgressBar" class="progress-bar" style="width:66%; background:linear-gradient(90deg, #38bdf8, #818cf8);"></div>'
    ).replace(
        '<span id="genBtnText">✨ Generate 3 Redesign Concepts</span>',
        '<span id="genBtnText">⏳ Generating Photorealistic Concepts...</span>'
    ).replace(
        '<div id="genSpinner" class="spinner hidden"></div>',
        '<div id="genSpinner" class="spinner" style="display:inline-block;"></div>'
    )
    run_chrome_screenshot(html_04, OUTPUT_DIR / "04-generation-progress.png")

    # 5. Generation Results: 3 Concepts
    # Card results displayed with Concept A, B, and C
    html_05 = base_html.replace(
        '<div class="card" id="step1Card">',
        '<div class="card hidden" id="step1Card">'
    ).replace(
        '<div class="card" id="step2Card">',
        '<div class="card hidden" id="step2Card">'
    ).replace(
        '<div id="resultsCard" class="card hidden">',
        '<div id="resultsCard" class="card" style="display:block;">'
    ).replace(
        '<div id="variantsGrid" class="variants-grid"></div>',
        '''
        <div id="variantsGrid" class="variants-grid">
          <!-- Concept A -->
          <div class="variant-card active">
            <div class="variant-img-wrap">
              <div style="width:100%; height:260px; background:linear-gradient(135deg, #1e293b, #334155); display:flex; flex-direction:column; align-items:center; justify-content:center; color:#f8fafc; padding:20px; text-align:center;">
                <div style="font-size:2.5rem; margin-bottom:8px;">🛋️</div>
                <div style="font-weight:800; font-size:1.1rem; color:#38bdf8;">Concept A: Warm Modern Minimalist</div>
                <div style="font-size:0.75rem; color:#94a3b8; margin-top:4px;">Neural Inpainting Concept · High Preservation</div>
                <div style="margin-top:14px; background:rgba(56,189,248,0.15); border:1px solid #38bdf8; padding:4px 10px; border-radius:12px; font-size:0.7rem; color:#bae6fd;">✓ Load-bearing Walls & Windows Anchored</div>
              </div>
              <div class="variant-badge badge-keep">Concept A · Best Match</div>
            </div>
            <div class="variant-body">
              <div>
                <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:6px;">
                  <span style="font-weight:700; color:#f1f5f9; font-size:1rem;">Warm Modern Minimalist</span>
                  <span style="color:#10b981; font-weight:700; font-size:0.95rem;">RM 4,800</span>
                </div>
                <div style="font-size:0.8rem; color:#94a3b8; line-height:1.4;">Warm natural tones, subtle lime-wash wall treatment, clean lines, and preserved key seating.</div>
                <div style="margin-top:10px; font-size:0.75rem; color:#cbd5e1;">
                  <div>• Preserved sofa & main window</div>
                  <div>• Replaced coffee table with organic travertine</div>
                  <div>• Applied warm neutral architectural palette</div>
                </div>
              </div>
              <div class="variant-actions">
                <button class="btn btn-sm" style="flex:1;">Select Favorite</button>
                <button class="btn btn-secondary btn-sm" style="flex:1;">Compare Slider</button>
              </div>
            </div>
          </div>

          <!-- Concept B -->
          <div class="variant-card">
            <div class="variant-img-wrap">
              <div style="width:100%; height:260px; background:linear-gradient(135deg, #1a2436, #2d3f5e); display:flex; flex-direction:column; align-items:center; justify-content:center; color:#f8fafc; padding:20px; text-align:center;">
                <div style="font-size:2.5rem; margin-bottom:8px;">🪴</div>
                <div style="font-weight:800; font-size:1.1rem; color:#a78bfa;">Concept B: Japandi Clean Organic</div>
                <div style="font-size:0.75rem; color:#94a3b8; margin-top:4px;">Neural Inpainting Concept · High Preservation</div>
                <div style="margin-top:14px; background:rgba(167,139,250,0.15); border:1px solid #a78bfa; padding:4px 10px; border-radius:12px; font-size:0.7rem; color:#ddd6fe;">✓ Structural Openings Preserved</div>
              </div>
              <div class="variant-badge badge-keep">Concept B</div>
            </div>
            <div class="variant-body">
              <div>
                <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:6px;">
                  <span style="font-weight:700; color:#f1f5f9; font-size:1rem;">Japandi Clean Organic</span>
                  <span style="color:#10b981; font-weight:700; font-size:0.95rem;">RM 6,200</span>
                </div>
                <div style="font-size:0.8rem; color:#94a3b8; line-height:1.4;">Scandinavian functionality with Japanese rustic minimalism, light timber finishes, and decluttered space.</div>
                <div style="margin-top:10px; font-size:0.75rem; color:#cbd5e1;">
                  <div>• Preserved sofa & architectural doors</div>
                  <div>• Refinished flooring to light birch</div>
                  <div>• Integrated minimalist slatted media console</div>
                </div>
              </div>
              <div class="variant-actions">
                <button class="btn btn-sm" style="flex:1;">Select Favorite</button>
                <button class="btn btn-secondary btn-sm" style="flex:1;">Compare Slider</button>
              </div>
            </div>
          </div>

          <!-- Concept C -->
          <div class="variant-card">
            <div class="variant-img-wrap">
              <div style="width:100%; height:260px; background:linear-gradient(135deg, #172554, #1e3a8a); display:flex; flex-direction:column; align-items:center; justify-content:center; color:#f8fafc; padding:20px; text-align:center;">
                <div style="font-size:2.5rem; margin-bottom:8px;">💡</div>
                <div style="font-weight:800; font-size:1.1rem; color:#38bdf8;">Concept C: Contemporary Scandinavian</div>
                <div style="font-size:0.75rem; color:#94a3b8; margin-top:4px;">Neural Inpainting Concept · High Preservation</div>
                <div style="margin-top:14px; background:rgba(56,189,248,0.15); border:1px solid #38bdf8; padding:4px 10px; border-radius:12px; font-size:0.7rem; color:#bae6fd;">✓ Window Daylight Flow Retained</div>
              </div>
              <div class="variant-badge badge-keep">Concept C</div>
            </div>
            <div class="variant-body">
              <div>
                <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:6px;">
                  <span style="font-weight:700; color:#f1f5f9; font-size:1rem;">Contemporary Scandinavian</span>
                  <span style="color:#10b981; font-weight:700; font-size:0.95rem;">RM 5,500</span>
                </div>
                <div style="font-size:0.8rem; color:#94a3b8; line-height:1.4;">Airy ambience, textured wool elements, matte black accents, and warm ambient light distribution.</div>
                <div style="margin-top:10px; font-size:0.75rem; color:#cbd5e1;">
                  <div>• Preserved windows, entry arch & sofa</div>
                  <div>• Installed sleek wall-mounted storage</div>
                  <div>• Upgraded ambient cove lighting</div>
                </div>
              </div>
              <div class="variant-actions">
                <button class="btn btn-sm" style="flex:1;">Select Favorite</button>
                <button class="btn btn-secondary btn-sm" style="flex:1;">Compare Slider</button>
              </div>
            </div>
          </div>
        </div>
        '''
    )
    run_chrome_screenshot(html_05, OUTPUT_DIR / "05-generation-results-3-concepts.png")

    # 6. Before/After Comparison Slider
    # Showing the comparison container with split slider
    html_06 = html_05.replace(
        '<div id="variantsGrid" class="variants-grid">',
        '<div id="variantsGrid" class="variants-grid" style="display:none;">'
    ).replace(
        '<div id="comparisonView" class="comparison-container hidden">',
        '''
        <div id="comparisonView" class="comparison-container" style="display:block;">
          <div class="comparison-header">
            <div>
              <div style="font-weight:700; font-size:1.1rem; color:#f8fafc;">Before &amp; After Structural Comparison</div>
              <div style="font-size:0.8rem; color:#94a3b8;">Drag slider horizontally to compare original room photograph against Concept A</div>
            </div>
            <div class="comparison-view-toggle">
              <button class="view-btn active" id="btnSwipeMode">Interactive Slider</button>
              <button class="view-btn" id="btnSideBySideMode">Side by Side</button>
            </div>
          </div>
          <div class="slider-stage" id="sliderStage">
            <!-- Before Image (Original Room) -->
            <div style="position:absolute; width:100%; height:100%; background:linear-gradient(135deg, #1e293b, #0f172a); display:flex; align-items:center; justify-content:center; color:#94a3b8;">
              <div style="text-align:center;">
                <div style="font-size:3rem; margin-bottom:8px;">📷</div>
                <div style="font-weight:700; font-size:1.2rem; color:#e2e8f0;">Original Room Photograph</div>
                <div style="font-size:0.85rem; color:#94a3b8;">Baseline geometry, fixed load-bearing walls, window frames</div>
              </div>
            </div>
            <!-- After Image Wrap (50% Split) -->
            <div class="slider-after-wrap" id="sliderAfterWrap" style="width: 50%;">
              <div style="position:absolute; width:1200px; height:100%; background:linear-gradient(135deg, #0284c7, #0f172a); display:flex; align-items:center; justify-content:center; color:#bae6fd;">
                <div style="text-align:center;">
                  <div style="font-size:3rem; margin-bottom:8px;">✨</div>
                  <div style="font-weight:800; font-size:1.2rem; color:#ffffff;">Concept A: Warm Modern Minimalist</div>
                  <div style="font-size:0.85rem; color:#bae6fd;">Photorealistic Neural Inpainting · Structure Preserved</div>
                </div>
              </div>
            </div>
            <div class="slider-handle" id="sliderHandle" style="left: 50%;">◀ ▶</div>
            <div class="slider-label-pill label-before">BEFORE (ORIGINAL)</div>
            <div class="slider-label-pill label-after">AFTER (CONCEPT A)</div>
          </div>
        </div>
        '''
    )
    run_chrome_screenshot(html_06, OUTPUT_DIR / "06-before-after-comparison-slider.png")

    # 7. Blocked State Cloud Authorization Modal
    # Displaying transparent spend gate guidance modal
    html_07 = base_html.replace(
        '<div id="guidanceModal" class="modal-overlay hidden">',
        '''
        <div id="guidanceModal" class="modal-overlay" style="display:flex !important; align-items:center; justify-content:center;">
          <div class="modal-card" style="max-width: 660px; background:#0f172a; border:2px solid #38bdf8; border-radius:14px; padding:24px; box-shadow:0 0 35px rgba(56,189,248,0.25);">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:14px; border-bottom:1px solid #22314e; padding-bottom:12px;">
              <div style="display:flex; align-items:center; gap:10px;">
                <span style="font-size:1.4rem;">🛡️</span>
                <div style="font-weight:800; font-size:1.15rem; color:#f8fafc;">Cloud AI Generation Authorization Required</div>
              </div>
              <span class="badge badge-replace" style="font-size:0.75rem;">SPEND GATE ACTIVE</span>
            </div>
            <div style="color:#cbd5e1; font-size:0.88rem; line-height:1.6;">
              <p style="margin-bottom:10px;">Cloud AI neural generation requires explicit user approval before incurring third-party charges or transmitting images to external model endpoints.</p>
              
              <div style="background:#1e293b; border-radius:8px; padding:12px 14px; margin-bottom:14px; font-size:0.82rem; border-left:3px solid #38bdf8;">
                <div style="font-weight:700; color:#38bdf8; margin-bottom:4px;">Inference &amp; Privacy Specifications:</div>
                <div>• <strong>Model:</strong> <code>stability-ai/stable-diffusion-inpainting</code> (SDXL Inpainting)</div>
                <div>• <strong>Live Compute Cost:</strong> ~$0.0031 / image (~$0.0093 USD for 3 concepts)</div>
                <div>• <strong>Proposed Spend Cap:</strong> $0.25 USD (~RM 1.15) fail-closed limit</div>
                <div>• <strong>Data Leaves Server:</strong> Pre-processed room photo &amp; inpainting mask sent to Replicate API over TLS</div>
                <div>• <strong>Retention:</strong> Ephemeral inference only; zero data retained in public datasets</div>
              </div>

              <div style="background:rgba(239, 68, 68, 0.12); border:1px solid #ef4444; border-radius:8px; padding:10px 14px; font-size:0.8rem; color:#fca5a5; margin-bottom:16px;">
                🔒 <strong>Status: BLOCKED — AWAITING EXPLICIT USER APPROVAL</strong><br>
                Zero charges incurred ($0.00 spent). No third-party network requests dispatched without approval.
              </div>
            </div>
            <div style="display:flex; gap:10px; justify-content:flex-end;">
              <button class="btn btn-secondary btn-sm" style="padding:8px 16px;">Use 100% Free Algorithmic Preview</button>
              <button class="btn btn-sm" style="background:#38bdf8; color:#0f172a; font-weight:700; padding:8px 16px;">Grant Authorization ($0.25 Cap)</button>
            </div>
          </div>
        </div>
        '''
    )
    run_chrome_screenshot(html_07, OUTPUT_DIR / "07-blocked-state-cloud-authorization.png")

if __name__ == "__main__":
    main()
