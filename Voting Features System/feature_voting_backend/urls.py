# feature_voting_backend/urls.py
from django.contrib import admin
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView

from features.views import FeatureViewSet, UserViewSet, CustomTokenObtainPairView

router = DefaultRouter()
router.register(r'features', FeatureViewSet)
router.register(r'users', UserViewSet, basename='user') # 'basename' is needed for ViewSets not linked to a model

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include(router.urls)), # Includes paths for features and users (register, me)
    path('api/token/', CustomTokenObtainPairView.as_view(), name='token_obtain_pair'), # Login
    path('api/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'), # Refresh JWT token
]