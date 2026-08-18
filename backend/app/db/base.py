from sqlalchemy.orm import DeclarativeBase, declared_attr


class Base(DeclarativeBase):
  """Base class for SQLAlchemy models with automatic table naming."""

  @declared_attr.directive
  def __tablename__(cls) -> str:  # type: ignore
    return cls.__name__.lower()
