"""
services/ai_worker/pipelines/variant_manager.py
===============================================
Milestone 2.5: Design Variant Management, Branching, Comparison, and Favorites.
Compliant with Blueprint Section 16 & 39.2.
"""

from typing import Dict, List, Optional, Any
from datetime import datetime, timezone

from packages.room_model.schema import (
    CanonicalRoomModel,
    DesignVariant,
    DesignVersion,
    VariantComparison,
)


class VariantManager:
    """
    Manages design versions, branching trees, side-by-side comparison,
    and user favourites across redesign variants.
    """

    @staticmethod
    def find_variant(room_model: CanonicalRoomModel, variant_id: str) -> Optional[DesignVariant]:
        """Searches all versions in a room for a variant by ID."""
        for version in room_model.versions:
            for variant in version.variants:
                if variant.variant_id == variant_id:
                    return variant
        return None

    @staticmethod
    def find_version(room_model: CanonicalRoomModel, version_id: str) -> Optional[DesignVersion]:
        """Finds a version by its ID in a room."""
        for version in room_model.versions:
            if version.id == version_id:
                return version
        return None

    @classmethod
    def toggle_favorite(
        cls,
        room_model: CanonicalRoomModel,
        variant_id: str,
        is_favorite: Optional[bool] = None,
        notes: Optional[str] = None,
    ) -> Optional[DesignVariant]:
        """
        Toggles or sets the favourite state and notes for a specific variant.
        Fulfills Blueprint Section 39.2.
        """
        variant = cls.find_variant(room_model, variant_id)
        if not variant:
            return None

        if is_favorite is not None:
            variant.is_favorite = is_favorite
        else:
            variant.is_favorite = not variant.is_favorite

        if notes is not None:
            variant.favorite_notes = notes

        if variant.is_favorite:
            variant.starred_at = datetime.now(timezone.utc)
        else:
            variant.starred_at = None

        return variant

    @classmethod
    def get_favorites(cls, room_model: CanonicalRoomModel) -> List[Dict[str, Any]]:
        """Returns all favorited variants across all versions with version context."""
        favorites: List[Dict[str, Any]] = []
        for version in room_model.versions:
            for variant in version.variants:
                if variant.is_favorite:
                    favorites.append({
                        "version_id": version.id,
                        "version_number": version.version_number,
                        "branch_label": version.branch_label,
                        "variant": variant.model_dump(mode="json"),
                    })
        return favorites

    @classmethod
    def compare_variants(
        cls,
        variant_a: DesignVariant,
        variant_b: DesignVariant,
    ) -> VariantComparison:
        """
        Computes detailed side-by-side comparison between two variants.
        Fulfills Milestone 2.5 & Blueprint Section 16 & 39.2.
        """
        cost_a = variant_a.estimated_cost
        cost_b = variant_b.estimated_cost
        cost_delta = round(cost_b - cost_a, 2) if (cost_a is not None and cost_b is not None) else None

        pres_a = variant_a.structural_preservation_score
        pres_b = variant_b.structural_preservation_score
        pres_delta = round(pres_b - pres_a, 4)

        set_a = set(variant_a.changes_made)
        set_b = set(variant_b.changes_made)

        shared = sorted(list(set_a.intersection(set_b)))
        unique_a = sorted(list(set_a - set_b))
        unique_b = sorted(list(set_b - set_a))

        return VariantComparison(
            variant_a_id=variant_a.variant_id,
            variant_b_id=variant_b.variant_id,
            variant_a_title=variant_a.title,
            variant_b_title=variant_b.title,
            variant_a_style=variant_a.style,
            variant_b_style=variant_b.style,
            variant_a_image_url=variant_a.image_url,
            variant_b_image_url=variant_b.image_url,
            cost_a=cost_a,
            cost_b=cost_b,
            cost_delta=cost_delta,
            preservation_score_a=pres_a,
            preservation_score_b=pres_b,
            preservation_score_delta=pres_delta,
            shared_changes=shared,
            changes_unique_to_a=unique_a,
            changes_unique_to_b=unique_b,
        )

    @classmethod
    def get_version_tree(cls, room_model: CanonicalRoomModel) -> List[Dict[str, Any]]:
        """
        Returns structured tree/list of versions and branches for the room.
        Fulfills Blueprint Section 16.
        """
        tree: List[Dict[str, Any]] = []
        for version in room_model.versions:
            tree.append({
                "id": version.id,
                "version_number": version.version_number,
                "branch_label": version.branch_label or "Main Branch",
                "parent_version_id": version.parent_version_id,
                "parent_variant_id": version.parent_variant_id,
                "variant_count": len(version.variants),
                "created_at": version.created_at.isoformat() if version.created_at else None,
                "variants": [
                    {
                        "variant_id": v.variant_id,
                        "title": v.title,
                        "style": v.style,
                        "image_url": v.image_url,
                        "is_favorite": v.is_favorite,
                        "estimated_cost": v.estimated_cost,
                    }
                    for v in version.variants
                ],
            })
        return tree
