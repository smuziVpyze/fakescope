from sqlalchemy import Column, String, Float, DateTime, Text, JSON, Boolean
from sqlalchemy.dialects.postgresql import UUID
from app.core.database import Base
from datetime import datetime, timezone
import uuid

class AnalysisRecord(Base):
    __tablename__ = "analyses"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    input_text = Column(Text, nullable=True)       # текст который проверяли
    input_url = Column(String(2048), nullable=True) # URL если был
    verdict = Column(String(20), nullable=False)    # fake / true / unverified
    confidence = Column(Float, nullable=False)      # 0.0 - 1.0
    arguments = Column(JSON, nullable=False)        # список аргументов
    scores = Column(JSON, nullable=False)           # оценки каждого модуля
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

class UserSource(Base):
    __tablename__ = "user_sources"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    domain = Column(String(255), nullable=False, unique=True)
    name = Column(String(255), nullable=False)
    rss_url = Column(String(2048), nullable=True)
    trust_score = Column(Float, default=0.5)
    enabled = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
