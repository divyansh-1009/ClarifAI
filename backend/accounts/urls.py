from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

from .views import LogoutView, MeView, RegisterOTPView, VerifyEmailOTPView

urlpatterns = [
    path('register/send-otp/', RegisterOTPView.as_view(), name='auth-register-send-otp'),
    path('register/verify-otp/', VerifyEmailOTPView.as_view(), name='auth-register-verify-otp'),
    path('login/', TokenObtainPairView.as_view(), name='auth-login'),
    path('token/refresh/', TokenRefreshView.as_view(), name='auth-token-refresh'),
    path('logout/', LogoutView.as_view(), name='auth-logout'),
    path('me/', MeView.as_view(), name='auth-me'),
]
