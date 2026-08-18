from datetime import timedelta

from fastapi import Depends, Header, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.rate_limiter import RateLimitExceeded, RateLimiter
from app.db.session import get_session
from app.models.user import AppUser
from app.services.mongo_message_store import (
    MongoMessageStore,
    get_mongo_message_store,
)
from app.services.supabase_auth import supabase_auth

security = HTTPBearer(auto_error=False)


async def get_current_user(
    x_user_id: str | None = Header(default=None, alias="X-User-Id"),
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
    session: AsyncSession = Depends(get_session),
) -> AppUser:
  # Try Supabase auth first
  if supabase_auth.enabled and credentials:
    try:
      payload = await supabase_auth.verify_token(credentials)
      if payload:
        user_id = supabase_auth.get_user_id(payload)
        email = supabase_auth.get_user_email(payload)
        
        # Try to find user by Supabase ID or email
        instance = await session.get(AppUser, user_id)
        if not instance:
          # Find by email
          from sqlalchemy import select
          result = await session.execute(
            select(AppUser).where(AppUser.email == email)
          )
          instance = result.scalar_one_or_none()
        
        if instance:
          return instance
        
        # Auto-create user if authenticated via Supabase but not in DB
        role_str = supabase_auth.get_user_role(payload)
        from app.models.user import Role
        try:
          role = Role[role_str]
        except KeyError:
          role = Role.user
        
        instance = AppUser(
          id=user_id,
          email=email,
          display_name=payload.get("user_metadata", {}).get("display_name", email.split("@")[0]),
          role=role,
        )
        session.add(instance)
        await session.commit()
        await session.refresh(instance)
        return instance
    except HTTPException:
      # If Supabase auth fails, fall through to header-based auth
      pass
  
  # Fall back to X-User-Id header (local auth)
  if not x_user_id:
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Missing X-User-Id header or authentication token",
    )
  instance = await session.get(AppUser, x_user_id)
  if not instance:
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="User not recognized",
  )
  return instance


async def enforce_message_rate_limit(
    current_user: AppUser = Depends(get_current_user),
) -> None:
  if settings.disable_rate_limiting:
    return
  try:
    message_rate_limiter.hit(current_user.id)
  except RateLimitExceeded:
    raise HTTPException(
        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        detail="Message rate limit exceeded. Please slow down.",
    ) from None


async def enforce_session_rate_limit(
    current_user: AppUser = Depends(get_current_user),
) -> None:
  if settings.disable_rate_limiting:
    return
  try:
    session_rate_limiter.hit(current_user.id)
  except RateLimitExceeded:
    raise HTTPException(
        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        detail="Session rate limit exceeded.",
    ) from None
message_rate_limiter = RateLimiter(
    limit=settings.companion_message_rate_per_minute,
    window=timedelta(minutes=1),
)
session_rate_limiter = RateLimiter(
    limit=settings.companion_session_rate_per_minute,
    window=timedelta(minutes=1),
)


async def get_message_store() -> MongoMessageStore:
  return await get_mongo_message_store()
