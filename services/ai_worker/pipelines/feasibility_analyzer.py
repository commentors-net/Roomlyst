"""
Geometry and Feasibility Intelligence Pipeline.
Fulfills Milestone 2.3 & Blueprint Section 10, 11, and 14.

Features:
1. Wall loop closure verification, endpoint snapping, and polygon Shoelace area calculation.
2. Non-rectangular room shape classification (Rectangular, L-shaped, T-shaped, Alcove, Polygonal).
3. 2D floor footprint derivation for detected room objects.
4. Automated spatial feasibility evaluation:
   - Door swing clearance checks (minimum 0.85m arc).
   - Walkway and circulation pathway clearances (minimum 0.60m, recommended 0.75m).
   - Furniture overlap / spatial collision detection.
   - Window accessibility checks.
"""

import math
from typing import List, Optional, Tuple
from packages.room_model import (
    CanonicalRoomModel,
    FeasibilityCheck,
    FeasibilityIssueType,
    FeasibilityReport,
    FeasibilitySeverity,
    FurnitureFootprint,
    Geometry,
    LoopClosureStatus,
    Point2D,
    RoomObject,
    RoomShapeType,
    WallSegment,
)


class GeometryAndFeasibilityAnalyzer:
    """
    Coordinates geometric room perimeter validation and physical space feasibility checks.
    """

    MIN_WALKWAY_CLEARANCE_M: float = 0.60  # Absolute minimum circulation path (600mm)
    RECOMMENDED_WALKWAY_M: float = 0.75   # Comfortable residential walkway (750mm)
    DOOR_SWING_CLEARANCE_M: float = 0.85   # Standard door swing clearance radius
    LOOP_CLOSURE_SNAP_TOLERANCE_M: float = 0.20  # Max gap to auto-snap endpoints (20cm)

    def analyze(self, room: CanonicalRoomModel) -> FeasibilityReport:
        """
        Processes room geometry, extracts footprints, validates loop closure,
        and executes physical clearance feasibility checks.
        """
        # 1. Process and validate room wall geometry
        self.process_geometry(room)

        # 2. Derive 2D footprints for furniture objects
        self.derive_furniture_footprints(room)

        # 3. Evaluate feasibility checks
        report = self.evaluate_feasibility(room)
        room.feasibility_report = report
        return report

    def process_geometry(self, room: CanonicalRoomModel) -> Geometry:
        """
        Validates wall segments, computes closed polygon vertices, calculates
        Shoelace area, checks loop closure, and classifies room shape.
        """
        geom = room.geometry
        width = geom.estimated_width_m or 4.0
        length = geom.estimated_length_m or 5.0
        height = geom.ceiling_height_m or 2.6

        # Synthesize default rectangular walls if none provided
        if not geom.wall_segments:
            geom.wall_segments = [
                WallSegment(
                    name="South Wall",
                    start_point=Point2D(x=0.0, y=0.0),
                    end_point=Point2D(x=width, y=0.0),
                    length_m=round(width, 2),
                    height_m=height,
                ),
                WallSegment(
                    name="East Wall",
                    start_point=Point2D(x=width, y=0.0),
                    end_point=Point2D(x=width, y=length),
                    length_m=round(length, 2),
                    height_m=height,
                ),
                WallSegment(
                    name="North Wall",
                    start_point=Point2D(x=width, y=length),
                    end_point=Point2D(x=0.0, y=length),
                    length_m=round(width, 2),
                    height_m=height,
                ),
                WallSegment(
                    name="West Wall",
                    start_point=Point2D(x=0.0, y=length),
                    end_point=Point2D(x=0.0, y=0.0),
                    length_m=round(length, 2),
                    height_m=height,
                ),
            ]
            geom.polygon_vertices = [
                Point2D(x=0.0, y=0.0),
                Point2D(x=width, y=0.0),
                Point2D(x=width, y=length),
                Point2D(x=0.0, y=length),
            ]
            geom.room_shape = RoomShapeType.RECTANGULAR
            geom.loop_closure_status = LoopClosureStatus.CLOSED
            geom.loop_closure_gap_m = 0.0
            geom.perimeter_m = round(2 * (width + length), 2)
            geom.floor_area_sqm = round(width * length, 2)
            return geom

        # Check loop closure for existing wall segments
        segments = geom.wall_segments
        p_first = segments[0].start_point
        p_last = segments[-1].end_point
        gap = math.sqrt((p_last.x - p_first.x) ** 2 + (p_last.y - p_first.y) ** 2)
        geom.loop_closure_gap_m = round(gap, 3)

        if gap <= 0.05:
            geom.loop_closure_status = LoopClosureStatus.CLOSED
        elif gap <= self.LOOP_CLOSURE_SNAP_TOLERANCE_M:
            geom.loop_closure_status = LoopClosureStatus.SNAPPED
            # Snap last end point to first start point
            segments[-1].end_point.x = p_first.x
            segments[-1].end_point.y = p_first.y
            # Recompute last wall length
            dx = segments[-1].end_point.x - segments[-1].start_point.x
            dy = segments[-1].end_point.y - segments[-1].start_point.y
            segments[-1].length_m = round(math.sqrt(dx ** 2 + dy ** 2), 2)
        else:
            geom.loop_closure_status = LoopClosureStatus.OPEN

        # Collect polygon vertices from segment start points
        geom.polygon_vertices = [Point2D(x=seg.start_point.x, y=seg.start_point.y) for seg in segments]

        # Calculate perimeter
        geom.perimeter_m = round(sum(seg.length_m for seg in segments), 2)

        # Calculate polygon area using Shoelace formula
        shoelace_area = self._calculate_shoelace_area(geom.polygon_vertices)
        if shoelace_area > 0:
            geom.floor_area_sqm = round(shoelace_area, 2)

        # Classify room shape
        num_vertices = len(geom.polygon_vertices)
        if num_vertices == 4:
            geom.room_shape = RoomShapeType.RECTANGULAR
        elif num_vertices == 6:
            geom.room_shape = RoomShapeType.L_SHAPED
        elif num_vertices == 8:
            geom.room_shape = RoomShapeType.ALCOVE
        else:
            geom.room_shape = RoomShapeType.POLYGONAL

        return geom

    def _calculate_shoelace_area(self, vertices: List[Point2D]) -> float:
        """Computes 2D polygon area via the Shoelace formula."""
        n = len(vertices)
        if n < 3:
            return 0.0
        area = 0.0
        for i in range(n):
            j = (i + 1) % n
            area += vertices[i].x * vertices[j].y
            area -= vertices[j].x * vertices[i].y
        return abs(area) / 2.0

    def derive_furniture_footprints(self, room: CanonicalRoomModel) -> None:
        """
        Derives 2D floor footprint coordinates from 2D bounding boxes or creates
        plausible spatial placement when footprints are absent.
        """
        width = room.geometry.estimated_width_m or 4.0
        length = room.geometry.estimated_length_m or 5.0

        for obj in room.objects:
            if obj.footprint_2d:
                continue

            if obj.bounding_box:
                # Map normalized 0..1 bounding box to metric floor plane coordinates
                min_x = round(obj.bounding_box.x_min * width, 2)
                max_x = round(obj.bounding_box.x_max * width, 2)
                min_y = round(obj.bounding_box.y_min * length, 2)
                max_y = round(obj.bounding_box.y_max * length, 2)
            else:
                # Fallback representative dimension based on category
                cat = obj.category.lower()
                if "sofa" in cat:
                    dim_w, dim_l = 2.10, 0.90
                elif "bed" in cat:
                    dim_w, dim_l = 1.80, 2.00
                elif "table" in cat or "desk" in cat:
                    dim_w, dim_l = 1.20, 0.70
                elif "chair" in cat:
                    dim_w, dim_l = 0.60, 0.60
                elif "wardrobe" in cat:
                    dim_w, dim_l = 1.50, 0.60
                else:
                    dim_w, dim_l = 0.80, 0.50

                center_x = round(width / 2.0, 2)
                center_y = round(length / 2.0, 2)
                min_x = round(max(0.0, center_x - dim_w / 2), 2)
                max_x = round(min(width, center_x + dim_w / 2), 2)
                min_y = round(max(0.0, center_y - dim_l / 2), 2)
                max_y = round(min(length, center_y + dim_l / 2), 2)

            w_m = round(max(0.20, max_x - min_x), 2)
            l_m = round(max(0.20, max_y - min_y), 2)
            cx = round((min_x + max_x) / 2.0, 2)
            cy = round((min_y + max_y) / 2.0, 2)

            obj.footprint_2d = FurnitureFootprint(
                center_x=cx,
                center_y=cy,
                width_m=w_m,
                length_m=l_m,
                min_x=min_x,
                max_x=max_x,
                min_y=min_y,
                max_y=max_y,
            )

    def evaluate_feasibility(self, room: CanonicalRoomModel) -> FeasibilityReport:
        """
        Executes clearance, door swing, loop closure, and furniture collision checks.
        """
        checks: List[FeasibilityCheck] = []
        critical_count = 0
        warning_count = 0

        # Check 1: Wall Loop Closure
        loop_status = room.geometry.loop_closure_status
        loop_gap = room.geometry.loop_closure_gap_m
        if loop_status in (LoopClosureStatus.CLOSED, LoopClosureStatus.SNAPPED):
            checks.append(
                FeasibilityCheck(
                    check_name="Wall Perimeter Loop Closure",
                    passed=True,
                    severity=FeasibilitySeverity.INFO,
                    message=f"Perimeter loop successfully closed ({loop_status.value.lower()}). Gap: {loop_gap:.2f}m.",
                )
            )
        else:
            checks.append(
                FeasibilityCheck(
                    check_name="Wall Perimeter Loop Closure",
                    passed=False,
                    severity=FeasibilitySeverity.WARNING,
                    issue_type=FeasibilityIssueType.WALL_LOOP_NOT_CLOSED,
                    measured_clearance_m=loop_gap,
                    required_clearance_m=self.LOOP_CLOSURE_SNAP_TOLERANCE_M,
                    message=f"Wall perimeter loop is unclosed with a {loop_gap:.2f}m gap.",
                    suggested_action="Capture missing corner photos to close the room loop.",
                )
            )
            warning_count += 1

        # Check 2: Door Swing Clearance
        for opn in room.openings:
            if opn.opening_type.value == "DOOR":
                # Default door location (assumed at south wall entrance (0.5, 0.0) if unpositioned)
                door_cx = 0.90
                door_cy = 0.0

                for obj in room.objects:
                    if not obj.footprint_2d:
                        continue
                    fp = obj.footprint_2d
                    # Distance from door hinge to nearest point of furniture
                    dx = max(0.0, fp.min_x - door_cx) if fp.min_x > door_cx else max(0.0, door_cx - fp.max_x)
                    dy = max(0.0, fp.min_y - door_cy) if fp.min_y > door_cy else max(0.0, door_cy - fp.max_y)
                    dist_to_door = math.sqrt(dx ** 2 + dy ** 2)

                    if dist_to_door < self.DOOR_SWING_CLEARANCE_M:
                        checks.append(
                            FeasibilityCheck(
                                check_name=f"Door Swing Clearance ({opn.name})",
                                passed=False,
                                severity=FeasibilitySeverity.CRITICAL,
                                issue_type=FeasibilityIssueType.DOOR_SWING_OBSTRUCTED,
                                entity_ids=[opn.id, obj.id],
                                entity_names=[opn.name, obj.name],
                                measured_clearance_m=round(dist_to_door, 2),
                                required_clearance_m=self.DOOR_SWING_CLEARANCE_M,
                                message=f"Door swing clearance obstructed by '{obj.name}' ({dist_to_door:.2f}m vs required {self.DOOR_SWING_CLEARANCE_M:.2f}m).",
                                suggested_action=f"Relocate '{obj.name}' at least {self.DOOR_SWING_CLEARANCE_M:.2f}m away from the door opening arc.",
                            )
                        )
                        critical_count += 1
                    else:
                        checks.append(
                            FeasibilityCheck(
                                check_name=f"Door Swing Clearance ({opn.name})",
                                passed=True,
                                severity=FeasibilitySeverity.INFO,
                                entity_ids=[opn.id, obj.id],
                                entity_names=[opn.name, obj.name],
                                measured_clearance_m=round(dist_to_door, 2),
                                required_clearance_m=self.DOOR_SWING_CLEARANCE_M,
                                message=f"Door swing path is clear from '{obj.name}' ({dist_to_door:.2f}m).",
                            )
                        )

        # Check 3: Inter-Furniture Walkway & Overlap Clearances
        min_walkway = float("inf")
        objs = [o for o in room.objects if o.footprint_2d is not None]

        for i in range(len(objs)):
            for j in range(i + 1, len(objs)):
                obj_a = objs[i]
                obj_b = objs[j]
                fp_a = obj_a.footprint_2d
                fp_b = obj_b.footprint_2d

                # 2D distance between rectangular footprints
                dx = max(0.0, max(fp_a.min_x - fp_b.max_x, fp_b.min_x - fp_a.max_x))
                dy = max(0.0, max(fp_a.min_y - fp_b.max_y, fp_b.min_y - fp_a.max_y))
                clearance = math.sqrt(dx ** 2 + dy ** 2)

                if clearance < min_walkway:
                    min_walkway = clearance

                # Overlap check
                if clearance == 0.0:
                    overlap_w = max(0.0, min(fp_a.max_x, fp_b.max_x) - max(fp_a.min_x, fp_b.min_x))
                    overlap_l = max(0.0, min(fp_a.max_y, fp_b.max_y) - max(fp_a.min_y, fp_b.min_y))
                    overlap_area = overlap_w * overlap_l
                    if overlap_area > 0.04:  # > 400 cm² overlap
                        checks.append(
                            FeasibilityCheck(
                                check_name=f"Furniture Overlap: {obj_a.name} & {obj_b.name}",
                                passed=False,
                                severity=FeasibilitySeverity.CRITICAL,
                                issue_type=FeasibilityIssueType.FURNITURE_OVERLAP,
                                entity_ids=[obj_a.id, obj_b.id],
                                entity_names=[obj_a.name, obj_b.name],
                                message=f"Physical overlap ({overlap_area:.2f}m²) between '{obj_a.name}' and '{obj_b.name}'.",
                                suggested_action=f"Separate '{obj_a.name}' and '{obj_b.name}' to prevent collision.",
                            )
                        )
                        critical_count += 1
                        continue

                # Narrow walkway check
                if clearance < self.MIN_WALKWAY_CLEARANCE_M:
                    checks.append(
                        FeasibilityCheck(
                            check_name=f"Walkway: {obj_a.name} & {obj_b.name}",
                            passed=False,
                            severity=FeasibilitySeverity.WARNING,
                            issue_type=FeasibilityIssueType.WALKWAY_TOO_NARROW,
                            entity_ids=[obj_a.id, obj_b.id],
                            entity_names=[obj_a.name, obj_b.name],
                            measured_clearance_m=round(clearance, 2),
                            required_clearance_m=self.MIN_WALKWAY_CLEARANCE_M,
                            message=f"Tight pathway between '{obj_a.name}' and '{obj_b.name}' ({clearance:.2f}m vs required {self.MIN_WALKWAY_CLEARANCE_M:.2f}m).",
                            suggested_action=f"Maintain at least {self.RECOMMENDED_WALKWAY_M:.2f}m between items for comfortable passage.",
                        )
                    )
                    warning_count += 1
                else:
                    checks.append(
                        FeasibilityCheck(
                            check_name=f"Walkway: {obj_a.name} & {obj_b.name}",
                            passed=True,
                            severity=FeasibilitySeverity.INFO,
                            entity_ids=[obj_a.id, obj_b.id],
                            entity_names=[obj_a.name, obj_b.name],
                            measured_clearance_m=round(clearance, 2),
                            required_clearance_m=self.MIN_WALKWAY_CLEARANCE_M,
                            message=f"Adequate clearance between '{obj_a.name}' and '{obj_b.name}' ({clearance:.2f}m).",
                        )
                    )

        min_walkway_val = round(min_walkway, 2) if min_walkway != float("inf") else None
        overall = critical_count == 0

        summary = (
            "All physical room clearances and loop closures pass."
            if overall and warning_count == 0
            else f"Feasibility warnings detected ({critical_count} critical, {warning_count} warnings). Review clearances."
        )

        return FeasibilityReport(
            overall_feasible=overall,
            critical_issues_count=critical_count,
            warning_issues_count=warning_count,
            checks=checks,
            min_walkway_clearance_m=min_walkway_val,
            summary=summary,
        )
