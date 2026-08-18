"""Supabase JWT authentication service."""
from __future__ import annotations

from typing import Optional
from jose import JWTError, jwt
from fastapi import HTTPException, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from app.core.config import settings

security = HTTPBearer(auto_error=False)


class SupabaseAuth:
    """Handles Supabase JWT token verification."""
    
    def __init__(self):
        self.jwt_secret = settings.supabase_jwt_secret
        self.enabled = bool(self.jwt_secret)
    
    async def verify_token(
        self,
        credentials: Optional[HTTPAuthorizationCredentials] = Security(security)
    ) -> Optional[dict]:
        """
        Verify Supabase JWT token and return user payload.
        Returns None if Supabase is not configured (allows fallback to local auth).
        """
        if not self.enabled:
            return None
        
        if not credentials:
            raise HTTPException(
                status_code=401,
                detail="Missing authentication token",
            )
        
        token = credentials.credentials
        
        try:
            payload = jwt.decode(
                token,
                self.jwt_secret,
                algorithms=["HS256"],
                audience="authenticated",
            )
            return payload
        except JWTError as e:
            raise HTTPException(
                status_code=401,
                detail=f"Invalid authentication token: {str(e)}",
            )
    
    def get_user_id(self, payload: dict) -> str:
        """Extract user ID from JWT payload."""
        return payload.get("sub", "")
    
    def get_user_email(self, payload: dict) -> str:
        """Extract user email from JWT payload."""
        return payload.get("email", "")
    
    def get_user_role(self, payload: dict) -> str:
        """Extract user role from JWT payload metadata."""
        user_metadata = payload.get("user_metadata", {})
        app_metadata = payload.get("app_metadata", {})
        
        # Check app_metadata first (set by admin)
        role = app_metadata.get("role")
        if role:
            return role
        
        # Fall back to user_metadata
        role = user_metadata.get("role")
        if role:
            return role
        
        # Default role
        return "user"


# Singleton instance
supabase_auth = SupabaseAuth()
