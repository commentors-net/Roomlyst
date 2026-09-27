"""
In-Memory & File-Backed Repository for Phase 0 POC state.
Stores Projects, Rooms, and Canonical Room Models.
Prepares clean transition to PostgreSQL in Phase 1.
"""

from typing import Dict, List, Optional
import uuid
from pydantic import BaseModel, Field

from packages.room_model import CanonicalRoomModel, DesignVersion


class ProjectRecord(BaseModel):
    id: str = Field(default_factory=lambda: f"proj_{uuid.uuid4().hex[:8]}")
    name: str
    currency: str = "MYR"
    room_ids: List[str] = Field(default_factory=list)


class InMemoryRepository:
    """Thread-safe store for development & POC execution."""

    def __init__(self):
        self.projects: Dict[str, ProjectRecord] = {}
        self.rooms: Dict[str, CanonicalRoomModel] = {}

    def create_project(self, name: str, currency: str = "MYR") -> ProjectRecord:
        proj = ProjectRecord(name=name, currency=currency)
        self.projects[proj.id] = proj
        return proj

    def get_project(self, project_id: str) -> Optional[ProjectRecord]:
        return self.projects.get(project_id)

    def list_projects(self) -> List[ProjectRecord]:
        return list(self.projects.values())

    def save_room(self, room: CanonicalRoomModel) -> CanonicalRoomModel:
        self.rooms[room.id] = room
        if room.project_id in self.projects:
            if room.id not in self.projects[room.project_id].room_ids:
                self.projects[room.project_id].room_ids.append(room.id)
        return room

    def get_room(self, room_id: str) -> Optional[CanonicalRoomModel]:
        return self.rooms.get(room_id)

    def list_rooms(self) -> List[CanonicalRoomModel]:
        return list(self.rooms.values())


# Global singleton repository instance for the running service
repository = InMemoryRepository()
