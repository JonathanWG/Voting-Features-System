# features/models.py
from django.db import models
from django.conf import settings
from django.core.cache import cache # Import Django's cache
import uuid

class Feature(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    title = models.CharField(max_length=255)
    description = models.TextField()
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='features'
    )
    # Status choices for a feature lifecycle
    STATUS_CHOICES = [
        ('Open', 'Open for Voting'),
        ('Under Review', 'Under Review'),
        ('Planned', 'Planned'),
        ('Completed', 'Completed'),
        ('Archived', 'Archived'),
    ]
    status = models.CharField(
        max_length=50,
        choices=STATUS_CHOICES,
        default='Open'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True) # auto_now updates on every save

    class Meta:
        ordering = ['-created_at'] # Order by most recent features first

    def __str__(self):
        return self.title

    def get_vote_count(self):
        """
        Retrieves vote count from Redis cache. If not in cache,
        calculates from DB and stores in cache.
        """
        cache_key = f'feature:{self.id}:votes'
        count = cache.get(cache_key)
        if count is None:
            count = self.votes.count() # Count related Vote objects
            # Cache for a reasonable duration (e.g., 1 hour), or indefinitely if managed by save/delete hooks
            cache.set(cache_key, count, timeout=3600)
        return count

class Vote(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='votes'
    )
    feature = models.ForeignKey(
        Feature,
        on_delete=models.CASCADE,
        related_name='votes'
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        # Ensures a user can only vote once per feature
        unique_together = ('user', 'feature')
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.username} voted for {self.feature.title}"

    def save(self, *args, **kwargs):
        is_new = self._state.adding # Check if this is a new object being created
        super().save(*args, **kwargs)
        if is_new:
            # Increment vote count in Redis only for new votes
            cache_key = f'feature:{self.feature.id}:votes'
            cache.incr(cache_key) # Atomically increment the count in Redis

    def delete(self, *args, **kwargs):
        # Decrement vote count in Redis when a vote is deleted
        cache_key = f'feature:{self.feature.id}:votes'
        # Check if the key exists before attempting to decrement, to prevent errors
        # if the cache was cleared but the DB entry still exists.
        if cache.get(cache_key) is not None:
            cache.decr(cache_key)
        super().delete(*args, **kwargs)