# features/views.py
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework_simplejwt.views import TokenObtainPairView
from django.shortcuts import get_object_or_404
from django.db import IntegrityError # For handling unique constraints

from .models import Feature, Vote
from .serializers import FeatureSerializer, VoteSerializer, UserSerializer, UserRegisterSerializer, CustomTokenObtainPairSerializer
from users.models import CustomUser # Import your custom user model

class CustomTokenObtainPairView(TokenObtainPairView):
    """
    Custom JWT login view that uses our CustomTokenObtainPairSerializer.
    """
    serializer_class = CustomTokenObtainPairSerializer

class UserViewSet(viewsets.ViewSet):
    """
    A simple ViewSet for user registration and retrieving the current user's profile.
    """
    # Permissions are set per action for granularity
    def get_permissions(self):
        if self.action == 'register':
            permission_classes = [AllowAny] # Anyone can register
        elif self.action == 'me':
            permission_classes = [IsAuthenticated] # Only authenticated can view their profile
        else:
            permission_classes = [AllowAny] # Default to allow any (e.g., if other custom actions are added)
        return [permission() for permission in permission_classes]

    @action(detail=False, methods=['post'], url_path='register')
    def register(self, request):
        """
        Registers a new user.
        """
        serializer = UserRegisterSerializer(data=request.data)
        if serializer.is_valid():
            try:
                user = serializer.save()
                return Response(UserSerializer(user).data, status=status.HTTP_201_CREATED)
            except IntegrityError:
                return Response(
                    {'detail': 'A user with that username or email already exists.'},
                    status=status.HTTP_400_BAD_REQUEST
                )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=False, methods=['get'], url_path='me')
    def current_user(self, request):
        """
        Retrieves the profile of the currently authenticated user.
        """
        serializer = UserSerializer(request.user)
        return Response(serializer.data)

    # You could add 'update_profile' or 'change_password' actions here if needed

class FeatureViewSet(viewsets.ModelViewSet):
    """
    A ViewSet for viewing and editing features.
    Provides list, retrieve, create, update, delete, upvote, and unvote actions.
    """
    queryset = Feature.objects.all()
    serializer_class = FeatureSerializer

    def get_permissions(self):
        """
        Set permissions based on the action.
        - list/retrieve (view features): AllowAny (publicly accessible)
        - create (post feature): IsAuthenticated (only logged-in users)
        - update/partial_update/destroy (edit/delete feature): IsAuthenticated (and potentially IsOwner or IsAdmin)
        - upvote/unvote: IsAuthenticated
        """
        if self.action in ['list', 'retrieve']:
            permission_classes = [AllowAny]
        elif self.action in ['create', 'upvote', 'unvote']:
            permission_classes = [IsAuthenticated]
        elif self.action in ['update', 'partial_update', 'destroy']:
            # For update/delete, you'd typically want custom permissions
            # e.g., only the creator or an admin can modify/delete.
            # For simplicity, this example just requires authentication.
            # To restrict to owner:
            # from rest_framework import permissions
            # class IsOwnerOrReadOnly(permissions.BasePermission):
            #     def has_object_permission(self, request, view, obj):
            #         if request.method in permissions.SAFE_METHODS:
            #             return True
            #         return obj.created_by == request.user
            # permission_classes = [IsAuthenticated, IsOwnerOrReadOnly]
            permission_classes = [IsAuthenticated]
        else:
            permission_classes = [IsAuthenticated] # Default for any other custom action
        return [permission() for permission in permission_classes]

    def perform_create(self, serializer):
        """
        When creating a feature, automatically set the 'created_by' to the current user.
        """
        serializer.save(created_by=self.request.user)

    @action(detail=True, methods=['post'], url_path='upvote')
    def upvote(self, request, pk=None):
        """
        Custom action to upvote a specific feature.
        """
        feature = get_object_or_404(Feature, pk=pk)
        user = request.user

        try:
            # Attempt to create a new vote record
            vote = Vote.objects.create(user=user, feature=feature)
            serializer = VoteSerializer(vote)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        except IntegrityError:
            # If IntegrityError occurs, it means the unique_together constraint was violated (duplicate vote)
            return Response(
                {'detail': 'You have already upvoted this feature.'},
                status=status.HTTP_400_BAD_REQUEST
            )

    @action(detail=True, methods=['post'], url_path='unvote')
    def unvote(self, request, pk=None):
        """
        Custom action to remove an upvote for a specific feature.
        """
        feature = get_object_or_404(Feature, pk=pk)
        user = request.user

        # Find and delete the existing vote
        vote = Vote.objects.filter(user=user, feature=feature).first()
        if not vote:
            return Response(
                {'detail': 'You have not upvoted this feature.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        vote.delete() # This will trigger the delete hook to decrement Redis
        return Response(
            {'detail': 'Vote removed successfully.'},
            status=status.HTTP_204_NO_CONTENT # 204 for successful deletion with no content
        )