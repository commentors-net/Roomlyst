import os
import tempfile
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Ensure test uses an isolated SQLite test database in temp directory
test_db_path = os.path.join(tempfile.gettempdir(), "test_roomlyst.db").replace("\\", "/")
os.environ["DATABASE_URL"] = f"sqlite:///{test_db_path}"
os.environ["SECRET_KEY"] = "test-secret-key-roomlyst-2026"
os.environ["STORAGE_BACKEND"] = "local"
os.environ["LOCAL_STORAGE_PATH"] = "storage"

from services.api.app.db.models import Base
from services.api.app.db.session import engine
from services.api.app.core.rate_limit import general_limiter, generation_limiter


@pytest.fixture(autouse=True)
def clean_database():
    """Wipes and recreates tables and resets rate limiters before each test to ensure test isolation."""
    general_limiter.reset()
    generation_limiter.reset()
    engine.dispose()
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    yield
    general_limiter.reset()
    generation_limiter.reset()
    engine.dispose()
    try:
        Base.metadata.drop_all(bind=engine)
    except Exception:
        pass


@pytest.fixture
def db_session():
    """Provides a transactional database session for tests."""
    from services.api.app.db.session import SessionLocal
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()

