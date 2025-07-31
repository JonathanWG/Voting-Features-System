# features/serializers.py
from rest_framework import serializers
from .models import Feature, Vote
from django.contrib.auth import get_user_model
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

User = get_user_model() # Get the currently active user model

class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    """
    Custom serializer to include username and email in JWT payload.
    """
    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        token['username'] = user.username
        token['email'] = user.email
        return token

class UserSerializer(serializers.ModelSerializer):
    """
    Serializer for basic user information.
    """
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name']
        read_only_fields = ['id', 'username', 'email'] # Fields that cannot be updated directly via this serializer

class UserRegisterSerializer(serializers.ModelSerializer):
    """
    Serializer for user registration. Handles password hashing.
    """
    password = serializers.CharField(write_only=True, required=True, min_length=6)
    email = serializers.EmailField(required=True)

    class Meta:
        model = User
        fields = ['username', 'email', 'password']

    def validate_email(self, value):
        """
        Check if email is already in use.
        """
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("A user with that email already exists.")
        return value

    def create(self, validated_data):
        """
        Create a new user with hashed password.
        """
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password']
        )
        return user

class FeatureSerializer(serializers.ModelSerializer):
    """
    Serializer for Feature objects, including vote count and user's vote status.
    """
    created_by = UserSerializer(read_only=True) # Nested serializer for creator details
    vote_count = serializers.SerializerMethodField() # Custom field for vote count
    has_voted = serializers.SerializerMethodField() # Custom field to check if current user has voted

    class Meta:
        model = Feature
        fields = ['id', 'title', 'description', 'status', 'created_by', 'created_at', 'updated_at', 'vote_count', 'has_voted']
        read_only_fields = ['id', 'created_by', 'created_at', 'updated_at', 'vote_count', 'has_voted']

    def get_vote_count(self, obj):
        """
        Returns the cached vote count for the feature.
        """
        return obj.get_vote_count()

    def get_has_voted(self, obj):
        """
        Checks if the authenticated user has voted for this feature.
        Requires 'request' in serializer context.
        """
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            # Check if a Vote object exists for the current user and feature
            return Vote.objects.filter(feature=obj, user=request.user).exists()
        return False

class VoteSerializer(serializers.ModelSerializer):
    """
    Serializer for Vote objects. Read-only as votes are handled via custom actions.
    """
    user = UserSerializer(read_only=True)
    feature = FeatureSerializer(read_only=True) # Full feature details included

    class Meta:
        model = Vote
        fields = ['id', 'user', 'feature', 'created_at']
        read_only_fields = ['id', 'user', 'feature', 'created_at']