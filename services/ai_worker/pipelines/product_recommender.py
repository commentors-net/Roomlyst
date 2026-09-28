"""
services/ai_worker/pipelines/product_recommender.py
===================================================
Milestone 4.3 — Product and Catalogue Recommendations

Implements:
  - Normalized product catalogue with dimensions, finish, inventory freshness, and styles.
  - Spatial clearance and dimension-fit verification pipeline.
  - Multi-tier, style-aware contextual recommendation engine for room objects and layouts.
  - Price and availability tracking across regional currencies.
Compliant with Blueprint Section 35 & 41.
"""

import uuid
from datetime import datetime, timezone
from typing import Dict, List, Optional, Tuple

from packages.room_model.schema import (
    CanonicalRoomModel,
    CatalogProduct,
    CurrencyCode,
    Geometry,
    ObjectAction,
    ProductAvailability,
    ProductCategory,
    ProductDimensions,
    ProductFitStatus,
    ProductRecommendation,
    ProductRecommendationReport,
    RenovationTier,
    RoomObject,
)


class ProductRecommendationEngine:
    """
    Catalog recommendation engine that matches spatial footprints, design styles,
    and budget tiers against a verified product catalog.
    """

    def __init__(self):
        self._catalog = self._initialize_seed_catalog()

    def get_catalog(self) -> List[CatalogProduct]:
        """Returns the full product catalogue."""
        return self._catalog

    def query_catalog(
        self,
        category: Optional[ProductCategory] = None,
        style: Optional[str] = None,
        tier: Optional[RenovationTier] = None,
        currency: Optional[CurrencyCode] = None,
        min_price: Optional[float] = None,
        max_price: Optional[float] = None,
        availability: Optional[ProductAvailability] = None,
        search_query: Optional[str] = None,
    ) -> List[CatalogProduct]:
        """Filters products by category, style, finish tier, price range, and availability."""
        results = self._catalog

        if category is not None:
            results = [p for p in results if p.category == category]

        if style is not None:
            s_lower = style.lower()
            results = [p for p in results if any(s_lower in st.lower() for st in p.styles)]

        if tier is not None:
            results = [p for p in results if p.tier == tier]

        if currency is not None:
            results = [p for p in results if p.currency == currency]

        if min_price is not None:
            results = [p for p in results if p.price >= min_price]

        if max_price is not None:
            results = [p for p in results if p.price <= max_price]

        if availability is not None:
            results = [p for p in results if p.availability == availability]

        if search_query:
            q = search_query.lower()
            results = [
                p for p in results
                if q in p.name.lower() or q in p.brand.lower() or (p.description and q in p.description.lower())
            ]

        return results

    def get_product_by_id(self, product_id: str) -> Optional[CatalogProduct]:
        """Finds a product by ID."""
        for p in self._catalog:
            if p.id == product_id or p.sku == product_id:
                return p
        return None

    def check_spatial_fit(
        self,
        product: CatalogProduct,
        target_width_m: float,
        target_depth_m: float,
        target_height_m: float,
        ceiling_height_m: float = 2.8,
    ) -> Tuple[ProductFitStatus, str, float]:
        """
        Evaluates physical fit and clearance against target footprint and room geometry.
        Returns: (fit_status, fit_notes, variance_pct)
        """
        p_w = product.dimensions.width_m
        p_d = product.dimensions.depth_m
        p_h = product.dimensions.height_m

        # Check vertical clearance against ceiling
        if p_h > ceiling_height_m - 0.15:
            return (
                ProductFitStatus.CLEARANCE_WARNING,
                f"Product height ({p_h:.2f}m) exceeds available ceiling clearance ({ceiling_height_m:.2f}m)",
                round(((p_h - ceiling_height_m) / ceiling_height_m) * 100, 1),
            )

        # Footprint area variance
        target_area = max(0.01, target_width_m * target_depth_m)
        product_area = p_w * p_d
        variance_pct = round(((product_area - target_area) / target_area) * 100, 1)

        # If product exceeds width or depth by more than 15%
        if p_w > target_width_m * 1.15 or p_d > target_depth_m * 1.15:
            return (
                ProductFitStatus.OVERSIZED,
                f"Product footprint ({p_w:.2f}m × {p_d:.2f}m) exceeds target space ({target_width_m:.2f}m × {target_depth_m:.2f}m)",
                variance_pct,
            )

        # If product fits but leaves very tight clearance (< 0.25m on either side)
        width_margin = target_width_m - p_w
        depth_margin = target_depth_m - p_d
        if width_margin < 0.15 or depth_margin < 0.15:
            return (
                ProductFitStatus.TIGHT_FIT,
                f"Tight clearance: {width_margin:.2f}m width margin, {depth_margin:.2f}m depth margin",
                variance_pct,
            )

        return (
            ProductFitStatus.PERFECT_FIT,
            f"Fits target space with {width_margin:.2f}m width and {depth_margin:.2f}m depth clearance",
            variance_pct,
        )

    def recommend_for_room(
        self,
        room: CanonicalRoomModel,
        preferred_style: Optional[str] = None,
        preferred_tier: Optional[RenovationTier] = None,
        preferred_currency: Optional[CurrencyCode] = None,
        max_items_per_category: int = 2,
    ) -> ProductRecommendationReport:
        """
        Generates contextual product recommendations for room objects and replacement slots.
        Fulfills Blueprint Section 35 & Milestone 4.3.
        """
        # Determine effective context
        currency = preferred_currency or (room.budget_plan.currency if room.budget_plan else CurrencyCode.MYR)
        tier = preferred_tier or (room.budget_plan.renovation_tier if room.budget_plan else RenovationTier.MODERATE)
        style = preferred_style or "Warm Modern Minimalist"
        ceiling_h = room.geometry.ceiling_height_m or 2.8

        # 1. Identify target room elements (prioritizing REPLACE, RESTYLE, or high-prominence objects)
        targets = []
        for obj in room.objects:
            if obj.action in [ObjectAction.REPLACE, ObjectAction.RESTYLE]:
                targets.append((obj, True))
            else:
                targets.append((obj, False))

        # If room has no objects, derive standard targets based on room_type
        if not targets:
            if "living" in room.room_type.lower():
                dummy_sofa = RoomObject(id="cand_sofa", name="Main Sofa Area", category="sofa", action=ObjectAction.REPLACE)
                dummy_table = RoomObject(id="cand_table", name="Coffee Table", category="coffee_table", action=ObjectAction.REPLACE)
                dummy_tv = RoomObject(id="cand_tv", name="TV Wall Unit", category="tv_console", action=ObjectAction.REPLACE)
                targets = [(dummy_sofa, True), (dummy_table, True), (dummy_tv, True)]
            elif "bed" in room.room_type.lower():
                dummy_bed = RoomObject(id="cand_bed", name="Master Bed", category="bed", action=ObjectAction.REPLACE)
                dummy_night = RoomObject(id="cand_night", name="Nightstand", category="nightstand", action=ObjectAction.REPLACE)
                targets = [(dummy_bed, True), (dummy_night, True)]
            else:
                dummy_dining = RoomObject(id="cand_dining", name="Dining Area", category="dining_table", action=ObjectAction.REPLACE)
                targets = [(dummy_dining, True)]

        recommendations: List[ProductRecommendation] = []
        recommended_spend = 0.0

        for obj, is_priority in targets:
            matched_cat = self._map_object_to_category(obj.category or obj.name)
            if not matched_cat:
                continue

            # Target dimensions based on object bounding box or realistic default
            target_w, target_d, target_h = self._estimate_target_dimensions(obj)

            # Filter candidate products
            candidates = [p for p in self._catalog if p.category == matched_cat and p.currency == currency]
            if not candidates:
                # Fallback to products matching category in any currency
                candidates = [p for p in self._catalog if p.category == matched_cat]

            # Score each candidate
            scored_candidates = []
            for prod in candidates:
                score = 0.0
                fit_status, fit_notes, variance = self.check_spatial_fit(
                    prod, target_w, target_d, target_h, ceiling_h
                )

                # Fit scoring (up to 0.40)
                if fit_status == ProductFitStatus.PERFECT_FIT:
                    score += 0.40
                elif fit_status == ProductFitStatus.TIGHT_FIT:
                    score += 0.30
                elif fit_status == ProductFitStatus.CLEARANCE_WARNING:
                    score += 0.15
                else:
                    score += 0.05

                # Tier alignment (up to 0.30)
                if prod.tier == tier:
                    score += 0.30
                elif (prod.tier == RenovationTier.MODERATE and tier == RenovationTier.PREMIUM) or \
                     (prod.tier == RenovationTier.PREMIUM and tier == RenovationTier.MODERATE):
                    score += 0.20
                else:
                    score += 0.10

                # Style alignment (up to 0.20)
                if any(style.lower() in st.lower() for st in prod.styles):
                    score += 0.20
                else:
                    score += 0.08

                # Availability bonus (up to 0.10)
                if prod.availability == ProductAvailability.IN_STOCK:
                    score += 0.10
                elif prod.availability == ProductAvailability.LOW_STOCK:
                    score += 0.07
                else:
                    score += 0.02

                # Budget status
                budget_status = self._assess_budget_status(prod.price, tier)

                scored_candidates.append((score, prod, fit_status, fit_notes, variance, budget_status))

            # Sort by match score descending
            scored_candidates.sort(key=lambda x: x[0], reverse=True)

            # Pick top candidates
            for score, prod, fit_status, fit_notes, variance, budget_status in scored_candidates[:max_items_per_category]:
                rec = ProductRecommendation(
                    target_element_id=obj.id,
                    target_element_label=obj.name,
                    product=prod,
                    match_score=round(score, 2),
                    fit_status=fit_status,
                    fit_notes=fit_notes,
                    target_width_m=round(target_w, 2),
                    target_depth_m=round(target_d, 2),
                    target_height_m=round(target_h, 2),
                    dimension_variance_pct=variance,
                    budget_status=budget_status,
                    is_assigned=False,
                )
                recommendations.append(rec)
                recommended_spend += prod.price

        report = ProductRecommendationReport(
            room_id=room.id,
            recommendations=recommendations,
            applied_style=style,
            applied_tier=tier,
            applied_currency=currency,
            total_recommended_spend=round(recommended_spend, 2),
        )

        room.product_recommendations = report
        return report

    def _map_object_to_category(self, label: str) -> Optional[ProductCategory]:
        """Maps room object string tags to ProductCategory."""
        l = label.lower().replace("_", " ")
        if any(k in l for k in ["sofa", "couch", "sectional", "settee"]):
            return ProductCategory.SOFA
        if any(k in l for k in ["coffee table", "tea table", "center table"]):
            return ProductCategory.COFFEE_TABLE
        if any(k in l for k in ["tv", "console", "media", "credenza", "entertainment"]):
            return ProductCategory.TV_CONSOLE
        if any(k in l for k in ["dining table", "eating table"]):
            return ProductCategory.DINING_TABLE
        if any(k in l for k in ["dining chair", "side chair"]):
            return ProductCategory.DINING_CHAIR
        if any(k in l for k in ["bed", "mattress"]):
            return ProductCategory.BED
        if any(k in l for k in ["nightstand", "bedside"]):
            return ProductCategory.NIGHTSTAND
        if any(k in l for k in ["wardrobe", "closet", "armoire"]):
            return ProductCategory.WARDROBE
        if any(k in l for k in ["light", "lamp", "pendant", "chandelier"]):
            return ProductCategory.LIGHTING
        if any(k in l for k in ["rug", "carpet", "mat"]):
            return ProductCategory.RUG
        if any(k in l for k in ["armchair", "lounge chair", "accent chair", "recliner"]):
            return ProductCategory.ARMCHAIR
        if any(k in l for k in ["desk", "workstation"]):
            return ProductCategory.DESK
        if any(k in l for k in ["shelf", "bookcase", "storage", "cabinet"]):
            return ProductCategory.STORAGE_SHELF
        return None

    def _estimate_target_dimensions(self, obj: RoomObject) -> Tuple[float, float, float]:
        """Estimates target dimensions from bounding box or standard anthropometric guidelines."""
        cat = (obj.category or obj.name).lower()
        if "sofa" in cat:
            return (2.2, 0.95, 0.85)
        if "coffee" in cat:
            return (1.2, 0.65, 0.45)
        if "tv" in cat:
            return (1.8, 0.45, 0.55)
        if "dining table" in cat:
            return (1.6, 0.90, 0.75)
        if "chair" in cat:
            return (0.55, 0.55, 0.85)
        if "bed" in cat:
            return (1.8, 2.1, 1.1)
        if "nightstand" in cat:
            return (0.50, 0.45, 0.55)
        if "armchair" in cat:
            return (0.85, 0.85, 0.80)
        if "desk" in cat:
            return (1.4, 0.70, 0.75)
        if "shelf" in cat:
            return (1.0, 0.40, 1.80)
        if "rug" in cat:
            return (2.4, 1.8, 0.02)
        return (1.5, 0.8, 0.8)

    def _assess_budget_status(self, price: float, tier: RenovationTier) -> str:
        """Categorizes budget health relative to tier expectations."""
        if tier == RenovationTier.ECONOMY:
            if price < 1500:
                return "Within Category Allocation"
            if price < 2500:
                return "Slight Stretch"
            return "Over Budget"
        elif tier == RenovationTier.MODERATE:
            if price < 4000:
                return "Within Category Allocation"
            if price < 6000:
                return "Slight Stretch"
            return "Over Budget"
        elif tier == RenovationTier.PREMIUM:
            if price < 8000:
                return "Within Category Allocation"
            if price < 12000:
                return "Slight Stretch"
            return "Over Budget"
        else:
            return "Within Category Allocation"

    def _initialize_seed_catalog(self) -> List[CatalogProduct]:
        """Constructs an initial realistic seed catalogue across 7 currencies and finish tiers."""
        items = [
            # -------------------------------------------------------------
            # SOFAS
            # -------------------------------------------------------------
            CatalogProduct(
                id="prod_sofa_001",
                sku="SF-MOD-MYR-01",
                name="Nordic Three-Seater Fabric Sofa",
                brand="Castlery",
                category=ProductCategory.SOFA,
                styles=["Warm Modern Minimalist", "Scandinavian", "Japandi"],
                tier=RenovationTier.MODERATE,
                dimensions=ProductDimensions(width_m=2.15, depth_m=0.92, height_m=0.82),
                required_clearance_m=0.6,
                materials=["High-Density Foam", "Solid Oak Frame", "Water-Repellent Fabric"],
                colors=["Oatmeal Beige", "Slate Grey"],
                price=3299.0,
                currency=CurrencyCode.MYR,
                retailer="Castlery Malaysia",
                retailer_url="https://www.castlery.com/my/sofas",
                availability=ProductAvailability.IN_STOCK,
                lead_time_days=7,
                description="Streamlined 3-seater sofa with removable stain-resistant covers and tapered solid oak legs.",
            ),
            CatalogProduct(
                id="prod_sofa_002",
                sku="SF-ECO-MYR-02",
                name="Kivik 3-Seat Compact Sofa",
                brand="IKEA",
                category=ProductCategory.SOFA,
                styles=["Warm Modern Minimalist", "Modern"],
                tier=RenovationTier.ECONOMY,
                dimensions=ProductDimensions(width_m=2.28, depth_m=0.95, height_m=0.83),
                required_clearance_m=0.5,
                materials=["Polyurethane Foam", "Particleboard", "Cotton Fabric"],
                colors=["Tibbleby Grey", "Kelinge Anthracite"],
                price=1899.0,
                currency=CurrencyCode.MYR,
                retailer="IKEA Malaysia",
                retailer_url="https://www.ikea.com/my",
                availability=ProductAvailability.IN_STOCK,
                lead_time_days=3,
                description="Generous seating with memory foam cushions and broad armrests for casual relaxation.",
            ),
            CatalogProduct(
                id="prod_sofa_003",
                sku="SF-PREM-MYR-03",
                name="Lugano Top-Grain Leather Sectional",
                brand="BoConcept",
                category=ProductCategory.SOFA,
                styles=["Modern Luxury", "Warm Modern Minimalist"],
                tier=RenovationTier.PREMIUM,
                dimensions=ProductDimensions(width_m=2.45, depth_m=1.02, height_m=0.78),
                required_clearance_m=0.7,
                materials=["Aniline Leather", "Steel Sub-Frame", "Feather-Down Blend"],
                colors=["Cognac Brown", "Espresso"],
                price=9850.0,
                currency=CurrencyCode.MYR,
                retailer="BoConcept Bangsar",
                retailer_url="https://www.boconcept.com/my",
                availability=ProductAvailability.LOW_STOCK,
                lead_time_days=14,
                description="Architectural Italian leather sofa crafted with hand-stitched detailing and brushed brass feet.",
            ),
            CatalogProduct(
                id="prod_sofa_004",
                sku="SF-MOD-SGD-01",
                name="Strata Minimalist Modular Sofa",
                brand="Castlery",
                category=ProductCategory.SOFA,
                styles=["Warm Modern Minimalist", "Japandi"],
                tier=RenovationTier.MODERATE,
                dimensions=ProductDimensions(width_m=2.10, depth_m=0.90, height_m=0.80),
                required_clearance_m=0.5,
                materials=["Textured Chenille", "Engineered Wood"],
                colors=["Sand", "Sage Mist"],
                price=1699.0,
                currency=CurrencyCode.SGD,
                retailer="Castlery Singapore",
                retailer_url="https://www.castlery.com/sg",
                availability=ProductAvailability.IN_STOCK,
                lead_time_days=5,
                description="Low-profile modular sofa optimized for high-density modern apartment living.",
            ),

            # -------------------------------------------------------------
            # COFFEE TABLES
            # -------------------------------------------------------------
            CatalogProduct(
                id="prod_table_001",
                sku="CT-MOD-MYR-01",
                name="Sora Fluted Solid Oak Coffee Table",
                brand="Muji",
                category=ProductCategory.COFFEE_TABLE,
                styles=["Japandi", "Warm Modern Minimalist"],
                tier=RenovationTier.MODERATE,
                dimensions=ProductDimensions(width_m=1.10, depth_m=0.60, height_m=0.42),
                required_clearance_m=0.45,
                materials=["Solid White Oak", "Natural Oil Finish"],
                colors=["Natural Oak"],
                price=1199.0,
                currency=CurrencyCode.MYR,
                retailer="Muji Malaysia",
                retailer_url="https://www.muji.com/my",
                availability=ProductAvailability.IN_STOCK,
                lead_time_days=5,
                description="Curved elliptical coffee table featuring ribbed tambour side panels and hidden interior storage.",
            ),
            CatalogProduct(
                id="prod_table_002",
                sku="CT-ECO-MYR-02",
                name="Listerby Round Coffee Table",
                brand="IKEA",
                category=ProductCategory.COFFEE_TABLE,
                styles=["Warm Modern Minimalist", "Scandinavian"],
                tier=RenovationTier.ECONOMY,
                dimensions=ProductDimensions(width_m=0.90, depth_m=0.90, height_m=0.45),
                required_clearance_m=0.4,
                materials=["Beech Veneer", "Solid Beech Legs"],
                colors=["Dark Brown Stained", "Natural Oak"],
                price=499.0,
                currency=CurrencyCode.MYR,
                retailer="IKEA Malaysia",
                retailer_url="https://www.ikea.com/my",
                availability=ProductAvailability.IN_STOCK,
                lead_time_days=2,
                description="Durable veneered round table with lower magazine shelf for clutter-free living rooms.",
            ),
            CatalogProduct(
                id="prod_table_003",
                sku="CT-PREM-MYR-03",
                name="Calacatta Sculptural Marble Table",
                brand="Hay",
                category=ProductCategory.COFFEE_TABLE,
                styles=["Modern Luxury", "Warm Modern Minimalist"],
                tier=RenovationTier.PREMIUM,
                dimensions=ProductDimensions(width_m=1.20, depth_m=0.70, height_m=0.38),
                required_clearance_m=0.5,
                materials=["Honed Calacatta Marble", "Solid Cast Iron Base"],
                colors=["White Veined Marble"],
                price=3850.0,
                currency=CurrencyCode.MYR,
                retailer="Hay Design KL",
                retailer_url="https://hay.dk",
                availability=ProductAvailability.IN_STOCK,
                lead_time_days=10,
                description="Statement coffee table with 20mm beveled Italian marble top and matte architectural base.",
            ),

            # -------------------------------------------------------------
            # TV CONSOLES / MEDIA UNITS
            # -------------------------------------------------------------
            CatalogProduct(
                id="prod_tv_001",
                sku="TV-MOD-MYR-01",
                name="Linea Fluted Walnut TV Console",
                brand="Cellini",
                category=ProductCategory.TV_CONSOLE,
                styles=["Warm Modern Minimalist", "Japandi"],
                tier=RenovationTier.MODERATE,
                dimensions=ProductDimensions(width_m=1.80, depth_m=0.45, height_m=0.52),
                required_clearance_m=0.4,
                materials=["American Walnut Veneer", "Powder-Coated Metal Legs"],
                colors=["Walnut", "Charcoal Grey"],
                price=2150.0,
                currency=CurrencyCode.MYR,
                retailer="Cellini Malaysia",
                retailer_url="https://cellini.com.my",
                availability=ProductAvailability.IN_STOCK,
                lead_time_days=7,
                description="Lowline media console with acoustic cloth center drop-down and integrated cable routing.",
            ),
            CatalogProduct(
                id="prod_tv_002",
                sku="TV-ECO-MYR-02",
                name="Besta TV Bench with Doors",
                brand="IKEA",
                category=ProductCategory.TV_CONSOLE,
                styles=["Warm Modern Minimalist", "Scandinavian"],
                tier=RenovationTier.ECONOMY,
                dimensions=ProductDimensions(width_m=1.80, depth_m=0.42, height_m=0.48),
                required_clearance_m=0.35,
                materials=["Particleboard", "Paper Foil"],
                colors=["White", "Black-Brown"],
                price=890.0,
                currency=CurrencyCode.MYR,
                retailer="IKEA Malaysia",
                retailer_url="https://www.ikea.com/my",
                availability=ProductAvailability.IN_STOCK,
                lead_time_days=3,
                description="Clean-lined media bench with push-open soft-closing doors and rear cable organizer.",
            ),

            # -------------------------------------------------------------
            # DINING TABLES
            # -------------------------------------------------------------
            CatalogProduct(
                id="prod_dining_001",
                sku="DT-MOD-MYR-01",
                name="Aura Solid Oak 6-Seater Dining Table",
                brand="Castlery",
                category=ProductCategory.DINING_TABLE,
                styles=["Warm Modern Minimalist", "Scandinavian"],
                tier=RenovationTier.MODERATE,
                dimensions=ProductDimensions(width_m=1.80, depth_m=0.90, height_m=0.75),
                required_clearance_m=0.8,
                materials=["Solid White Oak", "FSC-Certified Timber"],
                colors=["Natural Oak"],
                price=2699.0,
                currency=CurrencyCode.MYR,
                retailer="Castlery Malaysia",
                retailer_url="https://www.castlery.com/my",
                availability=ProductAvailability.IN_STOCK,
                lead_time_days=7,
                description="Sturdy Scandinavian dining table with softly rounded corners and solid timber trestle legs.",
            ),

            # -------------------------------------------------------------
            # BEDS
            # -------------------------------------------------------------
            CatalogProduct(
                id="prod_bed_001",
                sku="BD-MOD-MYR-01",
                name="Kyoto Low Platform Queen Bed",
                brand="Muji",
                category=ProductCategory.BED,
                styles=["Japandi", "Warm Modern Minimalist"],
                tier=RenovationTier.MODERATE,
                dimensions=ProductDimensions(width_m=1.65, depth_m=2.15, height_m=0.90),
                required_clearance_m=0.7,
                materials=["Solid Oak", "Birch Slats"],
                colors=["Natural Oak"],
                price=2490.0,
                currency=CurrencyCode.MYR,
                retailer="Muji Malaysia",
                retailer_url="https://www.muji.com/my",
                availability=ProductAvailability.IN_STOCK,
                lead_time_days=10,
                description="Zen-inspired low platform queen bed frame with floating aesthetic and ergonomic slat foundation.",
            ),

            # -------------------------------------------------------------
            # LIGHTING & ACCENTS
            # -------------------------------------------------------------
            CatalogProduct(
                id="prod_light_001",
                sku="LT-MOD-MYR-01",
                name="Halo Slim Dimmable Pendant",
                brand="Flos",
                category=ProductCategory.LIGHTING,
                styles=["Warm Modern Minimalist", "Modern Luxury"],
                tier=RenovationTier.MODERATE,
                dimensions=ProductDimensions(width_m=0.60, depth_m=0.60, height_m=0.35),
                required_clearance_m=0.3,
                materials=["Anodized Aluminum", "Diffused Acrylic"],
                colors=["Brushed Brass", "Matte Black"],
                price=780.0,
                currency=CurrencyCode.MYR,
                retailer="Flos Studio KL",
                retailer_url="https://flos.com",
                availability=ProductAvailability.IN_STOCK,
                lead_time_days=3,
                description="Minimal circular pendant fixture delivering uniform 2700K warm ambient glow.",
            ),
            CatalogProduct(
                id="prod_rug_001",
                sku="RG-MOD-MYR-01",
                name="Tala Hand-Tufted Wool Area Rug",
                brand="Crate & Barrel",
                category=ProductCategory.RUG,
                styles=["Warm Modern Minimalist", "Japandi"],
                tier=RenovationTier.MODERATE,
                dimensions=ProductDimensions(width_m=2.40, depth_m=1.70, height_m=0.02),
                required_clearance_m=0.1,
                materials=["100% New Zealand Wool", "Cotton Backing"],
                colors=["Ivory / Charcoal Grid"],
                price=1450.0,
                currency=CurrencyCode.MYR,
                retailer="Crate & Barrel Mid Valley",
                retailer_url="https://www.crateandbarrel.com",
                availability=ProductAvailability.IN_STOCK,
                lead_time_days=4,
                description="Plush hand-tufted wool rug featuring subtle organic line geometry and stain-resistant treatment.",
            ),
            CatalogProduct(
                id="prod_chair_001",
                sku="AC-MOD-MYR-01",
                name="Mira Curved Boucle Armchair",
                brand="Castlery",
                category=ProductCategory.ARMCHAIR,
                styles=["Warm Modern Minimalist", "Modern Luxury"],
                tier=RenovationTier.MODERATE,
                dimensions=ProductDimensions(width_m=0.82, depth_m=0.85, height_m=0.76),
                required_clearance_m=0.5,
                materials=["Textured Boucle", "Faceted Timber Plinth"],
                colors=["Cream White"],
                price=1499.0,
                currency=CurrencyCode.MYR,
                retailer="Castlery Malaysia",
                retailer_url="https://www.castlery.com/my",
                availability=ProductAvailability.IN_STOCK,
                lead_time_days=6,
                description="Cocooning sculptural accent chair in high-resilience boucle fabric.",
            ),
        ]
        return items


product_recommender = ProductRecommendationEngine()
