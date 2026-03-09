from django.db import models
from django.contrib.auth.models import User
from django.utils import timezone
from datetime import timedelta
import hashlib
import secrets


class EmailOTP(models.Model):
    """
    Model to store email verification OTP codes.
    """
    email = models.EmailField(unique=True)
    otp_hash = models.CharField(max_length=64) 
    attempts = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_verified = models.BooleanField(default=False)

    class Meta:
        db_table = 'email_otp'

    def __str__(self):
        return f"OTP for {self.email}"

    @staticmethod
    def generate_otp():
        return str(secrets.randbelow(1000000)).zfill(6)

    @staticmethod
    def hash_otp(otp):
        return hashlib.sha256(otp.encode()).hexdigest()

    def set_otp(self, otp):
        self.otp_hash = self.hash_otp(otp)
        self.expires_at = timezone.now() + timedelta(minutes=10)
        self.attempts = 0

    def verify_otp(self, otp):
        if self.is_verified:
            return False, "Email already verified."

        if timezone.now() > self.expires_at:
            return False, "OTP expired."

        if self.attempts >= 5:
            return False, "Maximum attempts exceeded."

        self.attempts += 1
        self.save()

        if self.hash_otp(otp) == self.otp_hash:
            self.is_verified = True
            self.save()
            return True, "Email verified successfully."

        return False, "Invalid OTP."

    def is_expired(self):
        """Check if OTP has expired."""
        return timezone.now() > self.expires_at
