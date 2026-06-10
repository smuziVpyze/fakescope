from sqlalchemy import Column, String, Float, DateTime, Text, JSON, Boolean
from sqlalchemy.dialects.postgresql import UUID
from app.core.database import Base
from datetime import datetime, timezone
import uuid

class AnalysisRecord(Base):
    __tablename__ = "analyses"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    input_text = Column(Text, nullable=True)
    input_url = Column(String(2048), nullable=True)
    verdict = Column(String(20), nullable=False)
    confidence = Column(Float, nullable=False)
    arguments = Column(JSON, nullable=False)
    scores = Column(JSON, nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


class UserSource(Base):
    __tablename__ = "user_sources"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    domain = Column(String(255), nullable=False, unique=True)
    name = Column(String(255), nullable=False)
    rss_url = Column(String(2048), nullable=True)
    trust_score = Column(Float, default=0.5)
    user_trust_score = Column(Float, nullable=True, default=None)
    enabled = Column(Boolean, default=True, nullable=False)
    is_builtin = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    @property
    def effective_trust_score(self) -> float:
        if self.user_trust_score is not None:
            return self.user_trust_score
        return self.trust_score


class FactCheckEntry(Base):
    __tablename__ = "factcheck_entries"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    text = Column(Text, nullable=False, unique=True)
    title = Column(String(500), nullable=True)
    verdict = Column(String(20), nullable=False)
    source_url = Column(String(2048), nullable=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
