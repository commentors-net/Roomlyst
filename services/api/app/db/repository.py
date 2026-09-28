"""
In-Memory & File-Backed Repository for Phase 0 POC & Phase 5 Professional Workspace state.
Stores Projects, Rooms, Clients, and Canonical Room Models.
Prepares clean transition to PostgreSQL in production.
"""

from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional
import uuid
from pydantic import BaseModel, Field

from packages.room_model import (
    ApprovalRecord,
    ApprovalStatus,
    CanonicalRoomModel,
    ClientRecord,
    CommentStatus,
    DesignComment,
    DesignVersion,
    ProjectCollaborator,
    ProjectRole,
    ProjectStatus,
    ProjectWorkspaceSummary,
    ReviewSessionPayload,
    SharePermissionTier,
    ShareReviewLink,
    StudioBranding,
    MeasurementScheduleItem,
    AssumptionScheduleItem,
    RoomSheetSummary,
    ProfessionalExportDossier,
)


class ProjectRecord(BaseModel):
    id: str = Field(default_factory=lambda: f"proj_{uuid.uuid4().hex[:8]}")
    name: str
    currency: str = "MYR"
    room_ids: List[str] = Field(default_factory=list)
    client_id: Optional[str] = None
    status: ProjectStatus = ProjectStatus.BRIEFING
    property_address: Optional[str] = None
    designer_notes: Optional[str] = None
    target_completion_date: Optional[str] = None
    collaborators: List[ProjectCollaborator] = Field(default_factory=list)
    branding: StudioBranding = Field(default_factory=StudioBranding)
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class InMemoryRepository:
    """Thread-safe store for development & professional workspace execution."""

    def __init__(self):
        self.projects: Dict[str, ProjectRecord] = {}
        self.rooms: Dict[str, CanonicalRoomModel] = {}
        self.clients: Dict[str, ClientRecord] = {}
        self.comments: Dict[str, DesignComment] = {}
        self.approvals: Dict[str, ApprovalRecord] = {}
        self.share_links: Dict[str, ShareReviewLink] = {}

    # ==========================
    # Project Methods
    # ==========================
    def create_project(
        self,
        name: str,
        currency: str = "MYR",
        client_id: Optional[str] = None,
        property_address: Optional[str] = None,
        status: ProjectStatus = ProjectStatus.BRIEFING,
        designer_notes: Optional[str] = None,
    ) -> ProjectRecord:
        proj = ProjectRecord(
            name=name,
            currency=currency,
            client_id=client_id,
            property_address=property_address,
            status=status,
            designer_notes=designer_notes,
        )
        self.projects[proj.id] = proj
        if client_id and client_id in self.clients:
            if proj.id not in self.clients[client_id].project_ids:
                self.clients[client_id].project_ids.append(proj.id)
                self.clients[client_id].updated_at = datetime.now(timezone.utc)
        return proj

    def get_project(self, project_id: str) -> Optional[ProjectRecord]:
        return self.projects.get(project_id)

    def list_projects(self, client_id: Optional[str] = None) -> List[ProjectRecord]:
        all_projs = list(self.projects.values())
        if client_id:
            return [p for p in all_projs if p.client_id == client_id]
        return all_projs

    def update_project(
        self,
        project_id: str,
        name: Optional[str] = None,
        currency: Optional[str] = None,
        client_id: Optional[str] = None,
        status: Optional[ProjectStatus] = None,
        property_address: Optional[str] = None,
        designer_notes: Optional[str] = None,
        target_completion_date: Optional[str] = None,
    ) -> Optional[ProjectRecord]:
        proj = self.projects.get(project_id)
        if not proj:
            return None

        # Handle client change
        if client_id is not None and client_id != proj.client_id:
            # Remove from old client
            if proj.client_id and proj.client_id in self.clients:
                self.clients[proj.client_id].project_ids = [
                    pid for pid in self.clients[proj.client_id].project_ids if pid != proj.id
                ]
            # Add to new client
            if client_id and client_id in self.clients:
                if proj.id not in self.clients[client_id].project_ids:
                    self.clients[client_id].project_ids.append(proj.id)
            proj.client_id = client_id

        if name is not None:
            proj.name = name
        if currency is not None:
            proj.currency = currency
        if status is not None:
            proj.status = status
        if property_address is not None:
            proj.property_address = property_address
        if designer_notes is not None:
            proj.designer_notes = designer_notes
        if target_completion_date is not None:
            proj.target_completion_date = target_completion_date

        proj.updated_at = datetime.now(timezone.utc)
        return proj

    def delete_project(self, project_id: str) -> bool:
        if project_id in self.projects:
            proj = self.projects.pop(project_id)
            if proj.client_id and proj.client_id in self.clients:
                self.clients[proj.client_id].project_ids = [
                    pid for pid in self.clients[proj.client_id].project_ids if pid != project_id
                ]
            # Delete child rooms
            for rid in proj.room_ids:
                self.rooms.pop(rid, None)
            return True
        return False

    def add_project_collaborator(
        self,
        project_id: str,
        user_id: str,
        email: str,
        name: str,
        role: ProjectRole = ProjectRole.COLLABORATOR,
    ) -> Optional[ProjectCollaborator]:
        proj = self.projects.get(project_id)
        if not proj:
            return None
        # Remove existing if already present
        proj.collaborators = [c for c in proj.collaborators if c.user_id != user_id]
        collab = ProjectCollaborator(user_id=user_id, email=email, name=name, role=role)
        proj.collaborators.append(collab)
        proj.updated_at = datetime.now(timezone.utc)
        return collab

    def remove_project_collaborator(self, project_id: str, user_id: str) -> bool:
        proj = self.projects.get(project_id)
        if not proj:
            return False
        initial_len = len(proj.collaborators)
        proj.collaborators = [c for c in proj.collaborators if c.user_id != user_id]
        if len(proj.collaborators) != initial_len:
            proj.updated_at = datetime.now(timezone.utc)
            return True
        return False

    def get_project_summary(self, project_id: str) -> Optional[ProjectWorkspaceSummary]:
        proj = self.projects.get(project_id)
        if not proj:
            return None

        client_rec = self.clients.get(proj.client_id) if proj.client_id else None
        rooms_list = [self.rooms[rid] for rid in proj.room_ids if rid in self.rooms]

        total_area = sum(r.geometry.floor_area_sqm for r in rooms_list if r.geometry)
        total_budget = sum(
            r.budget_plan.grand_total for r in rooms_list if r.budget_plan and r.budget_plan.grand_total > 0
        )

        rooms_summary_list = []
        for r in rooms_list:
            rooms_summary_list.append({
                "room_id": r.id,
                "name": r.name,
                "room_type": r.room_type,
                "status": r.status,
                "floor_area_sqm": round(r.geometry.floor_area_sqm, 2) if r.geometry else 0.0,
                "estimated_budget": round(r.budget_plan.grand_total, 2) if r.budget_plan else 0.0,
                "variants_count": sum(len(v.variants) for v in r.versions),
                "plans_count": len(r.renovation_plans),
                "latest_plan_version": r.renovation_plans[-1].version if r.renovation_plans else None,
            })

        return ProjectWorkspaceSummary(
            project_id=proj.id,
            name=proj.name,
            client=client_rec,
            status=proj.status,
            currency=proj.currency,
            property_address=proj.property_address,
            total_rooms=len(rooms_list),
            total_floor_area_sqm=round(total_area, 2),
            total_estimated_budget=round(total_budget, 2),
            rooms_summary=rooms_summary_list,
            collaborators=proj.collaborators,
            designer_notes=proj.designer_notes,
            target_completion_date=proj.target_completion_date,
            updated_at=proj.updated_at,
        )

    # ==========================
    # Client Methods
    # ==========================
    def create_client(
        self,
        name: str,
        email: Optional[str] = None,
        phone: Optional[str] = None,
        company: Optional[str] = None,
        address: Optional[str] = None,
        notes: Optional[str] = None,
        budget_preference: Optional[float] = None,
        currency: str = "MYR",
        preferred_styles: Optional[List[str]] = None,
    ) -> ClientRecord:
        client = ClientRecord(
            name=name,
            email=email,
            phone=phone,
            company=company,
            address=address,
            notes=notes,
            budget_preference=budget_preference,
            currency=currency,
            preferred_styles=preferred_styles or [],
        )
        self.clients[client.client_id] = client
        return client

    def get_client(self, client_id: str) -> Optional[ClientRecord]:
        return self.clients.get(client_id)

    def list_clients(self) -> List[ClientRecord]:
        return list(self.clients.values())

    def update_client(
        self,
        client_id: str,
        name: Optional[str] = None,
        email: Optional[str] = None,
        phone: Optional[str] = None,
        company: Optional[str] = None,
        address: Optional[str] = None,
        notes: Optional[str] = None,
        budget_preference: Optional[float] = None,
        currency: Optional[str] = None,
        preferred_styles: Optional[List[str]] = None,
    ) -> Optional[ClientRecord]:
        client = self.clients.get(client_id)
        if not client:
            return None
        if name is not None:
            client.name = name
        if email is not None:
            client.email = email
        if phone is not None:
            client.phone = phone
        if company is not None:
            client.company = company
        if address is not None:
            client.address = address
        if notes is not None:
            client.notes = notes
        if budget_preference is not None:
            client.budget_preference = budget_preference
        if currency is not None:
            client.currency = currency
        if preferred_styles is not None:
            client.preferred_styles = preferred_styles
        client.updated_at = datetime.now(timezone.utc)
        return client

    def delete_client(self, client_id: str) -> bool:
        if client_id in self.clients:
            self.clients.pop(client_id)
            # Unlink client from projects
            for p in self.projects.values():
                if p.client_id == client_id:
                    p.client_id = None
                    p.updated_at = datetime.now(timezone.utc)
            return True
        return False

    # ==========================
    # Room Methods
    # ==========================
    def save_room(self, room: CanonicalRoomModel) -> CanonicalRoomModel:
        self.rooms[room.id] = room
        if room.project_id in self.projects:
            if room.id not in self.projects[room.project_id].room_ids:
                self.projects[room.project_id].room_ids.append(room.id)
        return room

    def get_room(self, room_id: str) -> Optional[CanonicalRoomModel]:
        return self.rooms.get(room_id)

    def list_rooms(self, project_id: Optional[str] = None) -> List[CanonicalRoomModel]:
        all_rooms = list(self.rooms.values())
        if project_id:
            return [r for r in all_rooms if r.project_id == project_id]
        return all_rooms

    # ==========================
    # Milestone 5.2: Comments & Annotations
    # ==========================
    def add_comment(
        self,
        room_id: str,
        author_id: str,
        author_name: str,
        text: str,
        author_role: str = "CLIENT",
        variant_id: Optional[str] = None,
        version_id: Optional[str] = None,
        pin_x: Optional[float] = None,
        pin_y: Optional[float] = None,
        element_id: Optional[str] = None,
        parent_comment_id: Optional[str] = None,
    ) -> DesignComment:
        cmt = DesignComment(
            room_id=room_id,
            author_id=author_id,
            author_name=author_name,
            author_role=author_role,
            text=text,
            variant_id=variant_id,
            version_id=version_id,
            pin_x=pin_x,
            pin_y=pin_y,
            element_id=element_id,
            parent_comment_id=parent_comment_id,
        )
        self.comments[cmt.comment_id] = cmt
        room = self.rooms.get(room_id)
        if room:
            room.comments.append(cmt.model_dump())
            room.updated_at = datetime.now(timezone.utc)
        return cmt

    def list_comments(
        self,
        room_id: str,
        variant_id: Optional[str] = None,
        status: Optional[CommentStatus] = None,
    ) -> List[DesignComment]:
        res = [c for c in self.comments.values() if c.room_id == room_id]
        if variant_id:
            res = [c for c in res if c.variant_id == variant_id or c.variant_id is None]
        if status:
            res = [c for c in res if c.status == status]
        return sorted(res, key=lambda x: x.created_at)

    def get_comment(self, comment_id: str) -> Optional[DesignComment]:
        return self.comments.get(comment_id)

    def update_comment_status(
        self, comment_id: str, status: CommentStatus
    ) -> Optional[DesignComment]:
        cmt = self.comments.get(comment_id)
        if not cmt:
            return None
        cmt.status = status
        cmt.updated_at = datetime.now(timezone.utc)
        return cmt

    def delete_comment(self, comment_id: str) -> bool:
        if comment_id in self.comments:
            self.comments.pop(comment_id)
            return True
        return False

    # ==========================
    # Milestone 5.2: Design Approvals
    # ==========================
    def record_approval(
        self,
        room_id: str,
        status: ApprovalStatus,
        decided_by_name: Optional[str] = None,
        decided_by_role: Optional[str] = None,
        notes: Optional[str] = None,
        version_id: Optional[str] = None,
        variant_id: Optional[str] = None,
    ) -> ApprovalRecord:
        record = ApprovalRecord(
            room_id=room_id,
            version_id=version_id,
            variant_id=variant_id,
            status=status,
            decided_by_name=decided_by_name,
            decided_by_role=decided_by_role,
            notes=notes,
            decided_at=datetime.now(timezone.utc) if status in [ApprovalStatus.APPROVED, ApprovalStatus.CHANGES_REQUESTED, ApprovalStatus.REJECTED] else None,
        )
        self.approvals[record.approval_id] = record
        room = self.rooms.get(room_id)
        if room:
            room.approvals.append(record.model_dump())
            room.updated_at = datetime.now(timezone.utc)
        return record

    def list_approvals(self, room_id: str) -> List[ApprovalRecord]:
        return [a for a in self.approvals.values() if a.room_id == room_id]

    def get_latest_approval(
        self, room_id: str, variant_id: Optional[str] = None
    ) -> Optional[ApprovalRecord]:
        matches = [a for a in self.approvals.values() if a.room_id == room_id]
        if variant_id:
            matches = [a for a in matches if a.variant_id == variant_id or a.variant_id is None]
        if not matches:
            return None
        return sorted(matches, key=lambda x: x.created_at, reverse=True)[0]

    # ==========================
    # Milestone 5.2: Shareable Review Links
    # ==========================
    def create_share_link(
        self,
        project_id: str,
        room_id: Optional[str] = None,
        created_by: str = "designer",
        permission: SharePermissionTier = SharePermissionTier.CAN_COMMENT,
        allow_comments: bool = True,
        allow_approvals: bool = False,
        expires_in_days: int = 14,
    ) -> ShareReviewLink:
        expires_at = datetime.now(timezone.utc) + timedelta(days=expires_in_days)
        link = ShareReviewLink(
            project_id=project_id,
            room_id=room_id,
            created_by=created_by,
            permission=permission,
            allow_comments=allow_comments,
            allow_approvals=allow_approvals,
            expires_at=expires_at,
        )
        self.share_links[link.token] = link
        return link

    def get_share_link_by_token(self, token: str) -> Optional[ShareReviewLink]:
        link = self.share_links.get(token)
        if not link:
            return None
        if link.is_revoked:
            return None
        if link.expires_at and datetime.now(timezone.utc) > link.expires_at:
            return None
        return link

    def revoke_share_link(self, link_id: str) -> bool:
        for link in self.share_links.values():
            if link.link_id == link_id:
                link.is_revoked = True
                return True
        return False

    def list_project_share_links(self, project_id: str) -> List[ShareReviewLink]:
        return [l for l in self.share_links.values() if l.project_id == project_id and not l.is_revoked]

    def get_review_session(self, token: str) -> Optional[ReviewSessionPayload]:
        link = self.get_share_link_by_token(token)
        if not link:
            return None

        project = self.projects.get(link.project_id)
        project_name = project.name if project else "Interior Design Workspace"
        currency = project.currency if project else "MYR"
        property_address = project.property_address if project else None

        # Resolve target room
        target_room_id = link.room_id
        if not target_room_id and project and project.room_ids:
            target_room_id = project.room_ids[0]

        room = self.rooms.get(target_room_id) if target_room_id else None
        room_name = room.name if room else "Room Design"
        room_type = room.room_type if room else "living_room"
        original_image_url = room.original_image_url if room else None

        # Select latest or best variant
        selected_variant_id = None
        selected_variant_image_url = None
        selected_variant_style = None
        available_variants: List[Dict[str, Any]] = []

        if room and room.versions:
            latest_version = room.versions[-1]
            if latest_version.variants:
                fav = next((v for v in latest_version.variants if v.is_favorite), latest_version.variants[0])
                selected_variant_id = fav.variant_id
                selected_variant_image_url = fav.image_url
                selected_variant_style = getattr(fav, "style", getattr(fav, "style_name", "Modern"))
                for v in latest_version.variants:
                    available_variants.append({
                        "variant_id": v.variant_id,
                        "style_name": getattr(v, "style", getattr(v, "style_name", "Modern")),
                        "image_url": v.image_url,
                        "estimated_cost": v.estimated_cost,
                        "is_favorite": v.is_favorite,
                    })

        # Latest approval & comments
        latest_approval = self.get_latest_approval(target_room_id) if target_room_id else None
        approval_status = latest_approval.status if latest_approval else ApprovalStatus.PENDING_REVIEW
        comments = self.list_comments(target_room_id) if target_room_id else []

        return ReviewSessionPayload(
            link_id=link.link_id,
            token=link.token,
            permission=link.permission,
            allow_comments=link.allow_comments,
            allow_approvals=link.allow_approvals,
            project_id=link.project_id,
            project_name=project_name,
            currency=currency,
            property_address=property_address,
            room_id=target_room_id or "room_preview",
            room_name=room_name,
            room_type=room_type,
            original_image_url=original_image_url,
            selected_variant_id=selected_variant_id,
            selected_variant_image_url=selected_variant_image_url,
            selected_variant_style=selected_variant_style,
            approval_status=approval_status,
            latest_approval=latest_approval,
            comments=comments,
            available_variants=available_variants,
        )

    # ==========================
    # Professional Output & Branding (Milestone 5.3)
    # ==========================
    def update_project_branding(self, project_id: str, branding_data: Dict[str, Any]) -> StudioBranding:
        proj = self.projects.get(project_id)
        if not proj:
            raise ValueError(f"Project {project_id} not found")

        current = proj.branding.model_dump()
        for k, v in branding_data.items():
            if v is not None:
                current[k] = v
        proj.branding = StudioBranding(**current)
        proj.updated_at = datetime.now(timezone.utc)
        return proj.branding

    def get_project_branding(self, project_id: str) -> StudioBranding:
        proj = self.projects.get(project_id)
        if not proj:
            raise ValueError(f"Project {project_id} not found")
        return proj.branding

    def generate_export_dossier(self, project_id: str) -> ProfessionalExportDossier:
        proj = self.projects.get(project_id)
        if not proj:
            raise ValueError(f"Project {project_id} not found")

        client = self.clients.get(proj.client_id) if proj.client_id else None

        room_sheets: List[RoomSheetSummary] = []
        measurement_schedules: List[MeasurementScheduleItem] = []
        total_area = 0.0
        total_budget = 0.0

        for r_id in proj.room_ids:
            room = self.rooms.get(r_id)
            if not room:
                continue

            area = 0.0
            if room.geometry and room.geometry.floor_area_sqm:
                area = room.geometry.floor_area_sqm
            elif room.material_takeoff and room.material_takeoff.total_floor_area_sqm:
                area = room.material_takeoff.total_floor_area_sqm
            elif getattr(room, "floor_area_sqm", None):
                area = room.floor_area_sqm
            total_area += area

            # Variant selection
            var_id = None
            var_title = None
            var_style = None
            var_url = None
            var_cost = 0.0
            if room.versions:
                latest = room.versions[-1]
                if latest.variants:
                    fav = next((v for v in latest.variants if v.is_favorite), latest.variants[0])
                    var_id = fav.variant_id
                    var_title = fav.title
                    var_style = getattr(fav, "style", getattr(fav, "style_name", "Modern"))
                    var_url = fav.image_url
                    var_cost = getattr(fav, "estimated_cost", getattr(fav, "estimated_budget", 0.0)) or 0.0

            budget = 0.0
            if room.budget_plan:
                budget = room.budget_plan.grand_total_estimated
            elif var_cost > 0.0:
                budget = var_cost
            total_budget += budget

            latest_appr = self.get_latest_approval(r_id)
            appr_status = latest_appr.status.value if latest_appr else "PENDING_REVIEW"

            takeoff_count = len(room.material_takeoff.items) if room.material_takeoff else 0
            product_count = len(room.product_recommendations.recommendations) if room.product_recommendations else 0

            seq_steps = [
                "1. Site preparation, protection & hoarding",
                "2. Demolition and non-structural strip-out",
                "3. Concealed electrical conduit & plumbing rough-in",
                "4. Wall & ceiling plasterboard / skim-coat preparation",
                "5. Floor tiling / engineered wood installation",
                "6. Custom built-in cabinetry & joinery installation",
                "7. Painting & architectural finishes",
                "8. Electrical fixtures, switches & lighting installation",
                "9. FF&E furniture placement & styling",
                "10. Final inspection, defect rectification & handover",
            ]

            room_sheets.append(RoomSheetSummary(
                room_id=room.id,
                room_name=room.name,
                room_type=room.room_type,
                floor_area_sqm=round(area, 2),
                ceiling_height_m=2.8,
                selected_variant_id=var_id,
                selected_variant_title=var_title,
                selected_variant_style=var_style,
                selected_variant_image_url=var_url,
                estimated_budget=round(budget, 2),
                material_takeoff_item_count=takeoff_count,
                curated_product_count=product_count,
                approval_status=str(appr_status),
                execution_sequence_steps=seq_steps,
            ))

            # Measurements
            for m in room.measurements:
                conf = getattr(m, "confidence", 0.9)
                src = getattr(m, "source", "ESTIMATED")
                src_val = src.value if hasattr(src, "value") else str(src)
                ver = getattr(m, "verified_by_user", False)
                req_check = not ver or conf < 0.90
                measurement_schedules.append(MeasurementScheduleItem(
                    room_id=room.id,
                    room_name=room.name,
                    entity_label=getattr(m, "entity_type", "Room Dimension").capitalize(),
                    dimension_type=getattr(m, "measurement_type", "Dimension"),
                    value=round(getattr(m, "value", 0.0), 3),
                    unit=getattr(m, "unit", "m"),
                    confidence=round(conf, 2),
                    source=src_val,
                    verified_by_user=ver,
                    requires_site_verification=req_check,
                    notes=getattr(m, "display_string", None),
                ))

        assumption_schedules = [
            AssumptionScheduleItem(
                category="STRUCTURAL",
                scope="Internal Partitions & Openings",
                assumption_description="All modified walls are assumed non-load-bearing drywall or light masonry. Structural columns and transfer beams remain untouched.",
                risk_level="HIGH",
                recommendation="Licensed structural PE review mandatory if masonry demolition exceeds 3m continuous span.",
            ),
            AssumptionScheduleItem(
                category="MEP_ELECTRICAL",
                scope="Power & Smart Lighting Circuits",
                assumption_description="Existing Main Distribution Board (DB) contains sufficient spare breaker poles and 40A incoming supply.",
                risk_level="MEDIUM",
                recommendation="Licensed wireman to test loop impedance and verify residual current device (RCD) sensitivity prior to first fix.",
            ),
            AssumptionScheduleItem(
                category="MEP_PLUMBING",
                scope="Wet Area Soil & Waste Drainage",
                assumption_description="Sanitary fixtures relocated within 1.5m radial distance of existing soil stack; minimum 1:40 drain gradient maintained without structural slab coring.",
                risk_level="HIGH",
                recommendation="CCTV inspection of vertical stack and water pressure test required before drylining concealment.",
            ),
            AssumptionScheduleItem(
                category="WATERPROOFING",
                scope="Bathrooms & Kitchen Wet Zones",
                assumption_description="Substrate will receive 2 coats of elastomeric polyurethane waterproof membrane with 300mm upturn at perimeters.",
                risk_level="HIGH",
                recommendation="Perform 24-hour flood ponding test signed off by clerk of works prior to screed and tile installation.",
            ),
            AssumptionScheduleItem(
                category="SUBSTRATE",
                scope="Floor Screed & Leveling",
                assumption_description="Existing concrete slab deflection within L/360. Self-leveling compound factored into bill of quantities for surface tolerances within +/- 2mm over 2m straightedge.",
                risk_level="LOW",
                recommendation="Moisture barrier primer required before applying engineered timber flooring adhesive.",
            ),
            AssumptionScheduleItem(
                category="PERMITTING",
                scope="Statutory & Building Management",
                assumption_description="Standard residential renovation permitting assumed. Work hours restricted to statutory condo / council renovation bylaws.",
                risk_level="LOW",
                recommendation="Client and main contractor to deposit renovation bond and submit insurances (CAR & Workmen Comp) to building management.",
            ),
        ]

        dossier = ProfessionalExportDossier(
            project_id=proj.id,
            project_name=proj.name,
            status=proj.status.value,
            property_address=proj.property_address,
            client_name=client.name if client else None,
            client_company=client.company if client else None,
            client_email=client.email if client else None,
            branding=proj.branding,
            dossier_version="v1.0",
            total_rooms=len(room_sheets),
            total_floor_area_sqm=round(total_area, 2),
            total_estimated_budget=round(total_budget, 2),
            currency=proj.currency,
            room_sheets=room_sheets,
            measurement_schedules=measurement_schedules,
            assumption_schedules=assumption_schedules,
        )

        dossier.printable_html = self._generate_printable_html(dossier)
        return dossier

    def _generate_printable_html(self, dossier: ProfessionalExportDossier) -> str:
        b = dossier.branding
        primary = b.primary_color_hex
        secondary = b.secondary_color_hex

        # Build room sheet rows
        rooms_html = ""
        for r in dossier.room_sheets:
            rooms_html += f"""
            <div class="room-card">
              <div class="room-header">
                <h3>{r.room_name} <span class="badge">{r.room_type}</span></h3>
                <span class="status-tag">{r.approval_status}</span>
              </div>
              <p><strong>Floor Area:</strong> {r.floor_area_sqm:.1f} m² | <strong>Ceiling:</strong> {r.ceiling_height_m:.1f} m | <strong>Target Budget:</strong> {dossier.currency} {r.estimated_budget:,.2f}</p>
              <p><strong>Design Concept:</strong> {r.selected_variant_style or 'Design Concept'} ({r.selected_variant_title or 'Variant 1'})</p>
              <div class="meta-row">
                <span>Material Takeoff: {r.material_takeoff_item_count} items</span>
                <span>Curated Products: {r.curated_product_count} items</span>
              </div>
            </div>
            """

        # Build measurement schedule rows
        meas_rows = ""
        for m in dossier.measurement_schedules:
            badge_class = "verified" if m.verified_by_user else ("warning" if m.requires_site_verification else "estimate")
            check_label = "Confirmed" if m.verified_by_user else ("Site Check Required" if m.requires_site_verification else "Approximate")
            meas_rows += f"""
            <tr>
              <td>{m.room_name}</td>
              <td>{m.entity_label}</td>
              <td>{m.dimension_type}</td>
              <td><strong>{m.value:.2f} {m.unit}</strong></td>
              <td>{int(m.confidence * 100)}%</td>
              <td><code>{m.source}</code></td>
              <td><span class="badge {badge_class}">{check_label}</span></td>
            </tr>
            """

        # Build assumptions rows
        assump_rows = ""
        for a in dossier.assumption_schedules:
            risk_class = "risk-" + a.risk_level.lower()
            assump_rows += f"""
            <tr>
              <td><strong>{a.category}</strong></td>
              <td>{a.scope}</td>
              <td>{a.assumption_description}</td>
              <td><span class="badge {risk_class}">{a.risk_level}</span></td>
              <td>{a.recommendation}</td>
            </tr>
            """

        html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>{dossier.project_name} — Professional Design Handover Dossier</title>
  <style>
    @page {{ size: A4 portrait; margin: 18mm 15mm; }}
    body {{
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      color: #1e293b;
      background: #f8fafc;
      margin: 0;
      padding: 24px;
      line-height: 1.5;
    }}
    .dossier-container {{
      max-width: 900px;
      margin: 0 auto;
      background: #ffffff;
      padding: 40px;
      border-radius: 12px;
      box-shadow: 0 4px 20px rgba(0,0,0,0.06);
    }}
    .header-bar {{
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      border-bottom: 3px solid {primary};
      padding-bottom: 20px;
      margin-bottom: 30px;
    }}
    .firm-name {{ font-size: 24px; font-weight: 800; color: {secondary}; margin: 0; }}
    .tagline {{ font-size: 13px; color: #64748b; margin-top: 4px; }}
    .license {{ font-size: 11px; color: #94a3b8; margin-top: 2px; }}
    .project-meta {{
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 16px;
      background: #f1f5f9;
      padding: 18px 24px;
      border-radius: 8px;
      margin-bottom: 30px;
    }}
    .meta-item label {{ display: block; font-size: 11px; text-transform: uppercase; color: #64748b; font-weight: 700; }}
    .meta-item span {{ font-size: 15px; font-weight: 600; color: #0f172a; }}
    .kpi-row {{
      display: flex;
      gap: 16px;
      margin-bottom: 32px;
    }}
    .kpi-card {{
      flex: 1;
      background: #ffffff;
      border: 1px solid #e2e8f0;
      padding: 16px;
      border-radius: 8px;
      border-left: 4px solid {primary};
    }}
    .kpi-card h4 {{ margin: 0 0 6px 0; font-size: 12px; color: #64748b; text-transform: uppercase; }}
    .kpi-card p {{ margin: 0; font-size: 22px; font-weight: 800; color: #0f172a; }}
    h2 {{ font-size: 18px; font-weight: 700; color: {secondary}; border-left: 4px solid {primary}; padding-left: 10px; margin-top: 36px; margin-bottom: 16px; }}
    .room-card {{
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      padding: 16px;
      margin-bottom: 14px;
      background: #ffffff;
    }}
    .room-header {{ display: flex; justify-content: space-between; align-items: center; }}
    .room-header h3 {{ margin: 0; font-size: 16px; }}
    table {{ width: 100%; border-collapse: collapse; font-size: 12px; margin-top: 10px; }}
    th, td {{ padding: 10px 12px; text-align: left; border-bottom: 1px solid #e2e8f0; }}
    th {{ background: #f8fafc; font-weight: 700; color: #475569; }}
    .badge {{
      display: inline-block;
      padding: 2px 8px;
      border-radius: 4px;
      font-size: 10px;
      font-weight: 700;
    }}
    .badge.verified {{ background: #dcfce7; color: #15803d; }}
    .badge.warning {{ background: #fef3c7; color: #b45309; }}
    .badge.estimate {{ background: #e0e7ff; color: #4338ca; }}
    .badge.risk-high {{ background: #fee2e2; color: #b91c1c; }}
    .badge.risk-medium {{ background: #fef3c7; color: #b45309; }}
    .badge.risk-low {{ background: #dcfce7; color: #15803d; }}
    .status-tag {{ background: #e2e8f0; color: #334155; padding: 3px 8px; border-radius: 4px; font-size: 11px; font-weight: 600; }}
    .disclaimer-box {{
      background: #fffbeb;
      border: 1px solid #fde68a;
      padding: 16px;
      border-radius: 8px;
      margin-top: 40px;
      font-size: 11px;
      color: #92400e;
      line-height: 1.6;
    }}
    .signature-row {{
      display: flex;
      justify-content: space-between;
      margin-top: 50px;
      padding-top: 20px;
    }}
    .signature-box {{ width: 45%; border-top: 1px dashed #94a3b8; padding-top: 8px; font-size: 12px; color: #475569; }}
    @media print {{
      body {{ background: #ffffff; padding: 0; }}
      .dossier-container {{ box-shadow: none; padding: 0; }}
      .page-break {{ page-break-before: always; }}
    }}
  </style>
</head>
<body>
  <div class="dossier-container">
    <div class="header-bar">
      <div>
        <h1 class="firm-name">{b.firm_name}</h1>
        <div class="tagline">{b.tagline}</div>
        <div class="license">Practice License: {b.license_number} | Contact: {b.contact_email}</div>
      </div>
      <div style="text-align: right;">
        <span class="status-tag" style="background: {primary}; color: #ffffff; font-size: 12px; padding: 6px 12px;">HANDOVER DOSSIER {dossier.dossier_version}</span>
        <div style="font-size: 11px; color: #64748b; margin-top: 6px;">Date: {dossier.generated_at.strftime('%d %B %Y')}</div>
      </div>
    </div>

    <div class="project-meta">
      <div class="meta-item">
        <label>Project Title</label>
        <span>{dossier.project_name}</span>
      </div>
      <div class="meta-item">
        <label>Client</label>
        <span>{dossier.client_name or 'Private Client'} {f"({dossier.client_company})" if dossier.client_company else ""}</span>
      </div>
      <div class="meta-item">
        <label>Property Address</label>
        <span>{dossier.property_address or 'On-site address pending verification'}</span>
      </div>
      <div class="meta-item">
        <label>Lifecycle Stage</label>
        <span>{dossier.status.replace('_', ' ')}</span>
      </div>
    </div>

    <div class="kpi-row">
      <div class="kpi-card">
        <h4>Total Scanned Rooms</h4>
        <p>{dossier.total_rooms}</p>
      </div>
      <div class="kpi-card">
        <h4>Total Floor Area</h4>
        <p>{dossier.total_floor_area_sqm:.1f} m²</p>
      </div>
      <div class="kpi-card">
        <h4>Cumulative Budget Estimate</h4>
        <p>{dossier.currency} {dossier.total_estimated_budget:,.2f}</p>
      </div>
    </div>

    <h2>1. Multi-Room Concept Schedule</h2>
    {rooms_html if rooms_html else '<p style="color: #64748b; font-size: 13px;">No room sheets generated yet.</p>'}

    <div class="page-break"></div>

    <h2>2. Tabular Measurement Schedule</h2>
    <table>
      <thead>
        <tr>
          <th>Room</th>
          <th>Entity</th>
          <th>Dimension</th>
          <th>Value</th>
          <th>Confidence</th>
          <th>Source</th>
          <th>Status</th>
        </tr>
      </thead>
      <tbody>
        {meas_rows if meas_rows else '<tr><td colspan="7" style="text-align: center; color: #64748b;">No room measurements recorded.</td></tr>'}
      </tbody>
    </table>

    <h2>3. Architectural & Construction Assumptions Schedule</h2>
    <table>
      <thead>
        <tr>
          <th>Category</th>
          <th>Scope</th>
          <th>Technical Assumption</th>
          <th>Risk</th>
          <th>Mandatory Verification Recommendation</th>
        </tr>
      </thead>
      <tbody>
        {assump_rows}
      </tbody>
    </table>

    <div class="disclaimer-box">
      <strong>Professional Regulatory & Safety Notice:</strong><br>
      {b.custom_disclaimer}
    </div>

    <div class="signature-row">
      <div class="signature-box">
        <strong>Prepared By (Lead Designer):</strong><br><br>
        Signature: ___________________________<br>
        Name: {b.firm_name}<br>
        Date: {dossier.generated_at.strftime('%d %b %Y')}
      </div>
      <div class="signature-box">
        <strong>Accepted & Acknowledged By (Client):</strong><br><br>
        Signature: ___________________________<br>
        Name: {dossier.client_name or 'Client Authorized Signatory'}<br>
        Date: ___________________________
      </div>
    </div>
  </div>
</body>
</html>
"""
        return html


# Global singleton repository instance for the running service
repository = InMemoryRepository()
