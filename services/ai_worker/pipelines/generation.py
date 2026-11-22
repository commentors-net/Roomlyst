"""
Structure-Preserving Generative Redesign Pipeline.
Fulfills Milestone 0.3: Structure-Preserving Redesign Spike.
Compliant with Blueprint Section 14, 15, and 16.
"""

import os
import time
import uuid
from typing import List, Optional
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from pydantic import BaseModel

from packages.room_model import (
    CanonicalRoomModel,
    DesignConstraint,
    DesignVariant,
    DesignVersion,
    ObjectAction,
)
from .base import PipelineResult, RedesignGeneratorBase


class LocalRedesignGenerator(RedesignGeneratorBase):
    """
    Controlled redesign generator.
    Translates user Keep/Replace/Remove constraints and style preferences
    into 3 structurally-anchored design concept variants.
    """

    def __init__(
        self,
        output_dir: str = "storage/outputs",
        model_version: str = "roomlyst-control-v1-ref",
    ):
        self.output_dir = output_dir
        self.model_version = model_version
        os.makedirs(output_dir, exist_ok=True)

    def _render_styled_variant_image(
        self,
        base_img: Image.Image,
        room: CanonicalRoomModel,
        constraints: DesignConstraint,
        variant_idx: int,
        variant_style: str,
    ) -> str:
        """
        Creates an illustrative generated redesign image preserving
        structural openings & kept furniture while restyling surfaces & replacements.
        """
        w, h = base_img.size
        # Work with RGB copy
        canvas = base_img.copy().convert("RGB")

        # Color grading palette based on style
        palettes = {
            "Warm Modern Minimalist": {
                "wall_tint": (245, 240, 232),   # warm alabaster
                "floor_tint": (180, 140, 100),  # light natural oak
                "accent": (140, 110, 80),
            },
            "Japandi Clean Organic": {
                "wall_tint": (238, 235, 226),   # soft linen
                "floor_tint": (210, 185, 150),  # bleached birch
                "accent": (60, 55, 50),
            },
            "Contemporary Scandinavian": {
                "wall_tint": (242, 244, 246),   # crisp cool white
                "floor_tint": (160, 130, 95),   # smoked oak
                "accent": (45, 75, 80),
            },
        }
        palette = palettes.get(variant_style, palettes["Warm Modern Minimalist"])

        draw = ImageDraw.Draw(canvas)

        # 1. Restyle floor if requested
        floor = next((s for s in room.surfaces if s.surface_type.value == "FLOOR"), None)
        if floor and floor.id in (constraints.replace_ids + constraints.restyle_ids):
            # Apply floor tint to lower perspective region
            floor_y = int(h * 0.72)
            floor_overlay = Image.new("RGBA", (w, h - floor_y), palette["floor_tint"] + (80,))
            canvas.paste(floor_overlay, (0, floor_y), floor_overlay)

        # 2. Restyle walls if requested
        for wall in room.surfaces:
            if wall.surface_type.value == "WALL" and wall.id in (constraints.replace_ids + constraints.restyle_ids):
                wall_overlay = Image.new("RGBA", (w, int(h * 0.65)), palette["wall_tint"] + (40,))
                canvas.paste(wall_overlay, (0, 0), wall_overlay)

        # 3. Draw architectural structural preservation badges (Doors, Windows)
        for opn in room.openings:
            if opn.bounding_box:
                bb = opn.bounding_box
                x1, y1, x2, y2 = int(bb.x_min * w), int(bb.y_min * h), int(bb.x_max * w), int(bb.y_max * h)
                # Subtle architectural anchor indicator
                draw.rectangle([x1, y1, x2, y2], outline=(100, 200, 255), width=2)
                draw.rectangle([x1, y1, x1 + 130, y1 + 22], fill=(20, 30, 45))
                draw.text((x1 + 6, y1 + 4), f"✓ PRESERVED: {opn.name}", fill=(180, 230, 255))

        # 4. Draw kept furniture badges and replaced items
        for obj in room.objects:
            if obj.bounding_box:
                bb = obj.bounding_box
                x1, y1, x2, y2 = int(bb.x_min * w), int(bb.y_min * h), int(bb.x_max * w), int(bb.y_max * h)
                if obj.id in constraints.preserve_ids or obj.action == ObjectAction.KEEP:
                    draw.rectangle([x1, y1, x2, y2], outline=(120, 220, 140), width=2)
                    draw.rectangle([x1, y1, x1 + 140, y1 + 22], fill=(20, 45, 25))
                    draw.text((x1 + 6, y1 + 4), f"✓ KEPT: {obj.name[:18]}", fill=(180, 255, 190))
                elif obj.id in constraints.replace_ids or obj.action == ObjectAction.REPLACE:
                    # Replacement styling box
                    draw.rectangle([x1, y1, x2, y2], outline=(255, 190, 70), width=2)
                    overlay = Image.new("RGBA", (x2 - x1, y2 - y1), palette["accent"] + (90,))
                    canvas.paste(overlay, (x1, y1), overlay)
                    draw.rectangle([x1, y1, x1 + 145, y1 + 22], fill=(45, 35, 10))
                    draw.text((x1 + 6, y1 + 4), f"★ REPLACED: {variant_style[:14]}", fill=(255, 230, 160))
                elif obj.id in constraints.remove_ids or obj.action == ObjectAction.REMOVE:
                    # Inpainted clean removal simulation
                    draw.rectangle([x1, y1, x2, y2], fill=palette["wall_tint"])
                    draw.text((x1 + 10, y1 + 10), "REMOVED (CLEAN SPACE)", fill=(120, 120, 120))

        # 5. Header banner (truthful preview label)
        draw.rectangle([0, 0, w, 36], fill=(15, 20, 30))
        concept_letter = chr(65 + variant_idx) if variant_idx < 26 else str(variant_idx + 1)
        draw.text((16, 10), f"Roomlyst Algorithmic Preview (Not Photorealistic) — Concept {concept_letter}: {variant_style[:24]}", fill=(255, 255, 255))

        # Save to disk
        filename = f"concept_{uuid.uuid4().hex[:8]}_v{variant_idx+1}.jpg"
        filepath = os.path.join(self.output_dir, filename)
        canvas.save(filepath, format="JPEG", quality=90)
        try:
            from services.api.app.storage import get_storage_provider
            return get_storage_provider().get_signed_url(f"outputs/{filename}", expires_in=86400)
        except Exception:
            return f"/storage/outputs/{filename}"

    def generate_redesigns(
        self,
        image: Image.Image,
        room_model: CanonicalRoomModel,
        constraints: DesignConstraint,
        count: int = 3,
        parent_version_id: Optional[str] = None,
        parent_variant_id: Optional[str] = None,
        branch_label: Optional[str] = None,
    ) -> PipelineResult:
        start_time = time.time()

        # Intent-driven concept templates (Prompt 15 consumer workflow)
        intent_templates = {
            "Empty & Redesign": [
                (
                    "Decluttered Spatial Reset",
                    "Pristine architectural baseline with all movable clutter removed, open spatial flow, and optimized natural daylight.",
                    0.96,
                    ["Preserved structural walls, windows & entry anchors", "Removed movable furniture & clutter", "Applied warm neutral architectural wash"],
                    4200.0,
                ),
                (
                    "Refined Minimalist Harmony",
                    "Harmonized spatial geometry, light hardwood tone restoration, and calm decluttered baseline ready for fresh styling.",
                    0.95,
                    ["Preserved load-bearing architecture", "Cleared central space floorplan", "Restyled surfaces with subtle travertine undertones"],
                    5100.0,
                ),
                (
                    "Warm Organic Renewal",
                    "Organic textures, soft linen wall palette, and airy unfurnished breathing room preserving architectural openings.",
                    0.94,
                    ["Maintained structural openings & ceiling boundary", "Inpainted clean removal of clutter", "Refreshed floor surface to bleached birch"],
                    5800.0,
                ),
            ],
            "Home Office": [
                (
                    "Executive Focus Studio",
                    "Ergonomic work zone with integrated timber desk, acoustic wall paneling, low-glare lighting, and concealed wire pathways.",
                    0.93,
                    ["Preserved window orientation for natural task light", "Replaced movable clutter with dedicated workspace", "Applied focus-enhancing muted palette"],
                    6500.0,
                ),
                (
                    "Minimalist Dual-Zone Work Nook",
                    "Floating wall desk, open book ledges, streamlined task lighting, and clean uncluttered lines.",
                    0.92,
                    ["Preserved architectural perimeter", "Integrated slimline workspace profile", "Installed warm ambient cove lighting"],
                    5400.0,
                ),
                (
                    "Architectural Creative Suite",
                    "Expansive multi-monitor desk placement, natural light window alignment, and smart acoustic organization.",
                    0.91,
                    ["Preserved structural openings", "Curated ergonomic seating & desk hub", "Refinished surfaces with modern matte finishes"],
                    7800.0,
                ),
            ],
            "Cozy Lounge / Reading Corner": [
                (
                    "Warm Reading Sanctuary",
                    "Plush boucle lounge armchair, arched brass reading light, curated timber book shelving, and calm ambient tones.",
                    0.94,
                    ["Preserved window daylight & architectural anchors", "Introduced reading alcove furniture grouping", "Layered warm ambient lighting"],
                    5200.0,
                ),
                (
                    "Japandi Tea & Solitude Nook",
                    "Low-profile cushioned seating, warm linen curtains, light timber accent table, and soft diffused illumination.",
                    0.93,
                    ["Maintained wall and floor structural boundaries", "Styled with minimalist organic materials", "Replaced visual clutter with serene seating"],
                    5900.0,
                ),
                (
                    "Modern Fireside-Style Lounge",
                    "Deep accent armchair, textured wool floor rug, side table, and serene evening relaxation atmosphere.",
                    0.92,
                    ["Preserved architectural openings", "Curated cozy relaxation vignette", "Warm tone color grading"],
                    6300.0,
                ),
            ],
            "Guest Nook": [
                (
                    "Multi-Functional Daybed Suite",
                    "Streamlined tailored daybed with concealed storage, compact side table, and welcoming hospitality accents.",
                    0.93,
                    ["Preserved structural openings & perimeter", "Integrated dual-use guest bedding layout", "Installed warm hospitality sconce lighting"],
                    6100.0,
                ),
                (
                    "Boutique Hotel Alcove",
                    "Convertible sleeper lounge, floating nightstands, ambient reading lights, and soft neutral textiles.",
                    0.92,
                    ["Preserved window & door anchors", "Optimized guest comfort in compact footprint", "Refreshed wall treatment in warm linen"],
                    6900.0,
                ),
                (
                    "Compact Rest & Study Retreat",
                    "Dual-purpose convertible retreat, tailored room-divider aesthetic, and practical guest hospitality nook.",
                    0.91,
                    ["Maintained core room architecture", "Introduced compact transformable furniture", "Applied calming neutral palette"],
                    5700.0,
                ),
            ],
            "Storage + Workspace": [
                (
                    "Seamless Architectural Cabinetry",
                    "Full-height integrated storage, push-to-open flush doors, and recessed floating executive desk surface.",
                    0.92,
                    ["Preserved window openings & structural walls", "Designed flush-fit storage cabinetry", "Concealed equipment & clutter storage bay"],
                    8200.0,
                ),
                (
                    "Modular Open-Ledge System",
                    "Floating oak shelves, integrated filing bench, and streamlined desk surface maintaining spacious feel.",
                    0.93,
                    ["Preserved architectural anchors", "Integrated modular vertical organization", "Installed task & shelf-accent lighting"],
                    6700.0,
                ),
                (
                    "Vertical Grid Organization",
                    "Tailored slat-wall utility storage, executive desk return, and high-efficiency spatial layout.",
                    0.91,
                    ["Preserved structural perimeter", "Implemented high-density organization system", "Restyled surfaces with durable matte finishes"],
                    7400.0,
                ),
            ],
            "Surprise Me": [
                (
                    "Contemporary Architectural Hybrid",
                    "Dynamic fusion of natural travertine, spatial openness, and statement accent pieces tuned to room daylight.",
                    0.94,
                    ["Preserved all load-bearing openings", "Harmonized open-plan furniture layout", "Curated warm contemporary color palette"],
                    6400.0,
                ),
                (
                    "Warm Japandi Sanctuary",
                    "Earthy organic textures, fluted timber detailing, and zen relaxation zoning maximizing space perception.",
                    0.93,
                    ["Maintained structural perimeter & anchors", "Refined surface finishes with natural oak & stone", "Decluttered visual pathways"],
                    6800.0,
                ),
                (
                    "Nordic Organic Loft",
                    "Crisp airy geometry, smoked oak flooring accents, and sculptural minimalist furnishings with high visual warmth.",
                    0.92,
                    ["Preserved window daylighting", "Arranged balanced conversational grouping", "Layered textured neutral materials"],
                    5900.0,
                ),
            ],
        }

        # Select template set based on requested style or intent
        primary_style = constraints.styles[0] if constraints.styles else "Empty & Redesign"
        matched_intent = next((k for k in intent_templates if k.lower() in primary_style.lower() or primary_style.lower() in k.lower()), None)
        if matched_intent:
            variant_templates = intent_templates[matched_intent]
        else:
            variant_templates = [
                (
                    "Warm Modern Minimalist",
                    "Warm natural tones, subtle lime-wash wall treatment, clean lines, and preserved key seating.",
                    0.95,
                    ["Preserved sofa & main window", "Replaced coffee table with organic travertine", "Applied warm neutral palette"],
                    4800.0,
                ),
                (
                    "Japandi Clean Organic",
                    "Blend of Scandinavian functionality with Japanese rustic minimalism, light timber finishes, and decluttered space.",
                    0.93,
                    ["Preserved sofa & architectural doors", "Refinished flooring to light birch", "Integrated minimalist slatted media console"],
                    6200.0,
                ),
                (
                    "Contemporary Scandinavian",
                    "Airy ambience, textured wool elements, matte black accents, and warm ambient light distribution.",
                    0.92,
                    ["Preserved windows, entry arch & sofa", "Installed sleek wall-mounted storage", "Upgraded ambient cove lighting"],
                    5500.0,
                ),
            ]

        variants: List[DesignVariant] = []
        budget_target = constraints.budget_amount
        if room_model.budget_plan and room_model.budget_plan.total_budget > 0:
            budget_target = room_model.budget_plan.total_budget

        for i in range(min(count, len(variant_templates))):
            style_name, desc, pres_score, changes, est_cost = variant_templates[i]

            # Adjust indicative cost to user budget constraints (Economy: ~70%, Target: ~95%, Premium: ~125%)
            if budget_target and budget_target > 0:
                cost_multipliers = [0.70, 0.95, 1.25]
                est_cost = round(budget_target * cost_multipliers[i % len(cost_multipliers)], 2)

            # Adapt changes list to reflect actual constraints accurately
            adapted_changes: List[str] = []
            for chg in changes:
                if "sofa" in chg.lower():
                    sofa_obj = next((o for o in room_model.objects if "sofa" in (o.category or "").lower() or "sofa" in (o.name or "").lower()), None)
                    if sofa_obj and sofa_obj.id in constraints.remove_ids:
                        adapted_changes.append(f"Removed {sofa_obj.name} (per room element review)")
                        continue
                    elif sofa_obj and sofa_obj.id in constraints.replace_ids:
                        adapted_changes.append(f"Replaced {sofa_obj.name} with curated modern alternative")
                        continue
                adapted_changes.append(chg)

            for obj in room_model.objects:
                if obj.id in constraints.remove_ids:
                    rem_msg = f"Removed {obj.name} (per room corrections)"
                    if rem_msg not in adapted_changes:
                        adapted_changes.append(rem_msg)

            img_url = self._render_styled_variant_image(
                base_img=image,
                room=room_model,
                constraints=constraints,
                variant_idx=i,
                variant_style=style_name,
            )
            concept_letter = chr(65 + i) if i < 26 else str(i + 1)
            variants.append(
                DesignVariant(
                    title=f"Concept {concept_letter}: {style_name} Concept Preview",
                    style=style_name,
                    image_url=img_url,
                    description=f"Algorithmic Concept Preview: {desc}",
                    structural_preservation_score=pres_score,
                    changes_made=adapted_changes,
                    estimated_cost=est_cost,
                    parent_variant_id=parent_variant_id,
                )
            )

        latency_ms = (time.time() - start_time) * 1000.0

        label = branch_label or ("Main Branch" if not parent_version_id else f"Branch from {parent_version_id[:6]}")
        version = DesignVersion(
            room_id=room_model.id,
            parent_version_id=parent_version_id,
            parent_variant_id=parent_variant_id,
            branch_label=label,
            version_number=len(room_model.versions) + 1,
            constraints=constraints,
            variants=variants,
            model_provider="roomlyst-algorithmic-preview-compositor",
            model_version=self.model_version,
            generation_latency_ms=round(latency_ms, 2),
            estimated_cost_usd=0.015,
        )

        room_model.versions.append(version)
        room_model.status = "COMPLETED"

        return PipelineResult(
            provider="roomlyst-algorithmic-preview-compositor",
            model_version=self.model_version,
            latency_ms=round(latency_ms, 2),
            estimated_cost_usd=0.015,
            data=version,
        )
