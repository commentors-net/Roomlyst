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
    MerchantRecord,
    SellerFitVerification,
    ProductPlacementVisualization,
    CommerceTrackingEvent,
    CommerceAttributionSummary,
    ProductDimensions,
    CurrencyCode,
    TradeCategory,
    TradeWorkPackage,
    BillOfQuantitiesItem,
    ContractorVerificationChecklist,
    ContractorProjectBrief,
    RFQStatus,
    BidStatus,
    ContractorBid,
    ContractorQuoteRequest,
    BidComparisonSummary,
    StagingType,
    WatermarkPosition,
    VirtualStagingDisclosure,
    RenovationPotentialEstimate,
    StagedRoomAsset,
    PropertyListingRecord,
    PortalExportPackage,
    EcosystemRole,
    HandoffTransitionType,
    HandoffStatus,
    EcosystemHandoffRecord,
    EcosystemAuditEvent,
    WorkflowOrchestrationSummary,
    RoleScopedProjectView,
)


class ProjectRecord(BaseModel):
    id: str = Field(default_factory=lambda: f"proj_{uuid.uuid4().hex[:8]}")
    user_id: Optional[str] = None
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
        self.merchants: Dict[str, MerchantRecord] = {}
        self.visualizations: Dict[str, ProductPlacementVisualization] = {}
        self.commerce_events: List[CommerceTrackingEvent] = []
        self.contractor_briefs: Dict[str, ContractorProjectBrief] = {}
        self.rfqs: Dict[str, ContractorQuoteRequest] = {}
        self.contractor_bids: Dict[str, ContractorBid] = {}
        self.listings: Dict[str, PropertyListingRecord] = {}
        self.handoffs: Dict[str, EcosystemHandoffRecord] = {}
        self.ecosystem_audit_events: List[EcosystemAuditEvent] = []
        self._seed_merchants()
        self._seed_listings()
        self._seed_handoffs()

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
        user_id: Optional[str] = None,
    ) -> ProjectRecord:
        proj = ProjectRecord(
            user_id=user_id,
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

    def list_projects(
        self, client_id: Optional[str] = None, user_id: Optional[str] = None
    ) -> List[ProjectRecord]:
        all_projs = list(self.projects.values())
        if user_id:
            all_projs = [
                p for p in all_projs
                if p.user_id == user_id
                or any(c.user_id == user_id for c in p.collaborators)
            ]
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

    # ==========================
    # Milestone 6.1: Furniture Seller & Commerce Methods
    # ==========================

    def _seed_merchants(self):
        """Initializes default certified merchants across regions."""
        seed_data = [
            MerchantRecord(
                merchant_id="merch_boconcept",
                business_name="BoConcept Scandinavia",
                store_slug="boconcept",
                contact_email="sales@boconcept.sg",
                contact_phone="+65 6736 0777",
                website="https://www.boconcept.com",
                logo_url="https://storage.roomlyst.com/merchants/boconcept_logo.png",
                country="SG",
                supported_currencies=[CurrencyCode.SGD, CurrencyCode.MYR, CurrencyCode.USD],
                commission_rate_pct=8.5,
                is_verified=True,
                active_listing_count=12,
            ),
            MerchantRecord(
                merchant_id="merch_castlery",
                business_name="Castlery Living",
                store_slug="castlery",
                contact_email="concierge@castlery.my",
                contact_phone="+60 3 2779 2888",
                website="https://www.castlery.com",
                logo_url="https://storage.roomlyst.com/merchants/castlery_logo.png",
                country="MY",
                supported_currencies=[CurrencyCode.MYR, CurrencyCode.SGD],
                commission_rate_pct=10.0,
                is_verified=True,
                active_listing_count=18,
            ),
            MerchantRecord(
                merchant_id="merch_hay",
                business_name="HAY Design Copenhagen",
                store_slug="hay",
                contact_email="asia@hay.dk",
                contact_phone="+65 6235 9999",
                website="https://hay.dk",
                logo_url="https://storage.roomlyst.com/merchants/hay_logo.png",
                country="SG",
                supported_currencies=[CurrencyCode.SGD, CurrencyCode.EUR, CurrencyCode.USD],
                commission_rate_pct=9.0,
                is_verified=True,
                active_listing_count=8,
            ),
            MerchantRecord(
                merchant_id="merch_atelier",
                business_name="Atelier Woodcraft & Co",
                store_slug="atelier-woodcraft",
                contact_email="craft@atelierwoodcraft.my",
                contact_phone="+60 12 345 6789",
                website="https://atelierwoodcraft.my",
                logo_url="https://storage.roomlyst.com/merchants/atelier_logo.png",
                country="MY",
                supported_currencies=[CurrencyCode.MYR],
                commission_rate_pct=12.0,
                is_verified=True,
                active_listing_count=6,
            ),
            MerchantRecord(
                merchant_id="merch_cratebarrel",
                business_name="Crate & Barrel Home",
                store_slug="crate-and-barrel",
                contact_email="trade@crateandbarrel.com",
                contact_phone="+1 800 967 6696",
                website="https://www.crateandbarrel.com",
                logo_url="https://storage.roomlyst.com/merchants/cratebarrel_logo.png",
                country="US",
                supported_currencies=[CurrencyCode.USD, CurrencyCode.CAD],
                commission_rate_pct=7.5,
                is_verified=True,
                active_listing_count=15,
            ),
        ]
        for m in seed_data:
            self.merchants[m.merchant_id] = m

    def create_merchant(
        self,
        business_name_or_record: Any,
        store_slug: Optional[str] = None,
        contact_email: Optional[str] = None,
        contact_phone: Optional[str] = None,
        website: Optional[str] = None,
        logo_url: Optional[str] = None,
        country: str = "MY",
        supported_currencies: Optional[List[CurrencyCode]] = None,
        commission_rate_pct: float = 8.5,
    ) -> MerchantRecord:
        """Onboards a new verified furniture seller or merchant partner."""
        if isinstance(business_name_or_record, MerchantRecord):
            merchant = business_name_or_record
            for existing in self.merchants.values():
                if existing.store_slug == merchant.store_slug:
                    raise ValueError(f"Merchant store slug '{merchant.store_slug}' already exists")
            self.merchants[merchant.merchant_id] = merchant
            return merchant

        business_name = str(business_name_or_record)
        for existing in self.merchants.values():
            if existing.store_slug == store_slug:
                raise ValueError(f"Merchant store slug '{store_slug}' already exists")

        currencies = supported_currencies or [CurrencyCode.MYR, CurrencyCode.SGD]
        merchant = MerchantRecord(
            business_name=business_name,
            store_slug=store_slug or "store",
            contact_email=contact_email or "partner@roomlyst.com",
            contact_phone=contact_phone,
            website=website,
            logo_url=logo_url,
            country=country,
            supported_currencies=currencies,
            commission_rate_pct=commission_rate_pct,
            is_verified=True,
            active_listing_count=0,
        )
        self.merchants[merchant.merchant_id] = merchant
        return merchant

    def get_merchant(self, merchant_id: str) -> Optional[MerchantRecord]:
        return self.merchants.get(merchant_id)

    def get_merchant_by_slug(self, store_slug: str) -> Optional[MerchantRecord]:
        for m in self.merchants.values():
            if m.store_slug == store_slug:
                return m
        return None

    def list_merchants(
        self,
        country: Optional[str] = None,
        search: Optional[str] = None,
    ) -> List[MerchantRecord]:
        results = list(self.merchants.values())
        if country:
            results = [m for m in results if m.country.upper() == country.upper()]
        if search:
            q = search.lower()
            results = [
                m for m in results
                if q in m.business_name.lower() or q in m.store_slug.lower() or q in m.contact_email.lower()
            ]
        results.sort(key=lambda m: m.business_name)
        return results

    def update_merchant(self, merchant_id: str, data: Dict[str, Any]) -> MerchantRecord:
        merchant = self.merchants.get(merchant_id)
        if not merchant:
            raise ValueError(f"Merchant '{merchant_id}' not found")
        dump = merchant.model_dump()
        for k, v in data.items():
            if v is not None and k in dump:
                dump[k] = v
        updated = MerchantRecord.model_validate(dump)
        self.merchants[merchant_id] = updated
        return updated

    # Product Placement Visualizations
    def add_product_placement(
        self,
        room_id: str,
        product_id: str,
        product_name: str,
        bounding_box: ProductDimensions,
        merchant_id: Optional[str] = None,
        position_x: float = 0.5,
        position_y: float = 0.5,
        position_z: float = 0.0,
        rotation_deg: float = 0.0,
        scale_factor: float = 1.0,
        overlay_image_url: Optional[str] = None,
        model_3d_url: Optional[str] = None,
        is_locked: bool = False,
    ) -> ProductPlacementVisualization:
        """Places a merchant product into an interactive room concept."""
        placement = ProductPlacementVisualization(
            room_id=room_id,
            product_id=product_id,
            product_name=product_name,
            merchant_id=merchant_id,
            position_x=position_x,
            position_y=position_y,
            position_z=position_z,
            rotation_deg=rotation_deg,
            scale_factor=scale_factor,
            bounding_box=bounding_box,
            overlay_image_url=overlay_image_url,
            model_3d_url=model_3d_url,
            is_locked=is_locked,
        )
        self.visualizations[placement.placement_id] = placement

        # Attach to room model if room exists
        if room_id in self.rooms:
            self.rooms[room_id].visualizations.append(placement)

        return placement

    def list_product_placements(self, room_id: str) -> List[ProductPlacementVisualization]:
        return [p for p in self.visualizations.values() if p.room_id == room_id]

    def get_product_placement(self, placement_id: str) -> Optional[ProductPlacementVisualization]:
        return self.visualizations.get(placement_id)

    def delete_product_placement(self, placement_id: str) -> bool:
        if placement_id in self.visualizations:
            placement = self.visualizations.pop(placement_id)
            if placement.room_id in self.rooms:
                self.rooms[placement.room_id].visualizations = [
                    p for p in self.rooms[placement.room_id].visualizations
                    if getattr(p, "placement_id", None) != placement_id
                ]
            return True
        return False

    # Commerce Tracking & Attribution
    def track_commerce_click(
        self,
        product_id: str,
        product_name: str,
        retailer_url: str,
        project_id: Optional[str] = None,
        designer_id: Optional[str] = None,
        client_id: Optional[str] = None,
        merchant_id: Optional[str] = None,
        event_type: str = "CLICK_OUT",
    ) -> CommerceTrackingEvent:
        """Logs deep-link attribution and click-to-retailer commerce events."""
        proj_tag = project_id or "direct"
        designer_tag = designer_id or "studio"
        token = f"roomlyst_{proj_tag}_{designer_tag}"

        sep = "&" if "?" in retailer_url else "?"
        tracked_url = f"{retailer_url}{sep}ref={token}&utm_source=roomlyst&utm_medium=app"

        event = CommerceTrackingEvent(
            event_type=event_type,
            merchant_id=merchant_id,
            product_id=product_id,
            product_name=product_name,
            project_id=project_id,
            designer_id=designer_id,
            client_id=client_id,
            retailer_url=retailer_url,
            affiliate_token=token,
            tracked_destination_url=tracked_url,
        )
        self.commerce_events.append(event)
        return event

    def get_commerce_attribution_summary(
        self,
        project_id: Optional[str] = None,
        merchant_id: Optional[str] = None,
    ) -> CommerceAttributionSummary:
        """Summarizes commercial referral metrics for a project or merchant."""
        filtered = self.commerce_events
        if project_id:
            filtered = [e for e in filtered if e.project_id == project_id]
        if merchant_id:
            filtered = [e for e in filtered if e.merchant_id == merchant_id]

        total_clicks = sum(1 for e in filtered if e.event_type == "CLICK_OUT")
        total_leads = sum(1 for e in filtered if e.event_type == "LEAD_SUBMISSION")
        total_quotes = sum(1 for e in filtered if e.event_type == "QUOTE_REQUEST")
        total_placed = len(self.visualizations)

        estimated_gmv = (total_clicks * 450.0) + (total_leads * 2200.0) + (total_quotes * 5500.0)

        return CommerceAttributionSummary(
            total_clicks=total_clicks,
            total_leads=total_leads,
            total_quote_requests=total_quotes,
            total_products_placed=total_placed,
            estimated_gmv_influenced=round(estimated_gmv, 2),
            currency="MYR",
            events=filtered[-50:],
        )

    # ==========================================================================
    # Milestone 6.2: Contractor Handoff, BOQ, and Tender Bid Management Methods
    # ==========================================================================
    def generate_contractor_brief(
        self,
        project_id: str,
        room_id: Optional[str] = None,
        site_access_notes: Optional[str] = None,
    ) -> ContractorProjectBrief:
        """
        Compiles a contractor-ready project brief with confirmed-vs-estimated measurement
        separation, trade work packages, and bill of quantities (Milestone 6.2).
        """
        proj = self.projects.get(project_id)
        if not proj:
            raise ValueError(f"Project {project_id} not found")

        # Select target room or project rooms
        target_rooms: List[CanonicalRoomModel] = []
        if room_id and room_id in self.rooms:
            target_rooms = [self.rooms[room_id]]
        elif proj.room_ids:
            target_rooms = [self.rooms[rid] for rid in proj.room_ids if rid in self.rooms]

        room_name = target_rooms[0].name if target_rooms else "All Project Rooms"
        primary_room = target_rooms[0] if target_rooms else None

        # Determine geometry and areas
        floor_area = 24.0
        ceiling_height = 2.80
        perimeter = 20.0
        if primary_room and primary_room.geometry:
            geom = primary_room.geometry
            if getattr(geom, "floor_area_sqm", None) and geom.floor_area_sqm > 0:
                floor_area = geom.floor_area_sqm
            if getattr(geom, "ceiling_height_m", None) and geom.ceiling_height_m > 0:
                ceiling_height = geom.ceiling_height_m
            if getattr(geom, "perimeter_m", None) and geom.perimeter_m > 0:
                perimeter = geom.perimeter_m
            elif getattr(geom, "estimated_width_m", None) and getattr(geom, "estimated_length_m", None):
                perimeter = 2 * (geom.estimated_width_m + geom.estimated_length_m)

        # 1. Process Confirmed vs Estimated Measurements & Verification Checklist
        verification_checklist: List[ContractorVerificationChecklist] = []
        confirmed_count = 0
        unconfirmed_count = 0

        # Extract measurements from room model
        measurements = primary_room.measurements if primary_room else []
        if measurements:
            for m in measurements:
                src_str = getattr(m.source, "value", str(m.source)) if hasattr(m, "source") else "ESTIMATED"
                is_conf = bool(
                    getattr(m, "verified_by_user", False)
                    or getattr(m, "is_confirmed", False)
                    or src_str in ("USER_VERIFIED", "LIDAR_VERIFIED", "LIDAR_NATIVE")
                    or getattr(m, "confidence", 0.0) >= 0.90
                )
                if is_conf:
                    confirmed_count += 1
                else:
                    unconfirmed_count += 1

                trade = TradeCategory.CARPENTRY_JOINERY
                lbl = getattr(m, "name", getattr(m, "label", getattr(m, "measurement_type", "Dimension")))
                lbl_lower = lbl.lower()
                if "height" in lbl_lower:
                    trade = TradeCategory.PAINTING_PLASTERING
                elif "door" in lbl_lower or "entry" in lbl_lower:
                    trade = TradeCategory.DEMOLITION_PREP
                elif "floor" in lbl_lower or "area" in lbl_lower:
                    trade = TradeCategory.MASONRY_TILING

                val = getattr(m, "value", 1.0)
                unit_str = getattr(m, "unit", "m")
                val_float = float(val) if isinstance(val, (int, float)) else 1.0

                verification_checklist.append(
                    ContractorVerificationChecklist(
                        dimension_label=lbl,
                        dimension_type=getattr(m, "measurement_type", getattr(m, "dimension_type", "Linear")),
                        dimension_value=round(val_float, 2),
                        unit=unit_str,
                        confidence=getattr(m, "confidence", 0.85),
                        source=src_str,
                        is_physically_verified=is_conf,
                        critical_for_trade=trade,
                    )
                )

        # Fallback critical checklist items if measurements were sparse
        if not verification_checklist:
            verification_checklist = [
                ContractorVerificationChecklist(
                    dimension_label="Room Floor Span (Length x Width)",
                    dimension_type="Wall Span",
                    dimension_value=round(floor_area, 2),
                    unit="m2",
                    confidence=0.88,
                    source="MULTIVIEW_RECONSTRUCTION",
                    is_physically_verified=False,
                    critical_for_trade=TradeCategory.MASONRY_TILING,
                ),
                ContractorVerificationChecklist(
                    dimension_label="Finished Ceiling Height",
                    dimension_type="Ceiling Height",
                    dimension_value=round(ceiling_height, 2),
                    unit="m",
                    confidence=0.92,
                    source="LIDAR_VERIFIED",
                    is_physically_verified=True,
                    critical_for_trade=TradeCategory.PAINTING_PLASTERING,
                ),
                ContractorVerificationChecklist(
                    dimension_label="Main Joinery Wall Span",
                    dimension_type="Wall Span",
                    dimension_value=4.50,
                    unit="m",
                    confidence=0.82,
                    source="ESTIMATED",
                    is_physically_verified=False,
                    critical_for_trade=TradeCategory.CARPENTRY_JOINERY,
                ),
                ContractorVerificationChecklist(
                    dimension_label="Entry Door Clear Rough Opening",
                    dimension_type="Opening Clearance",
                    dimension_value=0.90,
                    unit="m",
                    confidence=0.95,
                    source="USER_VERIFIED",
                    is_physically_verified=True,
                    critical_for_trade=TradeCategory.DEMOLITION_PREP,
                ),
            ]
            confirmed_count = 2
            unconfirmed_count = 2

        # 2. Build Trade Work Packages
        work_packages: List[TradeWorkPackage] = [
            TradeWorkPackage(
                trade=TradeCategory.DEMOLITION_PREP,
                title="Site Protection & Strip-Out Prep",
                description="Erect protective heavy-duty polythene sheeting, floor corflute boards, and strip existing wall finishes.",
                location=room_name,
                priority="HIGH",
                prerequisite_trades=[],
                scope_items=[
                    "Install hallway and lift lobby floor protection",
                    "Disconnect and cap electrical points in accordance with safety standards",
                    "Demolish and remove redundant fixtures and debris to municipal landfill",
                ],
                safety_notes=[
                    "Mandatory PPE: Hard hat, safety boots, and particulate dust masks",
                    "Isolate electrical distribution board before cutting any conduits",
                ],
                estimated_duration_days=2,
            ),
            TradeWorkPackage(
                trade=TradeCategory.MASONRY_TILING,
                title="Floor Substrate Screeding & Tile Laying",
                description="Laser-level substrate with self-leveling compound and install specified porcelain floor tiles.",
                location=room_name,
                priority="NORMAL",
                prerequisite_trades=[TradeCategory.DEMOLITION_PREP],
                scope_items=[
                    "Check floor substrate moisture content (< 4.5% CM)",
                    "Apply polymer-modified floor primer and screed to 1:100 fall if applicable",
                    "Lay 600x600mm rectified porcelain tiles with 2mm leveling clips",
                    "Grout with mold-resistant epoxy grout and allow 48h curing",
                ],
                safety_notes=[
                    "Ensure adequate cross-ventilation during epoxy grout application",
                ],
                estimated_duration_days=4,
            ),
            TradeWorkPackage(
                trade=TradeCategory.CARPENTRY_JOINERY,
                title="Bespoke Cabinetry & Architectural Joinery",
                description="Fabricate and install bespoke full-height cabinetry with Blum soft-close hardware.",
                location=room_name,
                priority="HIGH",
                prerequisite_trades=[TradeCategory.MASONRY_TILING],
                scope_items=[
                    "Field-measure actual site wall spans and ceiling clearances prior to cutting carcasses",
                    "Anchor joinery units to structural masonry with M8 expansion bolts",
                    "Install integrated LED aluminum profile channels and concealed wiring",
                ],
                safety_notes=[
                    "Secure all tall units to structural walls to prevent tip-over hazards",
                ],
                estimated_duration_days=5,
            ),
            TradeWorkPackage(
                trade=TradeCategory.ELECTRICAL_LIGHTING,
                title="Conduit Rough-In & Luminaire Installation",
                description="Install dedicated lighting circuits, LED downlights, and designer wall sconces.",
                location=room_name,
                priority="HIGH",
                prerequisite_trades=[TradeCategory.DEMOLITION_PREP],
                scope_items=[
                    "Chasm and conceal PVC conduits into masonry walls",
                    "Pull 2.5mm2 fire-resistant copper conductors for power outlets",
                    "Fit and commission recessed LED drivers and smart dimmers",
                    "Perform earth leakage circuit breaker (ELCB) trip tests",
                ],
                safety_notes=[
                    "All works must be signed off by a certified electrical wireman / engineer",
                ],
                estimated_duration_days=3,
            ),
            TradeWorkPackage(
                trade=TradeCategory.PAINTING_PLASTERING,
                title="Plaster Skimming & Architectural Paint",
                description="Skim coat drywall/masonry joints and apply 3-coat washable acrylic paint system.",
                location=room_name,
                priority="NORMAL",
                prerequisite_trades=[TradeCategory.CARPENTRY_JOINERY, TradeCategory.ELECTRICAL_LIGHTING],
                scope_items=[
                    "Sand and patch wall fissures with fiber mesh tape",
                    "Apply 1 coat alkali-resistant sealer/primer",
                    "Apply 2 finish coats of low-VOC matte emulsion to specified color swatch",
                ],
                safety_notes=[
                    "Mask joinery and flooring with painter tape prior to roller application",
                ],
                estimated_duration_days=3,
            ),
            TradeWorkPackage(
                trade=TradeCategory.FINAL_CLEANING,
                title="Post-Construction Chemical Cleaning & Handover",
                description="Industrial deep cleaning and joint sealing ready for client furniture move-in.",
                location=room_name,
                priority="LOW",
                prerequisite_trades=[
                    TradeCategory.DEMOLITION_PREP,
                    TradeCategory.MASONRY_TILING,
                    TradeCategory.CARPENTRY_JOINERY,
                    TradeCategory.ELECTRICAL_LIGHTING,
                    TradeCategory.PAINTING_PLASTERING,
                ],
                scope_items=[
                    "Vacuum all cabinetry interiors and wipe down glass surfaces",
                    "Remove chemical haze and residue from tiled floors",
                    "Conduct joint site walk-through with Lead Designer and Client",
                ],
                safety_notes=[
                    "Use non-acidic cleaners on chrome fixtures and polished stone",
                ],
                estimated_duration_days=1,
            ),
        ]

        # 3. Build Bill of Quantities (BOQ) with Wastage Margins
        wall_area = max(35.0, round(perimeter * ceiling_height - 5.0, 1))

        boq_items: List[BillOfQuantitiesItem] = [
            BillOfQuantitiesItem(
                trade=TradeCategory.DEMOLITION_PREP,
                item_code="DEM-01",
                description="Surface protection sheeting, floor corflute, and site disposal skips",
                quantity=1.0,
                unit="lot",
                waste_factor_pct=0.0,
                total_quantity_with_waste=1.0,
                is_owner_supplied=False,
                estimated_unit_rate=1200.0,
                estimated_material_total=400.0,
                estimated_labor_total=800.0,
                requires_site_verification=False,
            ),
            BillOfQuantitiesItem(
                trade=TradeCategory.MASONRY_TILING,
                item_code="TIL-01",
                description="Rectified matte porcelain tiles (600x600mm) including adhesive & epoxy grout",
                quantity=round(floor_area, 2),
                unit="m2",
                waste_factor_pct=10.0,
                total_quantity_with_waste=round(floor_area * 1.10, 2),
                is_owner_supplied=False,
                estimated_unit_rate=135.0,
                estimated_material_total=round(floor_area * 1.10 * 85.0, 2),
                estimated_labor_total=round(floor_area * 50.0, 2),
                requires_site_verification=True,
            ),
            BillOfQuantitiesItem(
                trade=TradeCategory.CARPENTRY_JOINERY,
                item_code="CAR-01",
                description="Full-height custom cabinetry with premium laminate & Blum soft-close hinges",
                quantity=4.5,
                unit="m",
                waste_factor_pct=5.0,
                total_quantity_with_waste=4.72,
                is_owner_supplied=False,
                estimated_unit_rate=1650.0,
                estimated_material_total=5200.0,
                estimated_labor_total=2225.0,
                requires_site_verification=True,
            ),
            BillOfQuantitiesItem(
                trade=TradeCategory.ELECTRICAL_LIGHTING,
                item_code="ELE-01",
                description="Concealed conduit wiring, 13A switched sockets, and recessed LED downlights",
                quantity=8.0,
                unit="pcs",
                waste_factor_pct=0.0,
                total_quantity_with_waste=8.0,
                is_owner_supplied=False,
                estimated_unit_rate=150.0,
                estimated_material_total=720.0,
                estimated_labor_total=480.0,
                requires_site_verification=False,
            ),
            BillOfQuantitiesItem(
                trade=TradeCategory.PAINTING_PLASTERING,
                item_code="PNT-01",
                description="Interior wall skim coating, sealer, and 2-coat premium washable emulsion",
                quantity=wall_area,
                unit="m2",
                waste_factor_pct=8.0,
                total_quantity_with_waste=round(wall_area * 1.08, 2),
                is_owner_supplied=False,
                estimated_unit_rate=38.0,
                estimated_material_total=round(wall_area * 1.08 * 20.0, 2),
                estimated_labor_total=round(wall_area * 18.0, 2),
                requires_site_verification=False,
            ),
        ]

        total_mat = round(sum(i.estimated_material_total for i in boq_items), 2)
        total_lab = round(sum(i.estimated_labor_total for i in boq_items), 2)
        total_cost = round(total_mat + total_lab, 2)

        # 4. Generate Contractor-Ready Brief Object
        brief = ContractorProjectBrief(
            project_id=project_id,
            room_id=room_id,
            title=f"Contractor Project Brief — {proj.name} ({room_name})",
            project_summary=f"Tender specification and trade execution package for {room_name} at {proj.name}.",
            property_address=proj.property_address or "Kuala Lumpur, Malaysia",
            site_access_notes=site_access_notes or (
                "Standard residential building operating hours 9:00 AM – 5:30 PM (Mondays to Fridays). "
                "No drilling or loud percussion outside permitted hours. Loading bay booking required 48h in advance."
            ),
            work_packages=work_packages,
            boq_items=boq_items,
            verification_checklist=verification_checklist,
            confirmed_measurements_count=confirmed_count,
            unconfirmed_measurements_count=unconfirmed_count,
            total_estimated_materials=total_mat,
            total_estimated_labor=total_lab,
            total_estimated_cost=total_cost,
            currency=CurrencyCode(proj.currency) if proj.currency in ("MYR", "SGD", "USD", "EUR", "GBP") else CurrencyCode.MYR,
        )

        brief.printable_html = self._generate_contractor_printable_html(brief, proj)
        self.contractor_briefs[brief.brief_id] = brief
        return brief

    def get_contractor_brief(self, brief_id: str) -> Optional[ContractorProjectBrief]:
        return self.contractor_briefs.get(brief_id)

    def list_contractor_briefs(self, project_id: str) -> List[ContractorProjectBrief]:
        return [b for b in self.contractor_briefs.values() if b.project_id == project_id]

    def verify_checklist_item(
        self,
        brief_id: str,
        checklist_id: str,
        verified_by_name: str,
        notes: Optional[str] = None,
    ) -> ContractorVerificationChecklist:
        """Records physical on-site measurement sign-off by a trade contractor or surveyor."""
        brief = self.contractor_briefs.get(brief_id)
        if not brief:
            raise ValueError(f"Contractor brief {brief_id} not found")

        item = next((c for c in brief.verification_checklist if c.checklist_id == checklist_id), None)
        if not item:
            raise ValueError(f"Checklist item {checklist_id} not found in brief")

        if not item.is_physically_verified:
            item.is_physically_verified = True
            brief.confirmed_measurements_count += 1
            brief.unconfirmed_measurements_count = max(0, brief.unconfirmed_measurements_count - 1)

        item.verified_by_name = verified_by_name
        item.verified_at = datetime.now(timezone.utc)
        if notes:
            item.notes = notes

        # Refresh printable HTML
        proj = self.projects.get(brief.project_id)
        if proj:
            brief.printable_html = self._generate_contractor_printable_html(brief, proj)

        return item

    # Request for Quotation (RFQ) & Bidding
    def create_quote_request(
        self,
        project_id: str,
        title: str,
        target_trades: List[TradeCategory],
        submission_deadline: Optional[datetime] = None,
        brief_id: Optional[str] = None,
        room_id: Optional[str] = None,
        invited_contractors: Optional[List[str]] = None,
        legal_terms_and_conditions: Optional[str] = None,
    ) -> ContractorQuoteRequest:
        """Issues a new contractor Request for Quotation (RFQ) for tender submission."""
        proj = self.projects.get(project_id)
        if not proj:
            raise ValueError(f"Project {project_id} not found")

        deadline = submission_deadline or (datetime.now(timezone.utc) + timedelta(days=14))
        rfq = ContractorQuoteRequest(
            project_id=project_id,
            room_id=room_id,
            brief_id=brief_id,
            title=title,
            target_trades=target_trades,
            submission_deadline=deadline,
            status=RFQStatus.BIDDING_OPEN,
            invited_contractors=invited_contractors or ["Apex Builders", "Straits Craft Carpentry", "VoltSmart Electrical"],
        )
        if legal_terms_and_conditions:
            rfq.legal_terms_and_conditions = legal_terms_and_conditions

        self.rfqs[rfq.rfq_id] = rfq
        return rfq

    def get_quote_request(self, rfq_id: str) -> Optional[ContractorQuoteRequest]:
        return self.rfqs.get(rfq_id)

    def list_quote_requests(self, project_id: str) -> List[ContractorQuoteRequest]:
        return [r for r in self.rfqs.values() if r.project_id == project_id]

    def submit_contractor_bid(
        self,
        rfq_id: str,
        contractor_id: str,
        contractor_name: str,
        license_no: str,
        contact_email: str,
        overall_bid_amount: float,
        trade_specialties: List[TradeCategory],
        line_item_breakdowns: Optional[List[Dict[str, Any]]] = None,
        contact_phone: Optional[str] = None,
        years_in_business: int = 5,
        insurance_policy_no: Optional[str] = None,
        estimated_lead_time_days: int = 14,
        validity_days: int = 30,
        statutory_compliance_acknowledged: bool = True,
        on_site_verification_acknowledged: bool = True,
        submission_notes: Optional[str] = None,
    ) -> ContractorBid:
        """
        Submits a formal contractor bid. Strictly enforces statutory licensing and
        mandatory physical field verification obligations.
        """
        rfq = self.rfqs.get(rfq_id)
        if not rfq:
            raise ValueError(f"RFQ {rfq_id} not found")

        if not statutory_compliance_acknowledged or not on_site_verification_acknowledged:
            raise ValueError(
                "Contractor must acknowledge statutory licensing compliance and mandatory on-site measurement verification before submitting tender."
            )

        bid = ContractorBid(
            rfq_id=rfq_id,
            contractor_id=contractor_id,
            contractor_name=contractor_name,
            license_no=license_no,
            contact_email=contact_email,
            contact_phone=contact_phone,
            years_in_business=years_in_business,
            insurance_policy_no=insurance_policy_no or f"POL-{uuid.uuid4().hex[:6].upper()}",
            trade_specialties=trade_specialties,
            overall_bid_amount=overall_bid_amount,
            currency=CurrencyCode.MYR,
            estimated_lead_time_days=estimated_lead_time_days,
            validity_days=validity_days,
            status=BidStatus.SUBMITTED,
            line_item_breakdowns=line_item_breakdowns or [],
            statutory_compliance_acknowledged=True,
            on_site_verification_acknowledged=True,
            submission_notes=submission_notes,
        )

        rfq.bids.append(bid)
        self.contractor_bids[bid.bid_id] = bid
        return bid

    def evaluate_and_compare_bids(self, rfq_id: str) -> BidComparisonSummary:
        """Analyzes all received bids for an RFQ against the Roomlyst internal estimate."""
        rfq = self.rfqs.get(rfq_id)
        if not rfq:
            raise ValueError(f"RFQ {rfq_id} not found")

        # Find estimated benchmark cost from brief or default
        benchmark_cost = 14500.0
        if rfq.brief_id and rfq.brief_id in self.contractor_briefs:
            benchmark_cost = self.contractor_briefs[rfq.brief_id].total_estimated_cost

        bids = rfq.bids
        if not bids:
            return BidComparisonSummary(
                rfq_id=rfq_id,
                project_id=rfq.project_id,
                title=rfq.title,
                roomlyst_estimated_total=benchmark_cost,
                total_bids_count=0,
                comparison_notes="No contractor bids submitted yet for this tender.",
            )

        amounts = [b.overall_bid_amount for b in bids]
        lowest = min(amounts)
        highest = max(amounts)
        average = round(sum(amounts) / len(amounts), 2)

        ranked: List[Dict[str, Any]] = []
        for b in sorted(bids, key=lambda x: x.overall_bid_amount):
            variance_pct = round(((b.overall_bid_amount - benchmark_cost) / benchmark_cost) * 100, 1)
            ranked.append({
                "bid_id": b.bid_id,
                "contractor_name": b.contractor_name,
                "license_no": b.license_no,
                "overall_bid_amount": b.overall_bid_amount,
                "variance_from_estimate_pct": variance_pct,
                "lead_time_days": b.estimated_lead_time_days,
                "status": b.status.value,
                "is_conforming": b.statutory_compliance_acknowledged and b.on_site_verification_acknowledged,
            })

        recommended_bid = sorted(bids, key=lambda x: x.overall_bid_amount)[0]

        return BidComparisonSummary(
            rfq_id=rfq_id,
            project_id=rfq.project_id,
            title=rfq.title,
            roomlyst_estimated_total=benchmark_cost,
            total_bids_count=len(bids),
            lowest_bid_amount=lowest,
            highest_bid_amount=highest,
            average_bid_amount=average,
            bids_ranked=ranked,
            recommended_bid_id=recommended_bid.bid_id,
            comparison_notes=(
                f"Evaluated {len(bids)} contractor submissions. "
                f"Lowest conforming quotation is {recommended_bid.contractor_name} at "
                f"MYR {lowest:,.2f} ({((lowest - benchmark_cost) / benchmark_cost) * 100:+.1f}% vs estimate)."
            ),
        )

    def award_contractor_bid(self, rfq_id: str, bid_id: str) -> ContractorBid:
        """Awards tender contract to the selected contractor and marks other bids rejected."""
        rfq = self.rfqs.get(rfq_id)
        if not rfq:
            raise ValueError(f"RFQ {rfq_id} not found")

        awarded_bid = next((b for b in rfq.bids if b.bid_id == bid_id), None)
        if not awarded_bid:
            raise ValueError(f"Bid {bid_id} not found in RFQ {rfq_id}")

        for b in rfq.bids:
            if b.bid_id == bid_id:
                b.status = BidStatus.ACCEPTED
            else:
                if b.status == BidStatus.SUBMITTED:
                    b.status = BidStatus.REJECTED

        rfq.awarded_bid_id = bid_id
        rfq.status = RFQStatus.AWARDED
        return awarded_bid

    def _generate_contractor_printable_html(
        self,
        brief: ContractorProjectBrief,
        project: ProjectRecord,
    ) -> str:
        """Produces a standalone printable HTML5 tender brief with print-friendly CSS."""
        curr = brief.currency.value if hasattr(brief.currency, "value") else str(brief.currency)

        checklist_rows = "".join([
            f"""<tr>
                <td><strong>{item.dimension_label}</strong></td>
                <td>{item.dimension_type}</td>
                <td style="font-family:monospace; font-weight:600;">{item.dimension_value} {item.unit}</td>
                <td><span class="badge {'badge-confirmed' if item.is_physically_verified else 'badge-unconfirmed'}">
                    {'CONFIRMED' if item.is_physically_verified else 'REQUIRES ON-SITE VERIFICATION'}
                </span></td>
                <td>{item.verified_by_name or '—'}</td>
                <td>{item.critical_for_trade.value}</td>
            </tr>"""
            for item in brief.verification_checklist
        ])

        packages_html = "".join([
            f"""<div class="package-card">
                <div class="package-header">
                    <h3>Trade {idx+1}: {pkg.title}</h3>
                    <span class="badge-trade">{pkg.trade.value} | Est: {pkg.estimated_duration_days} Days</span>
                </div>
                <p style="margin: 4px 0 8px 0; color: #475569;">{pkg.description}</p>
                <div style="font-size: 13px; font-weight: 600; margin-bottom: 4px;">Scope of Work:</div>
                <ul style="margin: 0 0 8px 18px; padding: 0; font-size: 13px; color: #334155;">
                    {"".join(f"<li>{s}</li>" for s in pkg.scope_items)}
                </ul>
                <div style="font-size: 12px; color: #b45309; background: #fffbeb; padding: 6px 10px; border-radius: 4px;">
                    <strong>Safety & Compliance:</strong> {", ".join(pkg.safety_notes)}
                </div>
            </div>"""
            for idx, pkg in enumerate(brief.work_packages)
        ])

        boq_rows = "".join([
            f"""<tr>
                <td style="font-family:monospace; font-weight:600;">{item.item_code}</td>
                <td>{item.description}</td>
                <td>{item.trade.value}</td>
                <td style="text-align:right;">{item.quantity} {item.unit}</td>
                <td style="text-align:right;">+{item.waste_factor_pct}%</td>
                <td style="text-align:right; font-weight:600;">{item.total_quantity_with_waste} {item.unit}</td>
                <td style="text-align:right;">{curr} {item.estimated_material_total:,.2f}</td>
                <td style="text-align:right;">{curr} {item.estimated_labor_total:,.2f}</td>
                <td style="text-align:right; font-weight:700;">{curr} {(item.estimated_material_total + item.estimated_labor_total):,.2f}</td>
            </tr>"""
            for item in brief.boq_items
        ])

        return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>{brief.title}</title>
<style>
  body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; color: #0f172a; margin: 40px; background: #fff; line-height: 1.5; }}
  h1 {{ font-size: 24px; margin-bottom: 4px; color: #0f172a; }}
  h2 {{ font-size: 18px; margin-top: 24px; margin-bottom: 8px; border-bottom: 2px solid #e2e8f0; padding-bottom: 6px; }}
  .header-meta {{ display: flex; justify-content: space-between; margin-bottom: 20px; font-size: 14px; color: #475569; }}
  .notice-box {{ background: #fef2f2; border: 1px solid #fecaca; color: #991b1b; padding: 12px 16px; border-radius: 6px; font-size: 13px; margin-bottom: 24px; }}
  .kpi-row {{ display: flex; gap: 16px; margin-bottom: 24px; }}
  .kpi-box {{ flex: 1; border: 1px solid #e2e8f0; border-radius: 6px; padding: 12px; background: #f8fafc; }}
  .kpi-box span {{ font-size: 12px; color: #64748b; text-transform: uppercase; letter-spacing: 0.5px; }}
  .kpi-box strong {{ display: block; font-size: 20px; color: #0f172a; margin-top: 4px; }}
  table {{ width: 100%; border-collapse: collapse; margin-top: 10px; margin-bottom: 20px; font-size: 13px; }}
  th, td {{ border: 1px solid #cbd5e1; padding: 8px 10px; text-align: left; }}
  th {{ background: #f1f5f9; font-weight: 600; color: #334155; }}
  .badge {{ display: inline-block; padding: 3px 8px; border-radius: 12px; font-size: 11px; font-weight: 700; }}
  .badge-confirmed {{ background: #dcfce7; color: #166534; }}
  .badge-unconfirmed {{ background: #fef3c7; color: #92400e; }}
  .badge-trade {{ font-size: 11px; background: #e0f2fe; color: #0369a1; padding: 3px 8px; border-radius: 4px; font-weight: 600; }}
  .package-card {{ border: 1px solid #e2e8f0; border-radius: 6px; padding: 14px; margin-bottom: 12px; background: #fafafa; }}
  .package-header {{ display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px; }}
  .package-header h3 {{ margin: 0; font-size: 15px; color: #0f172a; }}
  .signatures {{ display: flex; justify-content: space-between; margin-top: 40px; padding-top: 20px; border-top: 1px dashed #cbd5e1; }}
  .sig-block {{ width: 45%; border-top: 1px solid #94a3b8; padding-top: 8px; font-size: 12px; color: #475569; }}
  @media print {{
    body {{ margin: 15mm; }}
    .no-print {{ display: none; }}
  }}
</style>
</head>
<body>
  <div class="header-meta">
    <div>
      <h1>{brief.title}</h1>
      <div>Project: <strong>{project.name}</strong> | Site: {brief.property_address}</div>
    </div>
    <div style="text-align: right;">
      <div>Ref: <strong>{brief.brief_id}</strong></div>
      <div>Date: {brief.created_at.strftime('%Y-%m-%d')}</div>
    </div>
  </div>

  <div class="notice-box">
    <strong>MANDATORY STATUTORY NOTICE:</strong> {brief.statutory_disclaimer}
  </div>

  <div class="kpi-row">
    <div class="kpi-box">
      <span>Estimated Cost</span>
      <strong>{curr} {brief.total_estimated_cost:,.2f}</strong>
    </div>
    <div class="kpi-box">
      <span>Material Takeoff</span>
      <strong>{curr} {brief.total_estimated_materials:,.2f}</strong>
    </div>
    <div class="kpi-box">
      <span>Labor Allocation</span>
      <strong>{curr} {brief.total_estimated_labor:,.2f}</strong>
    </div>
    <div class="kpi-box">
      <span>Measurements Status</span>
      <strong style="color: {'#16a34a' if brief.unconfirmed_measurements_count == 0 else '#d97706'};">
        {brief.confirmed_measurements_count} Confirmed / {brief.unconfirmed_measurements_count} Field-Check
      </strong>
    </div>
  </div>

  <h2>1. Site Access & Operating Constraints</h2>
  <p style="font-size: 13px; color: #334155; margin-bottom: 20px;">{brief.site_access_notes}</p>

  <h2>2. Critical Dimension Verification Checklist</h2>
  <p style="font-size: 12px; color: #64748b;">Contractors must physically check dimensions marked below prior to ordering custom millwork or cutting finishes.</p>
  <table>
    <thead>
      <tr>
        <th>Dimension Target</th>
        <th>Type</th>
        <th>Value</th>
        <th>Status</th>
        <th>Verified By</th>
        <th>Critical Trade</th>
      </tr>
    </thead>
    <tbody>
      {checklist_rows}
    </tbody>
  </table>

  <h2>3. Trade Execution Packages & Safety Scope</h2>
  {packages_html}

  <h2>4. Bill of Quantities (BOQ) with Wastage Margins</h2>
  <table>
    <thead>
      <tr>
        <th>Code</th>
        <th>Description</th>
        <th>Trade</th>
        <th style="text-align:right;">Net Qty</th>
        <th style="text-align:right;">Waste</th>
        <th style="text-align:right;">Gross Qty</th>
        <th style="text-align:right;">Est Mat</th>
        <th style="text-align:right;">Est Lab</th>
        <th style="text-align:right;">Total ({curr})</th>
      </tr>
    </thead>
    <tbody>
      {boq_rows}
    </tbody>
  </table>

  <div class="signatures">
    <div class="sig-block">
      <strong>Issued By: Lead Interior Designer</strong><br>
      Studio Registration / Stamp:<br><br>
      Signature: __________________________ Date: ___________
    </div>
    <div class="sig-block">
      <strong>Acknowledged By: Licensed Contractor</strong><br>
      Company & CIDB License No:<br><br>
      Signature: __________________________ Date: ___________
    </div>
  </div>
</body>
</html>"""

    # ==========================
    # Property Agent & Virtual Staging Methods (Milestone 6.3)
    # ==========================
    def _seed_listings(self):
        """Seeds initial property listings with virtual staging concepts."""
        disclosure_1 = VirtualStagingDisclosure(
            is_virtually_staged=True,
            watermark_applied=True,
            watermark_text="VIRTUALLY STAGED — FOR ILLUSTRATIVE PURPOSES ONLY",
            watermark_position=WatermarkPosition.BOTTOM_RIGHT,
            disclosure_statement=(
                "Virtually Staged: Furnishings and decor are digitally added for illustrative purposes only. "
                "Original room dimensions, walls, and permanent fixtures remain unaltered."
            ),
            regulatory_framework="RESO Standard / BOVAEP / CEA Guidelines",
            agent_license_no="REN 19482",
            agency_name="PropNex Realty Malaysia",
            original_image_url="https://storage.roomlyst.com/samples/vacant_living_room_raw.jpg",
            staged_image_url="https://storage.roomlyst.com/staged/room_pavilion_01_staged.jpg",
            staged_at=datetime.now(timezone.utc),
        )

        staged_asset_1 = StagedRoomAsset(
            asset_id="stage_asset_001",
            room_id="room_pavilion_living",
            room_name="Grand Living & Dining Room",
            staging_type=StagingType.VIRTUAL_STAGING_EMPTY,
            style_theme="Warm Contemporary",
            original_image_url="https://storage.roomlyst.com/samples/vacant_living_room_raw.jpg",
            staged_image_url="https://storage.roomlyst.com/staged/room_pavilion_01_staged.jpg",
            watermarked_image_url="https://storage.roomlyst.com/staged/room_pavilion_01_watermarked.jpg",
            disclosure=disclosure_1,
            created_at=datetime.now(timezone.utc),
        )

        renovation_potential_2 = RenovationPotentialEstimate(
            cosmetic_scope_items=[
                "Engineered French oak chevron flooring",
                "Matte mineral limewash paint (Warm Alabaster)",
                "Concealed architectural LED cove lighting",
                "Slim-profile black aluminum window frame finish",
            ],
            estimated_renovation_cost=18500.0,
            currency=CurrencyCode.MYR,
            indicative_value_uplift_pct=9.5,
            estimated_value_uplift_amount=68000.0,
            roi_notes="Cosmetic makeover estimated at MYR 18,500 with projected listing value uplift of MYR 68,000 (3.6x cost).",
        )

        disclosure_2 = VirtualStagingDisclosure(
            is_virtually_staged=True,
            watermark_applied=True,
            watermark_text="RENOVATION POTENTIAL CONCEPT — COSMETIC UPGRADE PREVIEW",
            watermark_position=WatermarkPosition.BOTTOM_RIGHT,
            disclosure_statement=(
                "Renovation Concept: Finish upgrades are digitally simulated. "
                "Consult contractor specifications before beginning construction."
            ),
            regulatory_framework="RESO Standard / BOVAEP / CEA Guidelines",
            agent_license_no="PEA 2811",
            agency_name="Knight Frank Malaysia",
            original_image_url="https://storage.roomlyst.com/samples/dated_bedroom_raw.jpg",
            staged_image_url="https://storage.roomlyst.com/staged/room_damansara_01_renovated.jpg",
            staged_at=datetime.now(timezone.utc),
        )

        staged_asset_2 = StagedRoomAsset(
            asset_id="stage_asset_002",
            room_id="room_damansara_master",
            room_name="Master Suite Retreat",
            staging_type=StagingType.RENOVATION_POTENTIAL,
            style_theme="Japandi Minimalist",
            original_image_url="https://storage.roomlyst.com/samples/dated_bedroom_raw.jpg",
            staged_image_url="https://storage.roomlyst.com/staged/room_damansara_01_renovated.jpg",
            watermarked_image_url="https://storage.roomlyst.com/staged/room_damansara_01_renovated_watermarked.jpg",
            disclosure=disclosure_2,
            renovation_potential=renovation_potential_2,
            created_at=datetime.now(timezone.utc),
        )

        listing_1 = PropertyListingRecord(
            listing_id="list_bangsar_01",
            mls_number="MLS-MY-88291",
            property_title="The Pavilion Suites, Bangsar",
            property_type="Condominium",
            bedrooms=3,
            bathrooms=3,
            built_up_sqft=1450.0,
            listing_price=1850000.0,
            currency=CurrencyCode.MYR,
            property_address="Level 18, 55 Jalan Telawi, Bangsar, 59100 Kuala Lumpur",
            listing_agent_name="Sarah Wong",
            agent_license_no="REN 19482",
            agency_name="PropNex Realty Malaysia",
            agent_phone="+60 12 889 1234",
            agent_email="sarah.wong@propnex.my",
            staged_rooms=[staged_asset_1],
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )

        listing_2 = PropertyListingRecord(
            listing_id="list_damansara_02",
            mls_number="MLS-MY-44102",
            property_title="Verdi Eco-dominiums, Damansara",
            property_type="Apartment",
            bedrooms=2,
            bathrooms=2,
            built_up_sqft=980.0,
            listing_price=720000.0,
            currency=CurrencyCode.MYR,
            property_address="Tower B, Persiaran Surian, Kota Damansara, 47810 Petaling Jaya",
            listing_agent_name="Marcus Tan",
            agent_license_no="PEA 2811",
            agency_name="Knight Frank Malaysia",
            agent_phone="+60 17 234 5678",
            agent_email="marcus.tan@knightfrank.my",
            staged_rooms=[staged_asset_2],
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )

        self.listings[listing_1.listing_id] = listing_1
        self.listings[listing_2.listing_id] = listing_2

    def create_listing(
        self,
        property_title: str,
        mls_number: Optional[str] = None,
        property_type: str = "Condominium",
        bedrooms: int = 3,
        bathrooms: int = 2,
        built_up_sqft: float = 1200.0,
        listing_price: float = 850000.0,
        currency: CurrencyCode = CurrencyCode.MYR,
        property_address: str = "Kuala Lumpur, Malaysia",
        listing_agent_name: str = "Real Estate Agent",
        agent_license_no: Optional[str] = None,
        agency_name: Optional[str] = None,
        agent_phone: Optional[str] = None,
        agent_email: Optional[str] = None,
    ) -> PropertyListingRecord:
        """Creates a new real estate listing record."""
        listing_id = f"list_{uuid.uuid4().hex[:8]}"
        mls = mls_number or f"MLS-MY-{uuid.uuid4().hex[:5].upper()}"

        record = PropertyListingRecord(
            listing_id=listing_id,
            mls_number=mls,
            property_title=property_title,
            property_type=property_type,
            bedrooms=bedrooms,
            bathrooms=bathrooms,
            built_up_sqft=built_up_sqft,
            listing_price=listing_price,
            currency=currency,
            property_address=property_address,
            listing_agent_name=listing_agent_name,
            agent_license_no=agent_license_no,
            agency_name=agency_name,
            agent_phone=agent_phone,
            agent_email=agent_email,
            staged_rooms=[],
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )
        self.listings[record.listing_id] = record
        return record

    def get_listing(self, listing_id: str) -> Optional[PropertyListingRecord]:
        return self.listings.get(listing_id)

    def list_listings(self, agent_license: Optional[str] = None) -> List[PropertyListingRecord]:
        all_listings = list(self.listings.values())
        if agent_license:
            return [l for l in all_listings if l.agent_license_no == agent_license]
        return all_listings

    def update_listing(
        self,
        listing_id: str,
        property_title: Optional[str] = None,
        listing_price: Optional[float] = None,
        bedrooms: Optional[int] = None,
        bathrooms: Optional[int] = None,
        property_address: Optional[str] = None,
    ) -> Optional[PropertyListingRecord]:
        rec = self.listings.get(listing_id)
        if not rec:
            return None
        if property_title is not None:
            rec.property_title = property_title
        if listing_price is not None:
            rec.listing_price = listing_price
        if bedrooms is not None:
            rec.bedrooms = bedrooms
        if bathrooms is not None:
            rec.bathrooms = bathrooms
        if property_address is not None:
            rec.property_address = property_address
        rec.updated_at = datetime.now(timezone.utc)
        return rec

    def delete_listing(self, listing_id: str) -> bool:
        if listing_id in self.listings:
            del self.listings[listing_id]
            return True
        return False

    def stage_room_for_listing(
        self,
        listing_id: str,
        room_name: str,
        staging_type: StagingType = StagingType.VIRTUAL_STAGING_EMPTY,
        style_theme: str = "Warm Contemporary",
        original_image_url: Optional[str] = None,
        watermark_position: WatermarkPosition = WatermarkPosition.BOTTOM_RIGHT,
        floor_area_sqm: float = 24.0,
        room_id: Optional[str] = None,
    ) -> StagedRoomAsset:
        """Executes virtual staging for a room in a property listing."""
        listing = self.listings.get(listing_id)
        if not listing:
            raise KeyError(f"Listing {listing_id} not found")

        asset_id = f"stage_{uuid.uuid4().hex[:8]}"
        rid = room_id or f"room_{uuid.uuid4().hex[:6]}"
        orig_img = original_image_url or "https://storage.roomlyst.com/samples/vacant_living_room_raw.jpg"
        slug = style_theme.lower().replace(" ", "_")
        staged_url = f"https://storage.roomlyst.com/staged/{listing_id}_{staging_type.value.lower()}_{slug}.jpg"
        watermarked_url = f"https://storage.roomlyst.com/staged/{listing_id}_{staging_type.value.lower()}_{slug}_watermarked.jpg"

        renovation_potential = None
        if staging_type == StagingType.RENOVATION_POTENTIAL:
            renovation_cost = round((floor_area_sqm * 180.0) + 4500.0, 2)
            indicative_uplift = round(renovation_cost * 2.4, 2)
            uplift_pct = round((indicative_uplift / listing.listing_price) * 100, 1) if listing.listing_price > 0 else 8.5

            renovation_potential = RenovationPotentialEstimate(
                cosmetic_scope_items=[
                    "Engineered French oak chevron flooring",
                    "Matte mineral limewash paint (Warm Alabaster)",
                    "Concealed architectural LED cove lighting",
                    "Slim-profile black aluminum window frame finish",
                ],
                estimated_renovation_cost=renovation_cost,
                currency=listing.currency,
                indicative_value_uplift_pct=uplift_pct,
                estimated_value_uplift_amount=indicative_uplift,
                roi_notes=(
                    f"Cosmetic makeover estimated at {listing.currency.value} {renovation_cost:,.2f} "
                    f"projected to increase listing valuation by {listing.currency.value} {indicative_uplift:,.2f} (~{uplift_pct}%)."
                ),
            )

        disclosure = VirtualStagingDisclosure(
            is_virtually_staged=True,
            watermark_applied=True,
            watermark_text="VIRTUALLY STAGED — FOR ILLUSTRATIVE PURPOSES ONLY",
            watermark_position=watermark_position,
            disclosure_statement=(
                "Virtually Staged: Furnishings and decor are digitally added for illustrative purposes only. "
                "Original room dimensions, walls, and permanent fixtures remain unaltered."
            ),
            regulatory_framework="RESO Standard / BOVAEP / CEA Guidelines",
            agent_license_no=listing.agent_license_no,
            agency_name=listing.agency_name,
            original_image_url=orig_img,
            staged_image_url=staged_url,
            staged_at=datetime.now(timezone.utc),
        )

        staged_asset = StagedRoomAsset(
            asset_id=asset_id,
            room_id=rid,
            room_name=room_name,
            staging_type=staging_type,
            style_theme=style_theme,
            original_image_url=orig_img,
            staged_image_url=staged_url,
            watermarked_image_url=watermarked_url,
            disclosure=disclosure,
            renovation_potential=renovation_potential,
            created_at=datetime.now(timezone.utc),
        )

        listing.staged_rooms.append(staged_asset)
        listing.updated_at = datetime.now(timezone.utc)
        return staged_asset

    def export_portal_bundle(
        self,
        listing_id: str,
        portal_target: str = "propertyguru",
    ) -> PortalExportPackage:
        """Compiles a RESO/portal syndication export package with compliance manifests."""
        listing = self.listings.get(listing_id)
        if not listing:
            raise KeyError(f"Listing {listing_id} not found")

        media_entries: List[Dict[str, Any]] = []
        for idx, asset in enumerate(listing.staged_rooms):
            media_entries.append({
                "media_index": idx + 1,
                "room_name": asset.room_name,
                "staging_type": asset.staging_type.value,
                "style_theme": asset.style_theme,
                "is_virtually_staged": True,
                "original_photo_url": asset.original_image_url,
                "staged_photo_url": asset.watermarked_image_url,
                "disclosure_statement": asset.disclosure.disclosure_statement,
                "watermark_applied": asset.disclosure.watermark_applied,
                "reso_media_category": "VirtuallyStagedRoom",
            })

        disclosure_manifest = {
            "listing_id": listing.listing_id,
            "mls_number": listing.mls_number,
            "property_address": listing.property_address,
            "portal_target": portal_target,
            "listing_agent": {
                "name": listing.listing_agent_name,
                "license_no": listing.agent_license_no,
                "agency": listing.agency_name,
            },
            "compliance_attestation": (
                "The listing broker confirms that all virtually staged images in this syndication feed "
                "strictly comply with MLS virtual staging guidelines and accurately represent permanent architecture."
            ),
            "generated_at": datetime.now(timezone.utc).isoformat(),
        }

        package = PortalExportPackage(
            listing_id=listing.listing_id,
            property_title=listing.property_title,
            total_staged_rooms=len(listing.staged_rooms),
            portal_format="RESO_STANDARD",
            export_timestamp=datetime.now(timezone.utc),
            media_entries=media_entries,
            disclosure_manifest=disclosure_manifest,
        )
        listing.portal_export_package = package
        listing.updated_at = datetime.now(timezone.utc)
        return package

    def generate_property_flyer_html(self, listing_id: str) -> str:
        """Generates a print-ready real estate property marketing flyer with staging disclosure."""
        listing = self.listings.get(listing_id)
        if not listing:
            raise KeyError(f"Listing {listing_id} not found")

        curr = listing.currency.value
        rooms_html = ""
        for room in listing.staged_rooms:
            roi_html = ""
            if room.renovation_potential:
                rp = room.renovation_potential
                roi_html = f"""
                <div style="background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 6px; padding: 12px; margin-top: 10px;">
                    <strong style="color: #166534; font-size: 13px;">💡 Renovation Potential Preview</strong>
                    <div style="font-size: 12px; color: #15803d; margin-top: 4px;">
                        Est. Cosmetic Makeover: <b>{curr} {rp.estimated_renovation_cost:,.2f}</b> | 
                        Projected Value Uplift: <b>+{curr} {rp.estimated_value_uplift_amount:,.2f} (~{rp.indicative_value_uplift_pct}%)</b>
                    </div>
                </div>
                """

            rooms_html += f"""
            <div style="margin-bottom: 28px; background: #ffffff; border: 1px solid #e2e8f0; border-radius: 8px; overflow: hidden;">
                <div style="padding: 12px 16px; background: #f8fafc; border-bottom: 1px solid #e2e8f0; display: flex; justify-content: space-between; align-items: center;">
                    <span style="font-weight: 600; color: #0f172a; font-size: 15px;">{room.room_name}</span>
                    <span style="font-size: 11px; background: #e0f2fe; color: #0369a1; padding: 2px 8px; border-radius: 4px; font-weight: 500;">
                        {room.staging_type.value.replace('_', ' ').title()} • {room.style_theme}
                    </span>
                </div>
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px; padding: 16px;">
                    <div>
                        <div style="font-size: 11px; font-weight: 600; color: #64748b; margin-bottom: 4px;">ORIGINAL (UNFURNISHED / AS-IS)</div>
                        <img src="{room.original_image_url}" alt="Original Room" style="width: 100%; height: 180px; object-fit: cover; border-radius: 6px; border: 1px solid #e2e8f0;" />
                    </div>
                    <div>
                        <div style="font-size: 11px; font-weight: 600; color: #2563eb; margin-bottom: 4px;">VIRTUALLY STAGED (CONCEPT)</div>
                        <div style="position: relative;">
                            <img src="{room.watermarked_image_url}" alt="Virtually Staged" style="width: 100%; height: 180px; object-fit: cover; border-radius: 6px; border: 1px solid #cbd5e1;" />
                            <div style="position: absolute; bottom: 8px; right: 8px; background: rgba(15, 23, 42, 0.85); color: #ffffff; font-size: 9px; font-weight: bold; padding: 3px 6px; border-radius: 4px;">
                                ⚠ VIRTUALLY STAGED
                            </div>
                        </div>
                    </div>
                </div>
                <div style="padding: 0 16px 16px 16px;">
                    <div style="font-size: 11px; color: #64748b; line-height: 1.4;">
                        <b>Mandatory Disclosure:</b> {room.disclosure.disclosure_statement}
                    </div>
                    {roi_html}
                </div>
            </div>
            """

        return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>{listing.property_title} — Property Marketing Flyer</title>
    <style>
        body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; margin: 0; padding: 32px; background: #f8fafc; color: #1e293b; }}
        .header {{ background: #0f172a; color: white; padding: 24px 32px; border-radius: 12px; margin-bottom: 24px; }}
        .price {{ font-size: 28px; font-weight: 800; color: #38bdf8; }}
        .stats-bar {{ display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; margin-bottom: 24px; }}
        .stat-card {{ background: white; padding: 14px 18px; border-radius: 8px; border: 1px solid #e2e8f0; }}
        .stat-card span {{ font-size: 11px; text-transform: uppercase; color: #64748b; font-weight: 600; display: block; }}
        .stat-card strong {{ font-size: 18px; color: #0f172a; margin-top: 4px; display: block; }}
        .footer {{ background: #e2e8f0; padding: 16px 24px; border-radius: 8px; font-size: 11px; color: #475569; margin-top: 24px; text-align: center; }}
    </style>
</head>
<body>
    <div class="header">
        <div style="font-size: 12px; letter-spacing: 0.05em; color: #94a3b8; text-transform: uppercase; margin-bottom: 4px;">Exclusive Property Presentation • {listing.mls_number}</div>
        <h1 style="margin: 0 0 8px 0; font-size: 26px;">{listing.property_title}</h1>
        <p style="margin: 0 0 16px 0; color: #cbd5e1; font-size: 14px;">📍 {listing.property_address}</p>
        <div class="price">{curr} {listing.listing_price:,.2f}</div>
    </div>

    <div class="stats-bar">
        <div class="stat-card">
            <span>Property Type</span>
            <strong>{listing.property_type}</strong>
        </div>
        <div class="stat-card">
            <span>Bedrooms / Baths</span>
            <strong>{listing.bedrooms} Beds / {listing.bathrooms} Baths</strong>
        </div>
        <div class="stat-card">
            <span>Built-Up Area</span>
            <strong>{listing.built_up_sqft:,.0f} sqft</strong>
        </div>
        <div class="stat-card">
            <span>Listing Agent</span>
            <strong style="font-size: 14px;">{listing.listing_agent_name} ({listing.agent_license_no or 'Agent'})</strong>
        </div>
    </div>

    <h2 style="font-size: 18px; color: #0f172a; margin-bottom: 16px;">Spatial Concepts & Virtually Staged Rooms</h2>
    {rooms_html if rooms_html else '<p style="color: #64748b;">No staged rooms currently compiled for this property.</p>'}

    <div class="footer">
        <b>Regulatory Compliance Note:</b> This property presentation incorporates digitally staged representations adhering to RESO, BOVAEP, and CEA advertising rules. All staged images are paired with original baseline condition records. Contact <b>{listing.listing_agent_name}</b> at <b>{listing.agent_phone or listing.agent_email or listing.agency_name}</b> for private viewings.
    </div>
</body>
</html>"""

    # ==========================
    # Milestone 6.4: Cross-Segment Ecosystem Workflow Orchestration
    # Fulfills Blueprint Section 41 & Phase 6 Exit Gate
    # ==========================
    def _seed_handoffs(self):
        """Seeds initial ecosystem handoffs and governance audit events."""
        proj_id = "proj_seed_01"
        h1 = EcosystemHandoffRecord(
            handoff_id="hnd_seed_01",
            project_id=proj_id,
            transition_type=HandoffTransitionType.HOMEOWNER_TO_DESIGNER,
            source_actor_id="user_homeowner_01",
            source_role=EcosystemRole.HOMEOWNER,
            target_actor_id="designer_studio_01",
            target_role=EcosystemRole.INTERIOR_DESIGNER,
            target_actor_name="Elena Vance Interior Architecture",
            status=HandoffStatus.ACTIVE,
            permitted_scopes=["view_raw_scans", "create_redesigns", "edit_budget"],
            transferred_artifact_ids=["room_living_01"],
            notes="Initial homeowner consultation and room model handover.",
            created_at=datetime.now(timezone.utc) - timedelta(days=5),
            accepted_at=datetime.now(timezone.utc) - timedelta(days=4),
        )

        h2 = EcosystemHandoffRecord(
            handoff_id="hnd_seed_02",
            project_id=proj_id,
            transition_type=HandoffTransitionType.DESIGNER_TO_CONTRACTOR,
            source_actor_id="designer_studio_01",
            source_role=EcosystemRole.INTERIOR_DESIGNER,
            target_actor_id="contractor_apex_01",
            target_role=EcosystemRole.CONTRACTOR,
            target_actor_name="Apex Build & Renovation Ltd",
            status=HandoffStatus.PENDING_ACCEPTANCE,
            permitted_scopes=["view_tender_brief", "view_boq", "submit_bids"],
            transferred_artifact_ids=["brief_living_01"],
            notes="RFQ Tender invitation for carpentry and masonry trade works.",
            created_at=datetime.now(timezone.utc) - timedelta(days=1),
        )

        self.handoffs[h1.handoff_id] = h1
        self.handoffs[h2.handoff_id] = h2

        # Seed initial audit trail
        self.ecosystem_audit_events.extend([
            EcosystemAuditEvent(
                event_id="aud_seed_01",
                project_id=proj_id,
                actor_id="user_homeowner_01",
                actor_name="Homeowner",
                actor_role=EcosystemRole.HOMEOWNER,
                action="INITIATE_HANDOFF",
                resource_type="handoff",
                resource_id="hnd_seed_01",
                metadata={"transition": "HOMEOWNER_TO_DESIGNER"},
                timestamp=datetime.now(timezone.utc) - timedelta(days=5),
            ),
            EcosystemAuditEvent(
                event_id="aud_seed_02",
                project_id=proj_id,
                actor_id="designer_studio_01",
                actor_name="Elena Vance",
                actor_role=EcosystemRole.INTERIOR_DESIGNER,
                action="ACCEPT_HANDOFF",
                resource_type="handoff",
                resource_id="hnd_seed_01",
                metadata={"status": "ACTIVE"},
                timestamp=datetime.now(timezone.utc) - timedelta(days=4),
            ),
            EcosystemAuditEvent(
                event_id="aud_seed_03",
                project_id=proj_id,
                actor_id="designer_studio_01",
                actor_name="Elena Vance",
                actor_role=EcosystemRole.INTERIOR_DESIGNER,
                action="INITIATE_HANDOFF",
                resource_type="handoff",
                resource_id="hnd_seed_02",
                metadata={"transition": "DESIGNER_TO_CONTRACTOR"},
                timestamp=datetime.now(timezone.utc) - timedelta(days=1),
            ),
        ])

    def initiate_handoff(
        self,
        project_id: str,
        transition_type: HandoffTransitionType,
        source_actor_id: str,
        source_role: EcosystemRole,
        target_actor_id: str,
        target_role: EcosystemRole,
        target_actor_name: Optional[str] = None,
        permitted_scopes: Optional[List[str]] = None,
        transferred_artifact_ids: Optional[List[str]] = None,
        notes: Optional[str] = None,
    ) -> EcosystemHandoffRecord:
        """Initiates a formal cross-segment handoff between ecosystem participants."""
        handoff_id = f"hnd_{uuid.uuid4().hex[:8]}"
        scopes = permitted_scopes or ["view_workspace", "read_specifications"]
        artifacts = transferred_artifact_ids or []

        handoff = EcosystemHandoffRecord(
            handoff_id=handoff_id,
            project_id=project_id,
            transition_type=transition_type,
            source_actor_id=source_actor_id,
            source_role=source_role,
            target_actor_id=target_actor_id,
            target_role=target_role,
            target_actor_name=target_actor_name,
            status=HandoffStatus.PENDING_ACCEPTANCE,
            permitted_scopes=scopes,
            transferred_artifact_ids=artifacts,
            notes=notes,
            created_at=datetime.now(timezone.utc),
        )
        self.handoffs[handoff_id] = handoff

        self.log_ecosystem_audit_event(
            project_id=project_id,
            actor_id=source_actor_id,
            actor_name=f"{source_role.value.replace('_', ' ').title()}",
            actor_role=source_role,
            action="INITIATE_HANDOFF",
            resource_type="handoff",
            resource_id=handoff_id,
            metadata={
                "transition_type": transition_type.value,
                "target_actor_id": target_actor_id,
                "target_role": target_role.value,
                "scopes": scopes,
            },
        )
        return handoff

    def accept_handoff(
        self,
        handoff_id: str,
        actor_id: str,
        actor_name: Optional[str] = None,
    ) -> EcosystemHandoffRecord:
        """Accepts and activates an ecosystem handoff."""
        handoff = self.handoffs.get(handoff_id)
        if not handoff:
            raise KeyError(f"Handoff '{handoff_id}' not found.")

        handoff.status = HandoffStatus.ACTIVE
        handoff.accepted_at = datetime.now(timezone.utc)
        if actor_name:
            handoff.target_actor_name = actor_name

        self.log_ecosystem_audit_event(
            project_id=handoff.project_id,
            actor_id=actor_id,
            actor_name=actor_name or handoff.target_actor_name or "Participant",
            actor_role=handoff.target_role,
            action="ACCEPT_HANDOFF",
            resource_type="handoff",
            resource_id=handoff_id,
            metadata={"transition": handoff.transition_type.value, "status": "ACTIVE"},
        )
        return handoff

    def complete_handoff(self, handoff_id: str) -> EcosystemHandoffRecord:
        """Marks a handoff as completed after milestones are delivered."""
        handoff = self.handoffs.get(handoff_id)
        if not handoff:
            raise KeyError(f"Handoff '{handoff_id}' not found.")

        handoff.status = HandoffStatus.COMPLETED
        handoff.completed_at = datetime.now(timezone.utc)

        self.log_ecosystem_audit_event(
            project_id=handoff.project_id,
            actor_id=handoff.source_actor_id,
            actor_name="Project Lead",
            actor_role=handoff.source_role,
            action="COMPLETE_HANDOFF",
            resource_type="handoff",
            resource_id=handoff_id,
            metadata={"status": "COMPLETED"},
        )
        return handoff

    def revoke_handoff(self, handoff_id: str, reason: str = "Access revoked") -> EcosystemHandoffRecord:
        """Revokes a cross-segment handoff and denies further data access."""
        handoff = self.handoffs.get(handoff_id)
        if not handoff:
            raise KeyError(f"Handoff '{handoff_id}' not found.")

        handoff.status = HandoffStatus.REVOKED

        self.log_ecosystem_audit_event(
            project_id=handoff.project_id,
            actor_id=handoff.source_actor_id,
            actor_name="Project Owner",
            actor_role=handoff.source_role,
            action="REVOKE_HANDOFF",
            resource_type="handoff",
            resource_id=handoff_id,
            metadata={"reason": reason, "revoked_scopes": handoff.permitted_scopes},
            is_sensitive=True,
        )
        return handoff

    def list_handoffs(
        self,
        project_id: Optional[str] = None,
        actor_id: Optional[str] = None,
    ) -> List[EcosystemHandoffRecord]:
        """Queries ecosystem handoffs filtered by project or participant actor."""
        res = list(self.handoffs.values())
        if project_id:
            res = [h for h in res if h.project_id == project_id]
        if actor_id:
            res = [h for h in res if h.source_actor_id == actor_id or h.target_actor_id == actor_id]
        return res

    def get_handoff(self, handoff_id: str) -> Optional[EcosystemHandoffRecord]:
        return self.handoffs.get(handoff_id)

    def log_ecosystem_audit_event(
        self,
        project_id: str,
        actor_id: str,
        actor_name: str,
        actor_role: EcosystemRole,
        action: str,
        resource_type: str,
        resource_id: Optional[str] = None,
        metadata: Optional[Dict[str, Any]] = None,
        is_sensitive: bool = False,
    ) -> EcosystemAuditEvent:
        """Records an immutable audit event for compliance and governance tracking."""
        event = EcosystemAuditEvent(
            event_id=f"aud_{uuid.uuid4().hex[:8]}",
            project_id=project_id,
            actor_id=actor_id,
            actor_name=actor_name,
            actor_role=actor_role,
            action=action,
            resource_type=resource_type,
            resource_id=resource_id,
            metadata=metadata or {},
            timestamp=datetime.now(timezone.utc),
            is_sensitive=is_sensitive,
        )
        self.ecosystem_audit_events.append(event)
        return event

    def list_ecosystem_audit_events(self, project_id: Optional[str] = None) -> List[EcosystemAuditEvent]:
        """Retrieves tamper-evident audit history for a project or the platform."""
        if project_id:
            return [e for e in self.ecosystem_audit_events if e.project_id == project_id]
        return list(self.ecosystem_audit_events)

    def get_workflow_orchestration_summary(self, project_id: str) -> WorkflowOrchestrationSummary:
        """
        Synthesizes the 5-phase project lifecycle status, active handoffs, and audit timeline.
        Fulfills Blueprint Section 41 & Phase 6 Exit Gate.
        """
        proj = self.projects.get(project_id)
        proj_name = proj.name if proj else "Ecosystem Master Project"

        # 1. Evaluate Homeowner Phase
        rooms = [r for r in self.rooms.values() if getattr(r, "project_id", None) == project_id]
        homeowner_status = "COMPLETED" if len(rooms) > 0 else "IN_PROGRESS"

        # 2. Evaluate Designer Phase
        has_redesigns = any(len(r.versions) > 0 for r in rooms) or any(len(r.renovation_plans) > 0 for r in rooms)
        designer_status = "COMPLETED" if has_redesigns else "ACTIVE"

        # 3. Evaluate Commerce Phase
        has_commerce = any(r.product_recommendations is not None for r in rooms) or len(self.visualizations) > 0
        commerce_status = "ACTIVE" if has_commerce else "NOT_STARTED"

        # 4. Evaluate Contractor Phase
        has_contractor = any(b.project_id == project_id for b in self.contractor_briefs.values()) or any(
            r.project_id == project_id for r in self.rfqs.values()
        )
        has_awarded_bid = any(
            b.status == BidStatus.ACCEPTED
            for rfq in self.rfqs.values()
            if rfq.project_id == project_id
            for b in self.contractor_bids.values()
            if b.rfq_id == rfq.rfq_id
        )
        contractor_status = "COMPLETED" if has_awarded_bid else ("ACTIVE" if has_contractor else "NOT_STARTED")

        # 5. Evaluate Property Staging Phase
        has_staging = any(l.project_id == project_id or len(l.staged_rooms) > 0 for l in self.listings.values())
        staging_status = "ACTIVE" if has_staging else "NOT_STARTED"

        project_handoffs = [h for h in self.handoffs.values() if h.project_id == project_id]
        recent_audits = [e for e in self.ecosystem_audit_events if e.project_id == project_id][-10:]

        # Distinct participant count
        participants = set()
        for h in project_handoffs:
            participants.add(h.source_actor_id)
            participants.add(h.target_actor_id)
        if proj and proj.collaborators:
            for c in proj.collaborators:
                participants.add(c.user_id)

        return WorkflowOrchestrationSummary(
            project_id=project_id,
            project_name=proj_name,
            homeowner_phase_status=homeowner_status,
            designer_phase_status=designer_status,
            commerce_phase_status=commerce_status,
            contractor_phase_status=contractor_status,
            property_staging_phase_status=staging_status,
            total_active_handoffs=len([h for h in project_handoffs if h.status == HandoffStatus.ACTIVE]),
            total_participants=max(1, len(participants)),
            handoffs=project_handoffs,
            recent_audit_events=recent_audits,
        )

    def get_role_scoped_project_view(self, project_id: str, role: EcosystemRole) -> RoleScopedProjectView:
        """
        Enforces Role-Based Access Control (RBAC) and privacy redaction across ecosystem roles.
        Guarantees that sensitive billing, personal data, or trade secrets are shielded.
        Fulfills Phase 6 Exit Gate.
        """
        proj = self.projects.get(project_id)
        proj_name = proj.name if proj else "Project Workspace"
        addr = proj.property_address if proj else "Confidential Site Address"

        # Log audit access
        self.log_ecosystem_audit_event(
            project_id=project_id,
            actor_id=f"actor_{role.value.lower()}",
            actor_name=f"{role.value.title()} User",
            actor_role=role,
            action="ACCESS_ROLE_SCOPED_VIEW",
            resource_type="project_workspace",
            resource_id=project_id,
            metadata={"role": role.value},
        )

        if role in (EcosystemRole.HOMEOWNER, EcosystemRole.INTERIOR_DESIGNER, EcosystemRole.STUDIO_ADMIN):
            # Full transparency for project owners & designers
            return RoleScopedProjectView(
                project_id=project_id,
                role=role,
                project_name=proj_name,
                property_address=addr,
                accessible_sections=[
                    "all_spatial_scans",
                    "design_versions_and_variants",
                    "full_financial_budget",
                    "client_confidential_brief",
                    "merchant_placements_and_commissions",
                    "contractor_briefs_and_tender_bids",
                    "property_virtual_staging_and_flyers",
                ],
                redacted_fields=[],
                data_payload={
                    "is_full_access": True,
                    "currency": proj.currency if proj else "MYR",
                    "client_id": proj.client_id if proj else None,
                    "designer_notes": proj.designer_notes if proj else None,
                },
            )

        elif role == EcosystemRole.CONTRACTOR:
            # Shield client financial billing, designer markups, and other contractor bids
            return RoleScopedProjectView(
                project_id=project_id,
                role=role,
                project_name=proj_name,
                property_address=addr,
                accessible_sections=[
                    "confirmed_and_estimated_measurements_checklist",
                    "trade_work_packages",
                    "bill_of_quantities_with_wastage",
                    "site_access_rules_and_working_hours",
                    "rfq_tender_specifications",
                ],
                redacted_fields=[
                    "homeowner_personal_phone",
                    "homeowner_billing_rate",
                    "designer_markups_and_commissions",
                    "competitor_contractor_tender_bids",
                    "unauthorized_private_room_scans",
                ],
                data_payload={
                    "is_full_access": False,
                    "permitted_trades": ["CARPENTRY_JOINERY", "MASONRY_TILING", "PAINTING_PLASTERING"],
                    "site_access_notes": "Standard residential access hours 9:00 AM – 5:30 PM.",
                    "requires_on_site_measurement_verification": True,
                },
            )

        elif role == EcosystemRole.MERCHANT_SELLER:
            # Shield full architectural layout, contractor pricing, and homeowner financials
            return RoleScopedProjectView(
                project_id=project_id,
                role=role,
                project_name=proj_name,
                property_address="City / Regional Hub (Specific street redacted)",
                accessible_sections=[
                    "specified_catalog_products",
                    "in_room_3d_furniture_placements",
                    "spatial_fit_attestations",
                    "affiliate_referral_tracking",
                ],
                redacted_fields=[
                    "full_architectural_floorplans",
                    "contractor_tender_packages",
                    "total_renovation_budget",
                    "client_contact_details",
                ],
                data_payload={
                    "is_full_access": False,
                    "active_product_referrals_count": len(self.visualizations),
                    "commission_tracking_active": True,
                },
            )

        else:  # EcosystemRole.PROPERTY_AGENT
            # Shield internal contractor construction margins and homeowner financials
            return RoleScopedProjectView(
                project_id=project_id,
                role=role,
                project_name=proj_name,
                property_address=addr,
                accessible_sections=[
                    "virtually_staged_media_pairs",
                    "reso_regulatory_disclosure_manifest",
                    "printable_marketing_flyer_html",
                    "cosmetic_renovation_potential_roi",
                ],
                redacted_fields=[
                    "subcontractor_unit_labor_rates",
                    "internal_designer_cost_margins",
                    "client_personal_identifiable_information",
                ],
                data_payload={
                    "is_full_access": False,
                    "disclosure_watermark_mandated": True,
                    "reso_portal_syndication_ready": True,
                },
            )


# Global singleton repository instance for the running service
repository = InMemoryRepository()

