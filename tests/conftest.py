import os
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Ensure test uses an isolated SQLite test database
os.environ["DATABASE_URL"] = "sqlite:///./test_roomlyst.db"
os.environ["SECRET_KEY"] = "test-secret-key-roomlyst-2026"
os.environ["STORAGE_BACKEND"] = "local"
os.environ["LOCAL_STORAGE_PATH"] = "storage"

from services.api.app.db.models import Base
from services.api.app.db.session import engine


@pytest.fixture(autouse=True)
def clean_database():
    """Wipes and recreates tables before each test to ensure test isolation."""
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def db_session():
    """Provides a transactional database session for tests."""
    from services.api.app.db.session import SessionLocal
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()

