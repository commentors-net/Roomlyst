"""
Budget Intelligence and Renovation Cost Estimator Pipeline.
Fulfills Milestone 2.4: Budget-aware redesign & Blueprint Section 34.

Separates:
- Design generation constraints
- Deterministic regional cost estimation
- Regional pricing benchmarks and currency configurations
"""

import math
from typing import Dict, List, Optional, Tuple, Any

from packages.room_model import (
    BudgetCategory,
    BudgetPlan,
    CanonicalRoomModel,
    CategoryCostItem,
    CurrencyCode,
    KeepReplaceTradeoff,
    ObjectAction,
    RenovationTier,
)


class BudgetIntelligenceEngine:
    """
    Estimates renovation costs and generates balanced budget plans
    based on room physical geometry, object actions (Keep/Replace/Remove),
    and regional pricing benchmarks.
    """

    # Currency formatting symbols
    CURRENCY_SYMBOLS: Dict[CurrencyCode, str] = {
        CurrencyCode.MYR: "RM",
        CurrencyCode.SGD: "S$",
        CurrencyCode.USD: "$",
        CurrencyCode.EUR: "€",
        CurrencyCode.GBP: "£",
        CurrencyCode.AUD: "A$",
        CurrencyCode.CAD: "C$",
    }

    # Regional unit rates per category across finish tiers: (Economy, Moderate, Premium, Luxury)
    # Wall painting (per sqm)
    RATES_PAINTING: Dict[CurrencyCode, Dict[RenovationTier, float]] = {
        CurrencyCode.MYR: {RenovationTier.ECONOMY: 16.0, RenovationTier.MODERATE: 28.0, RenovationTier.PREMIUM: 48.0, RenovationTier.LUXURY: 80.0},
        CurrencyCode.SGD: {RenovationTier.ECONOMY: 10.0, RenovationTier.MODERATE: 20.0, RenovationTier.PREMIUM: 38.0, RenovationTier.LUXURY: 65.0},
        CurrencyCode.USD: {RenovationTier.ECONOMY: 15.0, RenovationTier.MODERATE: 30.0, RenovationTier.PREMIUM: 55.0, RenovationTier.LUXURY: 90.0},
        CurrencyCode.EUR: {RenovationTier.ECONOMY: 14.0, RenovationTier.MODERATE: 28.0, RenovationTier.PREMIUM: 50.0, RenovationTier.LUXURY: 85.0},
        CurrencyCode.GBP: {RenovationTier.ECONOMY: 12.0, RenovationTier.MODERATE: 24.0, RenovationTier.PREMIUM: 42.0, RenovationTier.LUXURY: 72.0},
        CurrencyCode.AUD: {RenovationTier.ECONOMY: 18.0, RenovationTier.MODERATE: 35.0, RenovationTier.PREMIUM: 62.0, RenovationTier.LUXURY: 100.0},
        CurrencyCode.CAD: {RenovationTier.ECONOMY: 16.0, RenovationTier.MODERATE: 32.0, RenovationTier.PREMIUM: 58.0, RenovationTier.LUXURY: 95.0},
    }

    # Flooring (per sqm)
    RATES_FLOORING: Dict[CurrencyCode, Dict[RenovationTier, float]] = {
        CurrencyCode.MYR: {RenovationTier.ECONOMY: 65.0, RenovationTier.MODERATE: 120.0, RenovationTier.PREMIUM: 220.0, RenovationTier.LUXURY: 380.0},
        CurrencyCode.SGD: {RenovationTier.ECONOMY: 45.0, RenovationTier.MODERATE: 85.0, RenovationTier.PREMIUM: 160.0, RenovationTier.LUXURY: 280.0},
        CurrencyCode.USD: {RenovationTier.ECONOMY: 50.0, RenovationTier.MODERATE: 100.0, RenovationTier.PREMIUM: 190.0, RenovationTier.LUXURY: 340.0},
        CurrencyCode.EUR: {RenovationTier.ECONOMY: 45.0, RenovationTier.MODERATE: 90.0, RenovationTier.PREMIUM: 170.0, RenovationTier.LUXURY: 310.0},
        CurrencyCode.GBP: {RenovationTier.ECONOMY: 40.0, RenovationTier.MODERATE: 80.0, RenovationTier.PREMIUM: 150.0, RenovationTier.LUXURY: 270.0},
        CurrencyCode.AUD: {RenovationTier.ECONOMY: 60.0, RenovationTier.MODERATE: 115.0, RenovationTier.PREMIUM: 210.0, RenovationTier.LUXURY: 370.0},
        CurrencyCode.CAD: {RenovationTier.ECONOMY: 55.0, RenovationTier.MODERATE: 105.0, RenovationTier.PREMIUM: 195.0, RenovationTier.LUXURY: 350.0},
    }

    # Millwork / Built-in Cabinetry (per linear meter)
    RATES_MILLWORK: Dict[CurrencyCode, Dict[RenovationTier, float]] = {
        CurrencyCode.MYR: {RenovationTier.ECONOMY: 500.0, RenovationTier.MODERATE: 950.0, RenovationTier.PREMIUM: 1800.0, RenovationTier.LUXURY: 3200.0},
        CurrencyCode.SGD: {RenovationTier.ECONOMY: 350.0, RenovationTier.MODERATE: 680.0, RenovationTier.PREMIUM: 1300.0, RenovationTier.LUXURY: 2400.0},
        CurrencyCode.USD: {RenovationTier.ECONOMY: 400.0, RenovationTier.MODERATE: 800.0, RenovationTier.PREMIUM: 1500.0, RenovationTier.LUXURY: 2800.0},
        CurrencyCode.EUR: {RenovationTier.ECONOMY: 360.0, RenovationTier.MODERATE: 720.0, RenovationTier.PREMIUM: 1400.0, RenovationTier.LUXURY: 2500.0},
        CurrencyCode.GBP: {RenovationTier.ECONOMY: 320.0, RenovationTier.MODERATE: 650.0, RenovationTier.PREMIUM: 1200.0, RenovationTier.LUXURY: 2200.0},
        CurrencyCode.AUD: {RenovationTier.ECONOMY: 450.0, RenovationTier.MODERATE: 900.0, RenovationTier.PREMIUM: 1700.0, RenovationTier.LUXURY: 3000.0},
        CurrencyCode.CAD: {RenovationTier.ECONOMY: 420.0, RenovationTier.MODERATE: 840.0, RenovationTier.PREMIUM: 1600.0, RenovationTier.LUXURY: 2900.0},
    }

    # Lighting / Electrical allowance (base per room + per sqm multiplier)
    RATES_LIGHTING_BASE: Dict[CurrencyCode, Dict[RenovationTier, float]] = {
        CurrencyCode.MYR: {RenovationTier.ECONOMY: 500.0, RenovationTier.MODERATE: 1200.0, RenovationTier.PREMIUM: 2500.0, RenovationTier.LUXURY: 4800.0},
        CurrencyCode.SGD: {RenovationTier.ECONOMY: 300.0, RenovationTier.MODERATE: 750.0, RenovationTier.PREMIUM: 1600.0, RenovationTier.LUXURY: 3200.0},
        CurrencyCode.USD: {RenovationTier.ECONOMY: 350.0, RenovationTier.MODERATE: 850.0, RenovationTier.PREMIUM: 1800.0, RenovationTier.LUXURY: 3500.0},
        CurrencyCode.EUR: {RenovationTier.ECONOMY: 320.0, RenovationTier.MODERATE: 800.0, RenovationTier.PREMIUM: 1700.0, RenovationTier.LUXURY: 3300.0},
        CurrencyCode.GBP: {RenovationTier.ECONOMY: 280.0, RenovationTier.MODERATE: 700.0, RenovationTier.PREMIUM: 1500.0, RenovationTier.LUXURY: 3000.0},
        CurrencyCode.AUD: {RenovationTier.ECONOMY: 400.0, RenovationTier.MODERATE: 950.0, RenovationTier.PREMIUM: 2000.0, RenovationTier.LUXURY: 3800.0},
        CurrencyCode.CAD: {RenovationTier.ECONOMY: 380.0, RenovationTier.MODERATE: 900.0, RenovationTier.PREMIUM: 1900.0, RenovationTier.LUXURY: 3700.0},
    }

    # Base furniture replacement cost per item type
    FURNITURE_BENCHMARKS: Dict[str, Dict[RenovationTier, float]] = {
        "sofa": {RenovationTier.ECONOMY: 1500.0, RenovationTier.MODERATE: 3500.0, RenovationTier.PREMIUM: 7500.0, RenovationTier.LUXURY: 14000.0},
        "coffee_table": {RenovationTier.ECONOMY: 300.0, RenovationTier.MODERATE: 750.0, RenovationTier.PREMIUM: 1600.0, RenovationTier.LUXURY: 3200.0},
        "tv_unit": {RenovationTier.ECONOMY: 600.0, RenovationTier.MODERATE: 1500.0, RenovationTier.PREMIUM: 3500.0, RenovationTier.LUXURY: 7000.0},
        "dining_table": {RenovationTier.ECONOMY: 800.0, RenovationTier.MODERATE: 2000.0, RenovationTier.PREMIUM: 4500.0, RenovationTier.LUXURY: 8500.0},
        "dining_chair": {RenovationTier.ECONOMY: 150.0, RenovationTier.MODERATE: 350.0, RenovationTier.PREMIUM: 750.0, RenovationTier.LUXURY: 1500.0},
        "bed": {RenovationTier.ECONOMY: 1200.0, RenovationTier.MODERATE: 2800.0, RenovationTier.PREMIUM: 5500.0, RenovationTier.LUXURY: 11000.0},
        "armchair": {RenovationTier.ECONOMY: 450.0, RenovationTier.MODERATE: 1100.0, RenovationTier.PREMIUM: 2400.0, RenovationTier.LUXURY: 4800.0},
        "rug": {RenovationTier.ECONOMY: 250.0, RenovationTier.MODERATE: 600.0, RenovationTier.PREMIUM: 1400.0, RenovationTier.LUXURY: 3000.0},
        "bookshelf": {RenovationTier.ECONOMY: 400.0, RenovationTier.MODERATE: 950.0, RenovationTier.PREMIUM: 2200.0, RenovationTier.LUXURY: 4500.0},
        "default": {RenovationTier.ECONOMY: 400.0, RenovationTier.MODERATE: 900.0, RenovationTier.PREMIUM: 2000.0, RenovationTier.LUXURY: 4000.0},
    }

    # Currency exchange/purchasing power factor relative to MYR baseline for furniture
    CURRENCY_PURCHASING_POWER_RATIO: Dict[CurrencyCode, float] = {
        CurrencyCode.MYR: 1.0,
        CurrencyCode.SGD: 0.45,
        CurrencyCode.USD: 0.50,
        CurrencyCode.EUR: 0.46,
        CurrencyCode.GBP: 0.40,
        CurrencyCode.AUD: 0.65,
        CurrencyCode.CAD: 0.60,
    }

    @classmethod
    def get_benchmarks_overview(cls) -> Dict[str, Any]:
        """Returns regional pricing benchmarks, supported currencies, and tier descriptions."""
        return {
            "supported_currencies": [c.value for c in CurrencyCode],
            "currency_symbols": {c.value: cls.CURRENCY_SYMBOLS[c] for c in CurrencyCode},
            "tiers": [
                {
                    "id": RenovationTier.ECONOMY.value,
                    "name": "Economy / Budget Refresh",
                    "description": "Cost-effective DIY materials, off-the-shelf retail furniture, simple coat of paint.",
                },
                {
                    "id": RenovationTier.MODERATE.value,
                    "name": "Moderate / Quality Standard",
                    "description": "Quality commercial laminate flooring, durable washable paints, custom modular millwork.",
                },
                {
                    "id": RenovationTier.PREMIUM.value,
                    "name": "Premium / Designer Grade",
                    "description": "Engineered hardwood flooring, designer feature walls, bespoke cabinetry, premium lighting.",
                },
                {
                    "id": RenovationTier.LUXURY.value,
                    "name": "Luxury / Bespoke Architecture",
                    "description": "Imported Italian porcelain/marble, solid timber architectural joinery, automated cove lighting.",
                },
            ],
            "disclaimer": (
                "Indicative renovation estimates only based on regional material and work benchmarks. "
                "Does not constitute a formal contractor quote, structural engineering sign-off, or commercial guarantee."
            ),
        }

    def extract_room_quantities(self, room: CanonicalRoomModel) -> Dict[str, float]:
        """
        Derives physical renovation work quantities (sqm, linear meters) from room geometry.
        Fulfills Blueprint Section 4 & 34.
        """
        # 1. Floor Area (sqm)
        if room.geometry.floor_area_sqm and room.geometry.floor_area_sqm > 0:
            floor_area = room.geometry.floor_area_sqm
        elif room.geometry.polygon_vertices and len(room.geometry.polygon_vertices) >= 3:
            # Shoelace formula
            v = room.geometry.polygon_vertices
            n = len(v)
            shoelace = sum(v[i].x * v[(i + 1) % n].y - v[(i + 1) % n].x * v[i].y for i in range(n))
            floor_area = abs(shoelace) / 2.0
        elif room.geometry.estimated_width_m and room.geometry.estimated_length_m:
            floor_area = room.geometry.estimated_width_m * room.geometry.estimated_length_m
        else:
            floor_area = 20.0  # reasonable default

        # 2. Ceiling Height (m)
        ceiling_h = room.geometry.ceiling_height_m or 2.80

        # 3. Perimeter & Wall Surface Area (sqm)
        if room.geometry.wall_segments:
            perimeter = sum(w.length_m for w in room.geometry.wall_segments)
            gross_wall_area = sum(w.length_m * (w.height_m or ceiling_h) for w in room.geometry.wall_segments)
        elif room.geometry.perimeter_m and room.geometry.perimeter_m > 0:
            perimeter = room.geometry.perimeter_m
            gross_wall_area = perimeter * ceiling_h
        elif room.geometry.estimated_width_m and room.geometry.estimated_length_m:
            perimeter = 2.0 * (room.geometry.estimated_width_m + room.geometry.estimated_length_m)
            gross_wall_area = perimeter * ceiling_h
        else:
            perimeter = 18.0
            gross_wall_area = perimeter * ceiling_h

        # Deduct openings (windows ~ 2.0 sqm, doors ~ 1.8 sqm)
        deductions = 0.0
        for opn in room.openings:
            if "window" in opn.name.lower():
                deductions += 2.2
            else:
                deductions += 1.8
        net_wall_area = max(10.0, round(gross_wall_area - deductions, 2))

        # 4. Millwork (linear meters) - default or based on cabinetry/tv objects
        cabinet_objects = [o for o in room.objects if any(k in o.category.lower() for k in ["tv", "cabinet", "shelf", "storage"])]
        millwork_lm = max(2.4, round(len(cabinet_objects) * 1.8, 1))

        return {
            "floor_area_sqm": round(floor_area, 2),
            "net_wall_area_sqm": round(net_wall_area, 2),
            "perimeter_m": round(perimeter, 2),
            "ceiling_height_m": round(ceiling_h, 2),
            "millwork_linear_m": millwork_lm,
        }

    def evaluate_keep_replace_tradeoffs(
        self,
        room: CanonicalRoomModel,
        currency: CurrencyCode = CurrencyCode.MYR,
        tier: RenovationTier = RenovationTier.MODERATE,
    ) -> Tuple[List[KeepReplaceTradeoff], float]:
        """
        Evaluates cost implications of keeping vs replacing existing room elements.
        Calculates user savings earned by preserving existing furniture and finishes.
        Fulfills Blueprint Section 34 (Keep-vs-replace trade-offs).
        """
        tradeoffs: List[KeepReplaceTradeoff] = []
        total_savings = 0.0
        ppr = self.CURRENCY_PURCHASING_POWER_RATIO.get(currency, 1.0)

        # 1. Furniture objects
        for obj in room.objects:
            # Identify benchmark category
            cat_key = "default"
            for k in self.FURNITURE_BENCHMARKS:
                if k in obj.category.lower() or k in obj.name.lower():
                    cat_key = k
                    break

            base_replacement_myr = self.FURNITURE_BENCHMARKS[cat_key][tier]
            estimated_replacement_cost = round(base_replacement_myr * ppr, 2)

            if obj.action == ObjectAction.KEEP:
                savings = estimated_replacement_cost
                total_savings += savings
                tradeoffs.append(
                    KeepReplaceTradeoff(
                        element_id=obj.id,
                        element_label=obj.name,
                        action="keep",
                        category=BudgetCategory.FURNITURE_DECOR,
                        replacement_cost_estimate=0.0,
                        savings_if_kept=savings,
                        notes=f"Retained existing {obj.name}. Avoided new purchase expense.",
                    )
                )
            elif obj.action == ObjectAction.RESTYLE:
                # Restyling / reupholstery costs ~ 40% of new item
                restyle_cost = round(estimated_replacement_cost * 0.40, 2)
                savings = round(estimated_replacement_cost - restyle_cost, 2)
                total_savings += savings
                tradeoffs.append(
                    KeepReplaceTradeoff(
                        element_id=obj.id,
                        element_label=obj.name,
                        action="restyle",
                        category=BudgetCategory.FURNITURE_DECOR,
                        replacement_cost_estimate=restyle_cost,
                        savings_if_kept=savings,
                        notes=f"Restyling existing {obj.name} saves ~60% compared to full replacement.",
                    )
                )
            elif obj.action == ObjectAction.REPLACE:
                tradeoffs.append(
                    KeepReplaceTradeoff(
                        element_id=obj.id,
                        element_label=obj.name,
                        action="replace",
                        category=BudgetCategory.FURNITURE_DECOR,
                        replacement_cost_estimate=estimated_replacement_cost,
                        savings_if_kept=0.0,
                        notes=f"New {obj.name} replacement budgeted at {tier.value.lower()} standard.",
                    )
                )
            elif obj.action == ObjectAction.REMOVE:
                tradeoffs.append(
                    KeepReplaceTradeoff(
                        element_id=obj.id,
                        element_label=obj.name,
                        action="remove",
                        category=BudgetCategory.LABOR_DEMOLITION,
                        replacement_cost_estimate=0.0,
                        savings_if_kept=0.0,
                        notes=f"Item scheduled for removal/donation.",
                    )
                )

        # 2. Flooring Surface Tradeoff
        floor_surface = next((s for s in room.surfaces if "floor" in s.surface_type.value.lower() or "floor" in s.name.lower()), None)
        if floor_surface:
            quantities = self.extract_room_quantities(room)
            sqm = quantities["floor_area_sqm"]
            flooring_rate = self.RATES_FLOORING.get(currency, self.RATES_FLOORING[CurrencyCode.MYR])[tier]
            est_floor_replacement = round(sqm * flooring_rate, 2)

            if floor_surface.action == ObjectAction.KEEP:
                total_savings += est_floor_replacement
                tradeoffs.append(
                    KeepReplaceTradeoff(
                        element_id=floor_surface.id,
                        element_label=floor_surface.name,
                        action="keep",
                        category=BudgetCategory.FLOORING,
                        replacement_cost_estimate=0.0,
                        savings_if_kept=est_floor_replacement,
                        notes=f"Retaining existing flooring across {sqm} m² saves replacement cost.",
                    )
                )
            elif floor_surface.action in (ObjectAction.REPLACE, ObjectAction.RESTYLE):
                tradeoffs.append(
                    KeepReplaceTradeoff(
                        element_id=floor_surface.id,
                        element_label=floor_surface.name,
                        action=floor_surface.action.value.lower(),
                        category=BudgetCategory.FLOORING,
                        replacement_cost_estimate=est_floor_replacement,
                        savings_if_kept=0.0,
                        notes=f"Refinishing/replacing {sqm} m² of flooring at {flooring_rate} {self.CURRENCY_SYMBOLS.get(currency, '')}/m².",
                    )
                )

        return tradeoffs, round(total_savings, 2)

    def create_budget_plan(
        self,
        room: CanonicalRoomModel,
        total_budget: float,
        currency: CurrencyCode = CurrencyCode.MYR,
        tier: RenovationTier = RenovationTier.MODERATE,
    ) -> BudgetPlan:
        """
        Synthesizes a complete renovation budget allocation plan with keep-vs-replace trade-offs.
        Fulfills Milestone 2.4 & Blueprint Section 34.
        """
        quantities = self.extract_room_quantities(room)
        tradeoffs, total_savings = self.evaluate_keep_replace_tradeoffs(room, currency=currency, tier=tier)

        # 1. Estimate Painting Costs
        wall_sqm = quantities["net_wall_area_sqm"]
        painting_rate = self.RATES_PAINTING.get(currency, self.RATES_PAINTING[CurrencyCode.MYR])[tier]
        painting_cost = round(wall_sqm * painting_rate, 2)

        # 2. Estimate Flooring Costs
        floor_surface = next((s for s in room.surfaces if "floor" in s.surface_type.value.lower() or "floor" in s.name.lower()), None)
        floor_sqm = quantities["floor_area_sqm"]
        flooring_rate = self.RATES_FLOORING.get(currency, self.RATES_FLOORING[CurrencyCode.MYR])[tier]
        if floor_surface and floor_surface.action == ObjectAction.KEEP:
            flooring_cost = 0.0
            flooring_notes = "Retained existing floor. No replacement expense."
        else:
            flooring_cost = round(floor_sqm * flooring_rate, 2)
            flooring_notes = f"{floor_sqm} m² at {flooring_rate} {self.CURRENCY_SYMBOLS.get(currency, '')}/m²."

        # 3. Estimate Millwork / Cabinetry Costs
        millwork_lm = quantities["millwork_linear_m"]
        millwork_rate = self.RATES_MILLWORK.get(currency, self.RATES_MILLWORK[CurrencyCode.MYR])[tier]
        millwork_cost = round(millwork_lm * millwork_rate, 2)

        # 4. Estimate Lighting / Electrical Costs
        base_lighting = self.RATES_LIGHTING_BASE.get(currency, self.RATES_LIGHTING_BASE[CurrencyCode.MYR])[tier]
        lighting_cost = round(base_lighting + (floor_sqm * 12.0 * self.CURRENCY_PURCHASING_POWER_RATIO.get(currency, 1.0)), 2)

        # 5. Estimate Furniture / Decor Costs from Trade-offs
        furniture_cost = sum(t.replacement_cost_estimate for t in tradeoffs if t.category == BudgetCategory.FURNITURE_DECOR)
        if furniture_cost == 0.0:
            # If all furniture kept or empty room, allocate minimal decor styling
            furniture_cost = round(base_lighting * 0.8, 2)

        # 6. Demolition / Preparation
        demo_cost = round((floor_sqm * 10.0 + wall_sqm * 5.0) * self.CURRENCY_PURCHASING_POWER_RATIO.get(currency, 1.0), 2)
        if floor_surface and floor_surface.action == ObjectAction.KEEP:
            demo_cost = round(demo_cost * 0.4, 2)

        # 7. Subtotal & Contingency (10% of subtotal)
        subtotal = painting_cost + flooring_cost + millwork_cost + lighting_cost + furniture_cost + demo_cost
        contingency_cost = round(subtotal * 0.10, 2)
        total_estimated = round(subtotal + contingency_cost, 2)

        # Target allocation distribution of user's budget across categories
        # Adjusted dynamically if flooring is kept
        if flooring_cost == 0.0:
            target_pcts = {
                BudgetCategory.PAINTING_WALLS: 0.15,
                BudgetCategory.FLOORING: 0.02,
                BudgetCategory.MILLWORK_CABINETRY: 0.30,
                BudgetCategory.LIGHTING_ELECTRICAL: 0.12,
                BudgetCategory.FURNITURE_DECOR: 0.28,
                BudgetCategory.LABOR_DEMOLITION: 0.03,
                BudgetCategory.CONTINGENCY: 0.10,
            }
        else:
            target_pcts = {
                BudgetCategory.PAINTING_WALLS: 0.10,
                BudgetCategory.FLOORING: 0.22,
                BudgetCategory.MILLWORK_CABINETRY: 0.24,
                BudgetCategory.LIGHTING_ELECTRICAL: 0.10,
                BudgetCategory.FURNITURE_DECOR: 0.22,
                BudgetCategory.LABOR_DEMOLITION: 0.02,
                BudgetCategory.CONTINGENCY: 0.10,
            }

        cost_map = {
            BudgetCategory.PAINTING_WALLS: (painting_cost, "sqm", wall_sqm, painting_rate, f"Covers {wall_sqm} m² wall area"),
            BudgetCategory.FLOORING: (flooring_cost, "sqm", floor_sqm, flooring_rate, flooring_notes),
            BudgetCategory.MILLWORK_CABINETRY: (millwork_cost, "linear_m", millwork_lm, millwork_rate, f"Custom cabinetry ~{millwork_lm} m"),
            BudgetCategory.LIGHTING_ELECTRICAL: (lighting_cost, "room", 1.0, lighting_cost, "Ambient, task & accent fixtures"),
            BudgetCategory.FURNITURE_DECOR: (furniture_cost, "lump_sum", 1.0, furniture_cost, f"Derived from {len(tradeoffs)} elements"),
            BudgetCategory.LABOR_DEMOLITION: (demo_cost, "room", 1.0, demo_cost, "Site prep, masking, disposal"),
            BudgetCategory.CONTINGENCY: (contingency_cost, "buffer", 1.0, contingency_cost, "10% unforeseen reserve buffer"),
        }

        category_names = {
            BudgetCategory.PAINTING_WALLS: "Painting & Wall Finishes",
            BudgetCategory.FLOORING: "Flooring & Skirting",
            BudgetCategory.MILLWORK_CABINETRY: "Built-in Millwork & TV Cabinetry",
            BudgetCategory.LIGHTING_ELECTRICAL: "Lighting & Electrical Fixtures",
            BudgetCategory.FURNITURE_DECOR: "Loose Furniture & Soft Decor",
            BudgetCategory.LABOR_DEMOLITION: "Site Prep & Demolition",
            BudgetCategory.CONTINGENCY: "Contingency Buffer (10%)",
        }

        allocated_items: List[CategoryCostItem] = []
        total_allocated = 0.0

        for cat, pct in target_pcts.items():
            alloc = round(total_budget * pct, 2)
            est, unit, qty, rate, notes = cost_map[cat]
            total_allocated += alloc
            allocated_items.append(
                CategoryCostItem(
                    category=cat,
                    category_name=category_names[cat],
                    allocated_amount=alloc,
                    estimated_cost=est,
                    unit=unit,
                    quantity=qty,
                    unit_rate=rate,
                    notes=notes,
                    is_over_budget=(est > alloc),
                )
            )

        remaining_budget = round(total_budget - total_estimated, 2)
        is_within_budget = total_estimated <= total_budget

        plan = BudgetPlan(
            total_budget=round(total_budget, 2),
            currency=currency,
            renovation_tier=tier,
            allocated_items=allocated_items,
            tradeoffs=tradeoffs,
            total_estimated_cost=total_estimated,
            total_allocated=round(total_allocated, 2),
            savings_from_kept_items=total_savings,
            remaining_budget=remaining_budget,
            is_within_budget=is_within_budget,
        )

        room.budget_plan = plan
        return plan
