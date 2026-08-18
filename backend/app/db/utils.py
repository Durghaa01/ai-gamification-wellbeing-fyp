"""Database utility functions and helpers."""
from datetime import datetime, timezone
from typing import TypeVar

from sqlalchemy import Index
from sqlalchemy.ext.asyncio import AsyncSession


T = TypeVar("T")


def utcnow() -> datetime:
    """Get current UTC datetime with timezone awareness.
    
    Replaces deprecated datetime.utcnow() in Python 3.12+
    """
    return datetime.now(timezone.utc)


async def get_or_create(
    session: AsyncSession,
    model: type[T],
    defaults: dict | None = None,
    **kwargs,
) -> tuple[T, bool]:
    """Get an existing instance or create a new one.
    
    Args:
        session: Database session
        model: SQLAlchemy model class
        defaults: Default values for creation
        **kwargs: Filter criteria
        
    Returns:
        Tuple of (instance, created_flag)
    """
    instance = await session.get(model, kwargs)
    if instance:
        return instance, False
    
    params = kwargs | (defaults or {})
    instance = model(**params)
    session.add(instance)
    return instance, True


def create_composite_index(
    table_name: str,
    *columns: str,
    name: str | None = None,
    unique: bool = False,
) -> Index:
    """Helper to create composite indexes with naming convention.
    
    Args:
        table_name: Name of the table
        *columns: Column names to index
        name: Optional custom index name
        unique: Whether index should enforce uniqueness
        
    Returns:
        SQLAlchemy Index object
    """
    if not name:
        prefix = "uq" if unique else "ix"
        col_str = "_".join(columns)
        name = f"{prefix}_{table_name}_{col_str}"
    
    return Index(name, *columns, unique=unique)
