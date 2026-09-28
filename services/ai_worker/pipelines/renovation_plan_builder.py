"""
Renovation Plan Output Builder Pipeline.
Consolidates design selections, spatial geometry, physical takeoffs,
product recommendations, and budget modeling into immutable, versionable renovation briefs.
Fulfills Blueprint Section 41 & Milestone 4.4.
"""

from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
import uuid

from packages.room_model.schema import (
    CanonicalRoomModel,
    CurrencyCode,
    DesignVariant,
    ExecutionPhase,
    MeasurementSource,
    ObjectAction,
    PlanMeasurementItem,
    RenovationPlanVersion,
    RenovationTier,
)


class RenovationPlanBuilder:
    """
    Consolidation engine that converts a room's active state into a versioned,
    comprehensive Renovation Plan Output without duplicating underlying data.
    """

    def generate_plan(
        self,
        room: CanonicalRoomModel,
        selected_variant_id: Optional[str] = None,
        selected_style: Optional[str] = None,
        selected_tier: Optional[RenovationTier] = None,
        currency: Optional[CurrencyCode] = None,
        project_name: Optional[str] = None,
        plan_title: Optional[str] = None,
    ) -> RenovationPlanVersion:
        """
        Synthesizes a new versioned RenovationPlanVersion and attaches it to room.renovation_plans.
        """
        # 1. Versioning
        version_num = len(room.renovation_plans) + 1
        version_tag = f"v{version_num}"
        p_name = project_name or "Interior Renovation Project"
        title = plan_title or f"Renovation Specification Brief ({version_tag})"

        tier = selected_tier or (room.budget_plan.renovation_tier if room.budget_plan else RenovationTier.MODERATE)
        curr = currency or (room.budget_plan.currency if room.budget_plan else CurrencyCode.MYR)
        style = selected_style or "Warm Modern Minimalist"

        # 2. Selected Design
        selected_variant: Optional[DesignVariant] = None
        if selected_variant_id:
            for ver in room.versions:
                for var in ver.variants:
                    if var.variant_id == selected_variant_id:
                        selected_variant = var
                        break
                if selected_variant:
                    break

        if not selected_variant and room.versions:
            # Pick latest favorite or first variant
            for ver in reversed(room.versions):
                for var in ver.variants:
                    if var.is_favorite:
                        selected_variant = var
                        break
                if selected_variant:
                    break
            if not selected_variant and room.versions[-1].variants:
                selected_variant = room.versions[-1].variants[0]

        if selected_variant:
            style = selected_variant.style
            design_dict = {
                "variant_id": selected_variant.variant_id,
                "title": selected_variant.title,
                "style": selected_variant.style,
                "description": selected_variant.description,
                "structural_preservation_score": selected_variant.structural_preservation_score,
                "changes_made": selected_variant.changes_made,
                "image_url": selected_variant.image_url,
            }
        else:
            design_dict = {
                "variant_id": None,
                "title": f"{style} Concept",
                "style": style,
                "description": f"AI-assisted design concept adhering to {style} aesthetic and {tier.value} specification.",
                "structural_preservation_score": 0.92,
                "changes_made": ["Surface refresh", "Furniture replacement", "Lighting modernization"],
                "image_url": room.original_image_url or "",
            }

        # 3. Room Information
        geom = room.geometry
        floor_area = geom.floor_area_sqm or 0.0
        ceil_h = geom.ceiling_height_m or 2.80
        est_w = geom.estimated_width_m or 4.0
        est_l = geom.estimated_length_m or 5.0

        room_info = {
            "room_id": room.id,
            "room_name": room.name,
            "room_type": room.room_type,
            "floor_area_sqm": round(floor_area, 2),
            "ceiling_height_m": round(ceil_h, 2),
            "estimated_width_m": round(est_w, 2),
            "estimated_length_m": round(est_l, 2),
            "room_shape": geom.room_shape.value if hasattr(geom.room_shape, "value") else str(geom.room_shape),
            "loop_closure_status": geom.loop_closure_status.value if hasattr(geom.loop_closure_status, "value") else str(geom.loop_closure_status),
            "surfaces_count": len(room.surfaces),
            "openings_count": len(room.openings),
            "objects_count": len(room.objects),
            "dimensions_summary": f"{round(est_l, 2)}m (L) × {round(est_w, 2)}m (W) × {round(ceil_h, 2)}m (H) · {round(floor_area, 1)} m²",
        }

        # 4. Scope of Work (Retained vs Removed vs Replaced)
        items_retain = []
        items_remove = []
        items_replace = []
        scope_lines = []

        # Architectural Openings
        for opn in room.openings:
            if opn.action == ObjectAction.KEEP:
                items_retain.append({
                    "id": opn.id,
                    "label": opn.name,
                    "category": "ARCHITECTURAL_OPENING",
                    "action": "KEEP",
                    "rationale": "Preserve existing architectural portal / fenestration",
                })
            elif opn.action == ObjectAction.REPLACE:
                items_replace.append({
                    "id": opn.id,
                    "label": opn.name,
                    "category": "ARCHITECTURAL_OPENING",
                    "action": "REPLACE",
                    "rationale": "Upgrade frame and hardware",
                })

        # Surfaces
        for s in room.surfaces:
            if s.action == ObjectAction.KEEP:
                items_retain.append({
                    "id": s.id,
                    "label": s.name,
                    "category": "SURFACE",
                    "action": "KEEP",
                    "rationale": "Maintain sound existing structural substrate",
                })
            elif s.action in [ObjectAction.REPLACE, ObjectAction.RESTYLE]:
                items_replace.append({
                    "id": s.id,
                    "label": s.name,
                    "category": "SURFACE",
                    "action": s.action.value,
                    "rationale": f"Refinish/retile surface according to {style} palette",
                })

        # Objects / Furniture
        for obj in room.objects:
            if obj.action == ObjectAction.KEEP:
                # Check if there is savings in budget plan tradeoffs
                savings = 0.0
                if room.budget_plan:
                    for t in room.budget_plan.tradeoffs:
                        if t.element_id == obj.id:
                            savings = t.savings_if_kept
                            break
                items_retain.append({
                    "id": obj.id,
                    "label": obj.name,
                    "category": "FURNITURE",
                    "action": "KEEP",
                    "rationale": "Existing anchor item preserved by homeowner",
                    "savings_if_kept": savings,
                })
            elif obj.action == ObjectAction.REMOVE:
                items_remove.append({
                    "id": obj.id,
                    "label": obj.name,
                    "category": "FURNITURE",
                    "action": "REMOVE",
                    "rationale": "Decommission and clear footprint for circulation",
                })
            elif obj.action in [ObjectAction.REPLACE, ObjectAction.RESTYLE]:
                items_replace.append({
                    "id": obj.id,
                    "label": obj.name,
                    "category": "FURNITURE",
                    "action": obj.action.value,
                    "rationale": "Replace with spatially verified catalog item",
                })

        if items_remove:
            scope_lines.append(f"Demolition & Removal: Strip out {len(items_remove)} redundant item(s) to optimize spatial flow.")
        if items_retain:
            scope_lines.append(f"Preservation: Protect and retain {len(items_retain)} structural and furniture item(s).")
        if items_replace:
            scope_lines.append(f"Renovation & Finishes: Upgrade and restyle {len(items_replace)} element(s) with durable materials.")
        scope_lines.append(f"MEP & Electrical: Inspect lighting circuits and service rough-ins for new design scheme.")
        scope_lines.append(f"Procurement: Source curated furniture satisfying circulation walkway clearances.")

        # 5. Materials and Quantities Takeoff Summary
        takeoff_dict = None
        if room.material_takeoff:
            t = room.material_takeoff
            takeoff_dict = {
                "report_id": t.report_id,
                "accuracy_tier": t.accuracy_tier,
                "gross_floor_area_sqm": t.gross_floor_area_sqm,
                "net_wall_area_sqm": t.net_wall_area_sqm,
                "ceiling_area_sqm": t.ceiling_area_sqm,
                "baseboard_perimeter_m": t.baseboard_perimeter_m,
                "openings_deducted_area_sqm": t.openings_deducted_area_sqm,
                "default_waste_factors": t.default_waste_factors,
                "items": [
                    {
                        "category": item.category.value if hasattr(item.category, "value") else str(item.category),
                        "material_name": getattr(item, "material_name", getattr(item, "name", "Unnamed Material")),
                        "net_quantity": getattr(item, "net_quantity", 0.0),
                        "waste_factor_pct": getattr(item, "waste_factor_pct", 0.0),
                        "recommended_order_quantity": getattr(item, "recommended_order_quantity", getattr(item, "gross_quantity", 0.0)),
                        "unit": getattr(item, "unit", "units"),
                        "package_spec": getattr(item, "package_spec", getattr(item, "packaging_spec", None)),
                        "packages_needed": getattr(item, "packages_needed", getattr(item, "estimated_packages", None)),
                        "uncertainty_margin_pct": getattr(item, "uncertainty_margin_pct", getattr(item, "uncertainty_pct", 0.0)),
                        "min_order_quantity": getattr(item, "min_order_quantity", getattr(item, "min_recommended_quantity", 0.0)),
                        "max_order_quantity": getattr(item, "max_order_quantity", getattr(item, "max_recommended_quantity", 0.0)),
                    }
                    for item in t.items
                ],
            }

        # 6. Furniture & Product Recommendations Summary
        products_list = []
        if room.product_recommendations:
            for rec in room.product_recommendations.recommendations:
                p = rec.product
                products_list.append({
                    "product_id": p.id,
                    "sku": p.sku,
                    "name": p.name,
                    "brand": p.brand,
                    "category": p.category.value if hasattr(p.category, "value") else str(p.category),
                    "fit_status": rec.fit_status.value if hasattr(rec.fit_status, "value") else str(rec.fit_status),
                    "fit_notes": rec.fit_notes,
                    "dimensions": f"{p.dimensions.width_m:.2f}m (W) × {p.dimensions.depth_m:.2f}m (D) × {p.dimensions.height_m:.2f}m (H)",
                    "target_element_label": rec.target_element_label,
                    "price": p.price,
                    "currency": p.currency.value if hasattr(p.currency, "value") else str(p.currency),
                    "retailer": p.retailer,
                    "retailer_url": p.retailer_url,
                    "lead_time_days": p.lead_time_days,
                    "is_assigned": rec.is_assigned,
                    "budget_status": rec.budget_status,
                })

        # 7. Budget Summary
        budget_dict = None
        if room.budget_plan:
            b = room.budget_plan
            budget_dict = {
                "plan_id": b.plan_id,
                "total_budget": b.total_budget,
                "currency": b.currency.value if hasattr(b.currency, "value") else str(b.currency),
                "renovation_tier": b.renovation_tier.value if hasattr(b.renovation_tier, "value") else str(b.renovation_tier),
                "total_estimated_cost": b.total_estimated_cost,
                "subtotal_materials": b.subtotal_materials,
                "subtotal_labor": b.subtotal_labor,
                "contingency_pct": b.contingency_pct,
                "contingency_amount": b.contingency_amount,
                "tax_name": b.tax_name,
                "tax_rate_pct": b.tax_rate_pct,
                "tax_amount": b.tax_amount,
                "grand_total": b.grand_total,
                "savings_from_kept_items": b.savings_from_kept_items,
                "remaining_budget": b.remaining_budget,
                "is_within_budget": b.is_within_budget,
                "allocated_items": [
                    {
                        "category_name": item.category_name,
                        "estimated_cost": item.estimated_cost,
                        "material_cost": item.material_cost,
                        "labor_cost": item.labor_cost,
                        "trade_name": item.trade_name,
                        "is_over_budget": item.is_over_budget,
                    }
                    for item in b.allocated_items
                ],
                "scenarios": [
                    {
                        "tier": s.tier.value if hasattr(s.tier, "value") else str(s.tier),
                        "tier_name": s.tier_name,
                        "grand_total_estimated": s.grand_total_estimated,
                        "is_within_budget": s.is_within_budget,
                    }
                    for s in b.scenarios
                ],
            }

        # 8. Measurement Confidence & Safety Demarcation
        meas_items: List[PlanMeasurementItem] = []
        unverified_count = 0
        confirmed_count = 0

        for m in room.measurements:
            is_conf = (
                m.verified_by_user
                or m.source in [MeasurementSource.USER_VERIFIED, MeasurementSource.LIDAR_NATIVE]
                or m.accuracy_tier == "EXACT"
            )
            req_ver = not is_conf

            if is_conf:
                confirmed_count += 1
            else:
                unverified_count += 1

            source_str = m.source.value if hasattr(m.source, "value") else str(m.source)
            meas_items.append(
                PlanMeasurementItem(
                    label=getattr(m, "name", None) or f"{m.entity_type.capitalize()} {m.measurement_type}",
                    value=round(m.value, 2),
                    unit=m.unit,
                    source=source_str,
                    confidence=round(m.confidence, 2),
                    is_confirmed=is_conf,
                    requires_manual_verification=req_ver,
                )
            )

        confidence_dict = {
            "overall_confidence": round(room.overall_confidence, 2),
            "total_measurements": len(meas_items),
            "confirmed_measurements_count": confirmed_count,
            "unverified_measurements_count": unverified_count,
            "measurements": [mi.model_dump() for mi in meas_items],
        }

        # 9. Assumptions
        assumptions = [
            "Existing subfloor substrate is level, dry, and structurally sound for finish overlay.",
            "Ceiling electrical junction boxes and switch legs are operational and adhere to code.",
            "Elevator and doorway access dimensions allow delivery of largest furniture packages.",
            "Work to be performed during standard residential renovation hours without overtime rates.",
            "Contractor will provide protective coverings for all retained architectural openings and items.",
        ]

        # 10. Warnings and Verifications
        warnings = []
        if unverified_count > 0:
            warnings.append(
                f"Measurement Uncertainty: {unverified_count} room dimension(s) remain unverified on site. "
                "Must be confirmed with a physical laser distance meter before custom millwork fabrication."
            )

        if room.feasibility_report and not room.feasibility_report.overall_feasible:
            for chk in room.feasibility_report.checks:
                if not chk.passed:
                    warnings.append(f"Spatial Feasibility: {chk.message}")

        if room.product_recommendations:
            for rec in room.product_recommendations.recommendations:
                if rec.fit_status.value in ["TIGHT_FIT", "CLEARANCE_WARNING", "OVERSIZED"]:
                    warnings.append(f"Furniture Clearance ({rec.product.name}): {rec.fit_notes}")

        # 11. Advisory Execution Sequence (11 Standard Steps)
        execution_sequence = [
            ExecutionPhase(
                phase_number=1,
                title="Site Preparation & Protection",
                description="Erect dust screens, lay heavy-duty floor protection over retained flooring, and mask preserved portals.",
                advisory_notes="Document pre-construction site condition with dated photographs.",
            ),
            ExecutionPhase(
                phase_number=2,
                title="Demolition & Element Removal",
                description="Carefully dismantle and dispose of flagged items marked for removal without disturbing structural anchors.",
                advisory_notes="Confirm disconnection of power/water services before dismantling built-in units.",
            ),
            ExecutionPhase(
                phase_number=3,
                title="Rough-in Mechanical, Electrical & Plumbing",
                description="Relocate power points, data drops, and luminaire feed wires according to revised lighting plan.",
                advisory_notes="Safety Critical: All electrical and plumbing modifications require licensed trade sign-off.",
                is_safety_critical=True,
            ),
            ExecutionPhase(
                phase_number=4,
                title="Substrate Preparation & Drywalling",
                description="Skim-coat walls, repair plaster cracks, and install framing or acoustic backing if required.",
                advisory_notes="Allow primer and compounds to fully cure before finish application.",
            ),
            ExecutionPhase(
                phase_number=5,
                title="Surface Finishes (Flooring & Tiling)",
                description="Install verified floor finishes (engineered oak, vinyl, or large-format tile) including underlayment.",
                advisory_notes="Verify expansion gaps around room perimeter prior to baseboard installation.",
            ),
            ExecutionPhase(
                phase_number=6,
                title="Custom Cabinetry & Built-in Millwork",
                description="Deliver and install custom storage units, TV credenzas, and decorative wall paneling.",
                advisory_notes="Check laser level against true vertical before securing anchor screws.",
            ),
            ExecutionPhase(
                phase_number=7,
                title="Architectural Painting & Ceiling Finishes",
                description="Apply specified low-VOC emulsion paint coats to ceilings, feature walls, and baseboard trims.",
                advisory_notes="Inspect surface uniformity under both natural daylight and warm artificial lighting.",
            ),
            ExecutionPhase(
                phase_number=8,
                title="Electrical Trim-out & Lighting Fixtures",
                description="Hang pendant fixtures, mount recessed architectural spotlights, and install switch plates.",
                advisory_notes="Safety Critical: Perform insulation resistance and circuit polarity tests.",
                is_safety_critical=True,
            ),
            ExecutionPhase(
                phase_number=9,
                title="Primary Furniture Placement & Spatial Clearance",
                description="Position sofa, coffee table, and anchor furniture pieces as mapped in the spatial fit evaluation.",
                advisory_notes="Confirm 0.60m walkway clearance is preserved around primary seating areas.",
            ),
            ExecutionPhase(
                phase_number=10,
                title="Soft Furnishings & Accent Decoration",
                description="Lay area rugs, hang tailored window treatments, and place curated decorative accessories.",
                advisory_notes="Anchor heavy mirrors or tall shelving units to wall studs for seismic and child safety.",
            ),
            ExecutionPhase(
                phase_number=11,
                title="Final Contractor Punch-List & Handover",
                description="Joint walkthrough between homeowner and contractor to inspect finishes, rectify blemishes, and sign off.",
                advisory_notes="Verify that all appliance warranties and material maintenance guides are transferred.",
            ),
        ]

        # 12. Project Summary text
        proj_summary = (
            f"Comprehensive renovation specification for {room.name} ({room_info['dimensions_summary']}) "
            f"under the {style} aesthetic and {tier.value} finish tier. "
            f"Consolidates {len(items_retain)} retained item(s), {len(items_replace)} replacement(s), "
            f"and {len(items_remove)} removal(s). Includes contractor material quantities, "
            f"spatially verified catalogue items, and multi-tier budget modeling."
        )

        # 13. Construct Plan Instance
        plan = RenovationPlanVersion(
            plan_id=f"plan_{uuid.uuid4().hex[:8]}",
            room_id=room.id,
            project_id=room.project_id,
            version_number=version_num,
            version_tag=version_tag,
            title=title,
            created_at=datetime.now(timezone.utc),
            selected_variant_id=selected_variant.variant_id if selected_variant else None,
            selected_variant_title=selected_variant.title if selected_variant else None,
            selected_style=style,
            selected_tier=tier,
            currency=curr,
            project_summary=proj_summary,
            room_information=room_info,
            selected_design=design_dict,
            scope_of_work=scope_lines,
            items_to_retain=items_retain,
            items_to_remove=items_remove,
            items_to_replace=items_replace,
            materials_and_quantities=takeoff_dict,
            product_recommendations=products_list,
            budget_estimate=budget_dict,
            measurement_confidence=confidence_dict,
            assumptions=assumptions,
            warnings_and_verifications=warnings,
            execution_sequence=execution_sequence,
        )

        # Build Markdown Export
        plan.export_markdown = self.generate_markdown_brief(plan, room)

        # Append to room history
        room.renovation_plans.append(plan)
        return plan

    def generate_markdown_brief(self, plan: RenovationPlanVersion, room: CanonicalRoomModel) -> str:
        """
        Generates a clean, professional contractor handover brief in Markdown format,
        ready for printing, PDF conversion, or sharing.
        """
        curr_symbol = "$"
        if plan.currency == CurrencyCode.MYR:
            curr_symbol = "RM"
        elif plan.currency == CurrencyCode.SGD:
            curr_symbol = "S$"
        elif plan.currency == CurrencyCode.EUR:
            curr_symbol = "€"
        elif plan.currency == CurrencyCode.GBP:
            curr_symbol = "£"
        elif plan.currency == CurrencyCode.AUD:
            curr_symbol = "A$"
        elif plan.currency == CurrencyCode.CAD:
            curr_symbol = "C$"

        lines = [
            f"# {plan.title}",
            f"**Version:** {plan.version_tag} | **Generated:** {plan.created_at.strftime('%Y-%m-%d %H:%M:%S UTC')}",
            f"**Room:** {room.name} ({room.room_type}) | **Aesthetic Style:** {plan.selected_style} | **Tier:** {plan.selected_tier.value}",
            "",
            "---",
            "",
            "## 1. Project Summary",
            plan.project_summary,
            "",
            "## 2. Room Dimensions & Architectural Information",
            f"- **Floor Area:** {plan.room_information.get('floor_area_sqm', 0.0)} m²",
            f"- **Ceiling Height:** {plan.room_information.get('ceiling_height_m', 0.0)} m",
            f"- **Estimated Dimensions:** {plan.room_information.get('dimensions_summary', 'N/A')}",
            f"- **Room Geometry Shape:** {plan.room_information.get('room_shape', 'RECTANGULAR')}",
            f"- **Wall Segments:** {len(room.geometry.wall_segments)} walls | **Openings:** {plan.room_information.get('openings_count', 0)}",
            "",
            "## 3. Selected Design Concept",
            f"- **Concept Title:** {plan.selected_design.get('title', 'N/A')}",
            f"- **Description:** {plan.selected_design.get('description', '')}",
            f"- **Structural Preservation Score:** {(plan.selected_design.get('structural_preservation_score', 0.92) * 100):.1f}%",
            "",
            "## 4. Scope of Work",
        ]
        for s in plan.scope_of_work:
            lines.append(f"- {s}")
        lines.append("")

        lines.append("## 5. Existing Items to Retain")
        if plan.items_to_retain:
            for item in plan.items_to_retain:
                sav = f" (Saved {curr_symbol} {item['savings_if_kept']:.0f})" if item.get("savings_if_kept") else ""
                lines.append(f"- **{item['label']}** [{item['category']}]: {item.get('rationale', 'Retained')}{sav}")
        else:
            lines.append("- No existing elements designated for retention.")
        lines.append("")

        lines.append("## 6. Items to Remove or Replace")
        if plan.items_to_remove:
            lines.append("### Items for Removal & Demolition:")
            for item in plan.items_to_remove:
                lines.append(f"- **{item['label']}** [{item['category']}]: {item.get('rationale', 'Removal')}")
        if plan.items_to_replace:
            lines.append("### Items for Replacement & Refinishing:")
            for item in plan.items_to_replace:
                lines.append(f"- **{item['label']}** [{item['category']}]: {item.get('rationale', 'Replacement')}")
        lines.append("")

        lines.append("## 7. Materials and Quantity Estimation (Takeoff)")
        if plan.materials_and_quantities:
            mq = plan.materials_and_quantities
            lines.append(f"- **Gross Floor Area:** {mq.get('gross_floor_area_sqm', 0.0):.1f} m²")
            lines.append(f"- **Net Wall Area:** {mq.get('net_wall_area_sqm', 0.0):.1f} m² (Openings deducted: {mq.get('openings_deducted_area_sqm', 0.0):.1f} m²)")
            lines.append(f"- **Baseboard Run:** {mq.get('baseboard_perimeter_m', 0.0):.1f} m")
            lines.append("")
            lines.append("| Category | Material | Net Qty | Waste % | Rec. Order Qty | Unit | Packages |")
            lines.append("|---|---|---|---|---|---|---|")
            for it in mq.get("items", []):
                lines.append(
                    f"| {it['category']} | {it['material_name']} | {it['net_quantity']:.1f} | "
                    f"{it['waste_factor_pct']:.0f}% | **{it['recommended_order_quantity']:.1f}** | "
                    f"{it['unit']} | {it.get('packages_needed', '-')} |"
                )
        else:
            lines.append("- Standard takeoff baseline derived from room geometry bounds.")
        lines.append("")

        lines.append("## 8. Furniture & Product Recommendations")
        if plan.product_recommendations:
            lines.append("| Target | Product | Brand | Dimensions | Clearance Fit | Price | Retailer | Lead Time |")
            lines.append("|---|---|---|---|---|---|---|---|")
            for p in plan.product_recommendations:
                tag = " (Assigned)" if p.get("is_assigned") else ""
                lines.append(
                    f"| {p.get('target_element_label', 'Placement')} | **{p['name']}**{tag} | {p['brand']} | "
                    f"{p['dimensions']} | {p['fit_status']} | {curr_symbol} {p['price']:.0f} | "
                    f"{p['retailer']} | {p['lead_time_days']}d |"
                )
        else:
            lines.append("- No catalogue items attached to this plan version.")
        lines.append("")

        lines.append("## 9. Budget & Cost Breakdown")
        if plan.budget_estimate:
            be = plan.budget_estimate
            lines.append(f"- **Total Target Budget:** {curr_symbol} {be.get('total_budget', 0.0):,.0f}")
            lines.append(f"- **Materials Subtotal:** {curr_symbol} {be.get('subtotal_materials', 0.0):,.0f}")
            lines.append(f"- **Labor Subtotal:** {curr_symbol} {be.get('subtotal_labor', 0.0):,.0f}")
            lines.append(f"- **Contingency Reserve ({be.get('contingency_pct', 10):.0f}%):** {curr_symbol} {be.get('contingency_amount', 0.0):,.0f}")
            lines.append(f"- **Statutory Tax ({be.get('tax_name', 'Tax')} {be.get('tax_rate_pct', 0.0):.1f}%):** {curr_symbol} {be.get('tax_amount', 0.0):,.0f}")
            lines.append(f"- **Grand Total Estimated:** **{curr_symbol} {be.get('grand_total', 0.0):,.0f}**")
            lines.append(f"- **Budget Status:** {'WITHIN BUDGET' if be.get('is_within_budget') else 'OVER BUDGET'}")
        lines.append("")

        lines.append("## 10. Measurement Confidence & Provenance")
        mc = plan.measurement_confidence
        lines.append(f"- **Overall Geometric Confidence:** {(mc.get('overall_confidence', 0.88) * 100):.1f}%")
        lines.append(f"- **Confirmed Dimensions:** {mc.get('confirmed_measurements_count', 0)} | **Unverified Dimensions:** {mc.get('unverified_measurements_count', 0)}")
        lines.append("")
        lines.append("| Measurement | Value | Source Provenance | Confidence | Status | Action Required |")
        lines.append("|---|---|---|---|---|---|")
        for m in mc.get("measurements", []):
            st = "CONFIRMED" if m.get("is_confirmed") else "ESTIMATED"
            act = "Physical tape check required" if m.get("requires_manual_verification") else "Ready for trade use"
            lines.append(
                f"| {m['label']} | {m['value']:.2f} {m['unit']} | {m['source']} | "
                f"{(m['confidence'] * 100):.0f}% | {st} | {act} |"
            )
        lines.append("")

        lines.append("## 11. Operational Assumptions")
        for a in plan.assumptions:
            lines.append(f"- {a}")
        lines.append("")

        lines.append("## 12. Warnings & Critical Verifications")
        for w in plan.warnings_and_verifications:
            lines.append(f"- ⚠️ {w}")
        lines.append("")
        lines.append(f"> **Important Regulatory Notice:** {plan.safety_critical_disclaimer}")
        lines.append("")

        lines.append("## 13. Suggested Advisory Execution Sequence")
        for phase in plan.execution_sequence:
            crit = " [SAFETY CRITICAL]" if phase.is_safety_critical else ""
            lines.append(f"### Phase {phase.phase_number}: {phase.title}{crit}")
            lines.append(f"{phase.description}")
            if phase.advisory_notes:
                lines.append(f"*Note: {phase.advisory_notes}*")
            lines.append("")

        return "\n".join(lines)


# Global singleton instance
renovation_plan_builder = RenovationPlanBuilder()
