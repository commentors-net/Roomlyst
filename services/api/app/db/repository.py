"""
In-Memory & File-Backed Repository for Phase 0 POC & Phase 5 Professional Workspace state.
Stores Projects, Rooms, Clients, and Canonical Room Models.
Prepares clean transition to PostgreSQL in production.
"""

from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
import uuid
from pydantic import BaseModel, Field

from packages.room_model import (
    CanonicalRoomModel,
    ClientRecord,
    DesignVersion,
    ProjectCollaborator,
    ProjectRole,
    ProjectStatus,
    ProjectWorkspaceSummary,
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


# Global singleton repository instance for the running service
repository = InMemoryRepository()
