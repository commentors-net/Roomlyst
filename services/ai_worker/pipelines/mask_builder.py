"""
Mask Synthesis and Conditioning Compiler for Generative Redesign.
Fulfills Blueprint Section 14 (Design Constraint System) and Milestone 1.5.
"""

from typing import Dict, Tuple
import numpy as np
from PIL import Image, ImageDraw

from packages.room_model import CanonicalRoomModel, DesignConstraint, ObjectAction


class MaskBuilder:
    """
    Synthesizes binary preserve and replace conditioning masks
    from CanonicalRoomModel spatial elements and DesignConstraint rules.
    """

    @staticmethod
    def build_conditioning_masks(
        room: CanonicalRoomModel,
        constraints: DesignConstraint,
        width: int,
        height: int,
    ) -> Tuple[Image.Image, Image.Image]:
        """
        Returns:
            preserve_mask: PIL Image (L mode). 255 where elements must remain strictly preserved.
            replace_mask: PIL Image (L mode). 255 where elements are subject to generative inpainting.
        """
        # Blank black masks (0 = unconstrained)
        preserve_img = Image.new("L", (width, height), 0)
        replace_img = Image.new("L", (width, height), 0)

        p_draw = ImageDraw.Draw(preserve_img)
        r_draw = ImageDraw.Draw(replace_img)

        # 1. Architectural Openings (Windows, Doors) -> Preserved by default
        for opn in room.openings:
            if opn.bounding_box:
                bb = opn.bounding_box
                box = [int(bb.x_min * width), int(bb.y_min * height), int(bb.x_max * width), int(bb.y_max * height)]
                if opn.id in constraints.preserve_ids or opn.action == ObjectAction.KEEP:
                    p_draw.rectangle(box, fill=255)
                else:
                    r_draw.rectangle(box, fill=255)

        # 2. Surfaces (Floor, Walls, Ceiling)
        for s in room.surfaces:
            if s.surface_type.value == "FLOOR":
                floor_y = int(height * 0.70)
                box = [0, floor_y, width, height]
                if s.id in constraints.replace_ids or s.action in {ObjectAction.REPLACE, ObjectAction.RESTYLE}:
                    r_draw.rectangle(box, fill=255)
                else:
                    p_draw.rectangle(box, fill=255)
            elif s.surface_type.value == "WALL":
                wall_y = int(height * 0.70)
                box = [0, 0, width, wall_y]
                if s.id in constraints.replace_ids or s.action in {ObjectAction.REPLACE, ObjectAction.RESTYLE}:
                    r_draw.rectangle(box, fill=255)

        # 3. Furniture Objects
        for obj in room.objects:
            if obj.bounding_box:
                bb = obj.bounding_box
                box = [int(bb.x_min * width), int(bb.y_min * height), int(bb.x_max * width), int(bb.y_max * height)]
                if obj.id in constraints.preserve_ids or obj.action == ObjectAction.KEEP:
                    p_draw.rectangle(box, fill=255)
                    # Clear from replace mask if overlap
                    r_draw.rectangle(box, fill=0)
                elif obj.id in (constraints.replace_ids + constraints.remove_ids) or obj.action in {ObjectAction.REPLACE, ObjectAction.REMOVE}:
                    r_draw.rectangle(box, fill=255)

        return preserve_img, replace_img

    @classmethod
    def build_inpainting_mask(
        cls,
        room: CanonicalRoomModel,
        constraints: DesignConstraint,
        width: int,
        height: int,
    ) -> Image.Image:
        """
        Synthesizes a normalized, single-channel 8-bit inpainting mask (L mode).

        POLARITY SPECIFICATION (Standard Diffusion Inpainting Convention):
        - 255 (White): Area to be INPAINTED / regenerated (surfaces to restyle, items to replace/remove).
        - 0 (Black): Area to be KEPT / preserved verbatim (structural doors, windows, preserved furniture).

        Strict Architectural & Object Preservation Rules:
        - Architectural openings (doors, windows) with ObjectAction.KEEP or in constraints.preserve_ids
          are strictly protected (locked to 0).
        - Furniture objects with ObjectAction.KEEP or in constraints.preserve_ids are strictly protected (locked to 0).
        - Any pixel covered by the preserve mask is zeroed out in the inpainting mask,
          guaranteeing that broad surface restyling never bleeds into protected elements.
        """
        preserve_mask, replace_mask = cls.build_conditioning_masks(
            room=room,
            constraints=constraints,
            width=width,
            height=height,
        )
        p_arr = np.array(preserve_mask)
        r_arr = np.array(replace_mask)

        # Inpainting mask = replace_mask AND NOT preserve_mask
        inpaint_arr = np.where(p_arr > 0, 0, r_arr).astype(np.uint8)
        return Image.fromarray(inpaint_arr, mode="L")

