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


# Global singleton repository instance for the running service
repository = InMemoryRepository()
