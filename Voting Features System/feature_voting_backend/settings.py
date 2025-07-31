# feature_voting_backend/settings.py

import os
from datetime import timedelta

# ... existing imports and settings ...

# Add your apps
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'rest_framework_simplejwt',
    'corsheaders', # Added for CORS handling
    'users',      # Custom User app
    'features',   # Features and Voting app
]

# Add CORS Middleware
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'corsheaders.middleware.CorsMiddleware', # IMPORTANT: Must be placed very high
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

# CORS Settings - Adjust as needed for your frontend domain(s) in production
CORS_ALLOWED_ORIGINS = [
    "http://localhost:3000",  # Default Flutter web development port
    "http://127.0.0.1:3000",
    "http://localhost:8080",  # Another common Flutter web development port
    "http://127.0.0.1:8080",
    "http://localhost",       # Generic localhost for some web scenarios
    # For Android Emulator to access host machine:
    "http://10.0.2.2:8000", # This specifically allows Flutter Android to connect to Django on host
    # Add your production Flutter web domain here, e.g., "https://your.prod.domain"
]
# In production, set CORS_ALLOW_ALL_ORIGINS = False and precisely list allowed origins.
CORS_ALLOW_ALL_ORIGINS = True # For development, simplifies setup
CORS_ALLOW_CREDENTIALS = True # Allow cookies/auth headers

# Database Configuration (PostgreSQL)
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'feature_voting_db',      # Your database name
        'USER': 'your_db_user',          # Your PostgreSQL username
        'PASSWORD': 'your_db_password',  # Your PostgreSQL password
        'HOST': 'localhost',             # Or your database host (e.g., 'db' if using Docker Compose)
        'PORT': '5432',
    }
}

# Custom User Model
AUTH_USER_MODEL = 'users.CustomUser'

# REST Framework Settings
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        # Allow authenticated users full access, read-only for unauthenticated
        'rest_framework.permissions.IsAuthenticatedOrReadOnly',
    ),
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 10, # Number of items per page for list views
}

# Simple JWT Settings
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=15), # Shorter for security, refresh often
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
    'ROTATE_REFRESH_TOKENS': True, # Automatically generate new refresh token on refresh
    'BLACKLIST_AFTER_ROTATION': True, # Invalidate old refresh token

    'ALGORITHM': 'HS256',
    'SIGNING_KEY': SECRET_KEY,
    'VERIFYING_KEY': None,
    'AUDIENCE': None,
    'ISSUER': None,
    'JWK_URL': None,
    'LEEWAY': 0,

    'AUTH_HEADER_TYPES': ('Bearer',),
    'AUTH_HEADER_NAME': 'HTTP_AUTHORIZATION',
    'USER_ID_FIELD': 'id',
    'USER_ID_CLAIM': 'user_id',
    'USER_AUTHENTICATION_RULE': 'rest_framework_simplejwt.authentication.default_user_authentication_rule',

    'AUTH_TOKEN_CLASSES': ('rest_framework_simplejwt.tokens.AccessToken',),
    'TOKEN_TYPE_CLAIM': 'token_type',
    'TOKEN_USER_CLASS': 'rest_framework_simplejwt.models.TokenUser',

    'JTI_CLAIM': 'jti',
}

# Redis Cache Settings
CACHES = {
    "default": {
        "BACKEND": "django_redis.cache.RedisCache",
        "LOCATION": "redis://127.0.0.1:6379/1", # Using database 1 in Redis
        "OPTIONS": {
            "CLIENT_CLASS": "django_redis.client.DefaultClient",
        }
    }
}