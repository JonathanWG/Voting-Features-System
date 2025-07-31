# users/models.py
from django.contrib.auth.models import AbstractUser
from django.db import models

class CustomUser(AbstractUser):
    # Add any additional fields here if you need them in the future.
    # Example: bio = models.TextField(blank=True, null=True)
    # For now, AbstractUser provides username, email, password, etc.
    pass