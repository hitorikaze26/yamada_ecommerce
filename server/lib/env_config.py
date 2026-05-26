"""
Centralized environment configuration for enabling/disabling deployment-specific behavior.

This module provides environment-aware toggles that allow temporarily disabling
production/deployment behavior while preserving the existing production architecture.
"""

import os
from typing import List


def _get_bool_env(var_name: str, default: bool = False) -> bool:
    """Get boolean environment variable with default."""
    value = os.environ.get(var_name, "")
    if not value:
        return default
    return value.lower() in ("true", "1", "yes", "on")


def _get_app_env() -> str:
    """Get application environment."""
    return os.environ.get("APP_ENV", "development")


# Application environment
APP_ENV = _get_app_env()

# Environment flags for controlling deployment-specific behavior
USE_LOCAL_STORAGE = _get_bool_env("USE_LOCAL_STORAGE", APP_ENV == "development")
USE_SUPABASE_STORAGE = _get_bool_env("USE_SUPABASE_STORAGE", APP_ENV == "production")
USE_PRODUCTION_COOKIES = _get_bool_env("USE_PRODUCTION_COOKIES", APP_ENV == "production")
USE_PRODUCTION_URLS = _get_bool_env("USE_PRODUCTION_URLS", APP_ENV == "production")
USE_RAILWAY_DETECTION = _get_bool_env("USE_RAILWAY_DETECTION", APP_ENV == "production")
USE_VERCEL_DETECTION = _get_bool_env("USE_VERCEL_DETECTION", APP_ENV == "production")

# Development/production flags
IS_DEVELOPMENT = APP_ENV == "development"
IS_PRODUCTION = APP_ENV == "production"


def get_api_base_url() -> str:
    """
    Get the appropriate API base URL based on environment flags.
    
    In development: http://127.0.0.1:5000/api
    In production: Uses API_BASE_URL or falls back to Railway detection
    """
    # If explicitly using production URLs, use the configured API base URL
    if USE_PRODUCTION_URLS:
        explicit = os.environ.get("API_BASE_URL", "").strip()
        if explicit:
            return explicit.rstrip("/")
        
        # Fall back to Railway detection if enabled
        if USE_RAILWAY_DETECTION:
            railway = os.environ.get("RAILWAY_PUBLIC_DOMAIN", "").strip()
            if railway:
                return f"https://{railway}/api"
    
    # Default to localhost API for development
    return "http://127.0.0.1:5000/api"


def get_frontend_url() -> str:
    """
    Derive canonical frontend URL from env or build from Railway/Vercel.
    """
    explicit = os.environ.get("FRONTEND_URL", "").strip()
    if explicit:
        return explicit.rstrip("/")
    
    # Use production URLs if enabled
    if USE_PRODUCTION_URLS:
        vercel = os.environ.get("VERCEL_URL", "").strip()
        if vercel and USE_VERCEL_DETECTION:
            return f"https://{vercel}"
        
        vercel_branch = os.environ.get("VERCEL_BRANCH_URL", "").strip()
        if vercel_branch and USE_VERCEL_DETECTION:
            return f"https://{vercel_branch}"
        
        railway = os.environ.get("RAILWAY_PUBLIC_DOMAIN", "").strip()
        if railway and USE_RAILWAY_DETECTION:
            return f"https://{railway}"
    
    # Default to localhost for development
    return "http://localhost:3000"


def get_cors_origins(frontend_url: str) -> List[str]:
    """
    Build allowed CORS origins from FRONTEND_URL, CORS_ORIGINS env, and defaults.
    """
    LOCAL_FALLBACKS = ("http://localhost:3000", "http://127.0.0.1:3000")

    raw = os.environ.get("CORS_ORIGINS", "").strip()
    origins: List[str] = []
    seen: set[str] = set()

    for part in raw.replace(";", ",").split(","):
        origin = part.strip().strip('"').strip("'")
        if origin and origin not in seen:
            seen.add(origin)
            origins.append(origin)

    if frontend_url and frontend_url not in seen:
        seen.add(frontend_url)
        origins.append(frontend_url)

    # Add local fallbacks in development
    if IS_DEVELOPMENT or frontend_url == "http://localhost:3000":
        for fallback in LOCAL_FALLBACKS:
            if fallback not in seen:
                seen.add(fallback)
                origins.append(fallback)

    # Add Railway domain if enabled
    if USE_RAILWAY_DETECTION:
        railwy_domain = os.environ.get("RAILWAY_PUBLIC_DOMAIN", "").strip()
        if railwy_domain:
            railwy_origin = f"https://{railwy_domain}"
            if railwy_origin not in seen:
                seen.add(railwy_origin)
                origins.append(railwy_origin)

    return origins


class EnvFlags:
    """Environment flags for controlling deployment-specific behavior."""
    
    APP_ENV = APP_ENV
    USE_LOCAL_STORAGE = USE_LOCAL_STORAGE
    USE_SUPABASE_STORAGE = USE_SUPABASE_STORAGE
    USE_PRODUCTION_COOKIES = USE_PRODUCTION_COOKIES
    USE_PRODUCTION_URLS = USE_PRODUCTION_URLS
    USE_RAILWAY_DETECTION = USE_RAILWAY_DETECTION
    USE_VERCEL_DETECTION = USE_VERCEL_DETECTION
    IS_DEVELOPMENT = IS_DEVELOPMENT
    IS_PRODUCTION = IS_PRODUCTION
    
    @staticmethod
    def get_api_base_url() -> str:
        return get_api_base_url()
    
    @staticmethod
    def get_frontend_url() -> str:
        return get_frontend_url()
    
    @staticmethod
    def get_cors_origins(frontend_url: str) -> List[str]:
        return get_cors_origins(frontend_url)