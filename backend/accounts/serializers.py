from django.contrib.auth.models import User
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers
from django.core.mail import send_mail
from django.conf import settings
from django.utils import timezone
from .models import EmailOTP


class EmailOTPSerializer(serializers.Serializer):
    """Serializer for sending OTP to email."""
    email = serializers.EmailField()

    def validate_email(self, value):
        """Check if email is already registered."""
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("Email already registered.")
        return value

    def create(self, validated_data):
        """Generate and send OTP."""
        email = validated_data['email']

        email_otp, created = EmailOTP.objects.get_or_create(
            email=email,
            defaults={
                'otp_hash': EmailOTP.hash_otp('000000'),
                'expires_at': timezone.now(),
            },
        )
        
        otp = EmailOTP.generate_otp()
        email_otp.set_otp(otp)
        email_otp.is_verified = False
        email_otp.save()
        
        subject = "ClarifAI Email Verification"
        message = f"""
Hello,

Your OTP for email verification is: {otp}

This OTP is valid for 10 minutes.
If you did not request this, please ignore this email.

Best regards,
Team ClarifAI
"""
        send_mail(
            subject,
            message,
            settings.DEFAULT_FROM_EMAIL,
            [email],
            fail_silently=False,
        )
        
        return {"message": "OTP sent to email."}


class VerifyEmailOTPSerializer(serializers.Serializer):
    """Serializer for verifying OTP and registering user."""
    email = serializers.EmailField()
    username = serializers.CharField(min_length=3, max_length=150)
    password = serializers.CharField(write_only=True, validators=[validate_password])
    password2 = serializers.CharField(write_only=True)
    otp = serializers.CharField(min_length=6, max_length=6)

    def validate_email(self, value):
        """Check if email is already registered."""
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("Email already registered.")
        return value

    def validate_username(self, value):
        """Check if username is already taken."""
        if User.objects.filter(username=value).exists():
            raise serializers.ValidationError("Username already taken.")
        return value

    def validate(self, attrs):
        """Validate passwords match and verify OTP."""
        if attrs['password'] != attrs['password2']:
            raise serializers.ValidationError({"password": "Passwords do not match."})
        
        try:
            email_otp = EmailOTP.objects.get(email=attrs['email'])
        except EmailOTP.DoesNotExist:
            raise serializers.ValidationError({"email": "No OTP found for this email."})
        
        is_valid, message = email_otp.verify_otp(attrs['otp'])
        if not is_valid:
            raise serializers.ValidationError({"otp": message})
        
        return attrs

    def create(self, validated_data):
        """Create user after OTP verification."""
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password']
        )
        return user


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ('id', 'username', 'email')
