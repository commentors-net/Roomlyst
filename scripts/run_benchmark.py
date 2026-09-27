"""
Roomlyst AI Benchmark Evaluation Runner.
Fulfills Milestone 0.1: Benchmark and evaluation foundation.
Runs automated evaluation suite against representative living room benchmark testcases.
"""

import json
import os
import sys
import time
from typing import Dict, List
import numpy as np
from PIL import Image

# Ensure path includes root directory
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from packages.room_model import CanonicalRoomModel, ObjectAction
from services.ai_worker.pipelines.generation import LocalRedesignGenerator
from services.ai_worker.pipelines.quality import ImageQualityChecker
from services.ai_worker.pipelines.room_analyzer import RoomAnalyzer


def generate_benchmark_testcase(test_id: str, case_name: str, has_challenging_lighting: bool = False) -> Image.Image:
    """Generates synthetic benchmark test room photos with controlled variations."""
    w, h = 800, 600
    arr = np.zeros((h, w, 3), dtype=np.uint8)

    # Ceiling & walls
    arr[0:int(h*0.25), :] = [235, 235, 240]
    wall_color = [180, 175, 165] if not has_challenging_lighting else [130, 125, 115]
    arr[int(h*0.25):int(h*0.7), :] = wall_color
    # Floor
    arr[int(h*0.7):, :] = [165, 125, 85]

    # Windows
    arr[int(h*0.3):int(h*0.58), int(w*0.55):int(w*0.88)] = [140, 195, 235]
    # Sofa
    arr[int(h*0.48):int(h*0.78), int(w*0.22):int(w*0.62)] = [75, 80, 90]
    # Coffee table
    arr[int(h*0.72):int(h*0.88), int(w*0.35):int(w*0.55)] = [110, 70, 40]

    # Add realistic texture noise
    noise = np.random.randint(-12, 12, (h, w, 3))
    arr = np.clip(arr.astype(int) + noise, 0, 255).astype(np.uint8)
    return Image.fromarray(arr)


def run_benchmark():
    print("=" * 70)
    print("ROOMLYST AI EVALUATION BENCHMARK -- PHASE 0 (Milestone 0.1)")
    print("=" * 70)

    quality_checker = ImageQualityChecker()
    room_analyzer = RoomAnalyzer(quality_checker=quality_checker)
    generator = LocalRedesignGenerator(output_dir="storage/outputs")

    test_cases = [
        {"id": "BM-01", "name": "Standard Living Room - Daylight", "challenging_light": False},
        {"id": "BM-02", "name": "Compact Apartment Living Room", "challenging_light": False},
        {"id": "BM-03", "name": "Moody / Lower-Light Living Room", "challenging_light": True},
    ]

    results: List[Dict] = []
    total_start = time.time()

    for tc in test_cases:
        print(f"\nEvaluating {tc['id']}: {tc['name']}...")
        img = generate_benchmark_testcase(tc["id"], tc["name"], tc["challenging_light"])

        # 1. Quality Check
        qr = quality_checker.validate_image(img)

        # 2. Room Understanding
        t0 = time.time()
        room = room_analyzer.analyze_photo(img, room_name=tc["name"])
        analysis_latency = (time.time() - t0) * 1000.0

        # Set keep/replace actions
        if room.objects:
            room.set_action_for_element(room.objects[0].id, ObjectAction.KEEP)
        if len(room.objects) > 1:
            room.set_action_for_element(room.objects[1].id, ObjectAction.REPLACE)

        # 3. Constraint Formulation
        constraints = room.build_design_constraint(
            styles=["Warm Modern Minimalist"],
            budget_amount=15000.0,
            budget_currency="MYR",
            free_text="Keep sofa. Refinish floor to light oak.",
        )

        # 4. Redesign Generation
        t1 = time.time()
        gen_res = generator.generate_redesigns(img, room, constraints, count=3)
        gen_latency = (time.time() - t1) * 1000.0

        version = gen_res.data
        avg_preservation = float(np.mean([v.structural_preservation_score for v in version.variants]))

        record = {
            "test_case_id": tc["id"],
            "name": tc["name"],
            "quality_passed": qr.passed,
            "blur_score": qr.blur_score,
            "exposure_mean": qr.exposure_mean,
            "detected_surfaces": len(room.surfaces),
            "detected_openings": len(room.openings),
            "detected_objects": len(room.objects),
            "generated_variants": len(version.variants),
            "avg_structural_preservation": round(avg_preservation, 3),
            "analysis_latency_ms": round(analysis_latency, 2),
            "generation_latency_ms": round(gen_latency, 2),
            "cost_usd": version.estimated_cost_usd,
            "model_version": version.model_version,
            "exit_criteria_satisfied": avg_preservation >= 0.90 and qr.passed,
        }
        results.append(record)

    total_duration = time.time() - total_start

    # Summary report
    print("\n" + "=" * 70)
    print("BENCHMARK RESULTS SUMMARY")
    print("=" * 70)
    print(f"{'Case ID':<8} | {'Quality':<8} | {'Surfaces':<8} | {'Objects':<8} | {'Preservation':<12} | {'Latency':<10} | {'Status'}")
    print("-" * 70)
    all_passed = True
    for r in results:
        status_str = "PASS [OK]" if r["exit_criteria_satisfied"] else "FAIL [X]"
        if not r["exit_criteria_satisfied"]:
            all_passed = False
        print(f"{r['test_case_id']:<8} | {str(r['quality_passed']):<8} | {r['detected_surfaces']:<8} | {r['detected_objects']:<8} | {r['avg_structural_preservation']*100:.1f}%        | {r['generation_latency_ms']:<8.0f}ms | {status_str}")

    print("-" * 70)
    print(f"Total Benchmark Suite Duration: {total_duration:.2f}s")
    print(f"Overall Benchmark Status: {'ALL EXIT CRITERIA PASSED' if all_passed else 'SOME CRITERIA FAILED'}")
    print("=" * 70)

    # Save to JSON
    out_dir = "docs/ai-evaluation"
    os.makedirs(out_dir, exist_ok=True)
    report_file = os.path.join(out_dir, "latest_benchmark_report.json")
    with open(report_file, "w", encoding="utf-8") as f:
        json.dump({"timestamp": time.strftime("%Y-%m-%d %H:%M:%SZ"), "results": results}, f, indent=2)
    print(f"Detailed benchmark metrics saved to: {report_file}")


if __name__ == "__main__":
    run_benchmark()
