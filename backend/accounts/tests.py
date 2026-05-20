from django.urls import reverse
from django.contrib.auth.models import User
from django.core import mail
from rest_framework import status
from rest_framework.test import APITestCase
from rest_framework_simplejwt.tokens import RefreshToken
from .models import EmailOTP

class AccountsTests(APITestCase):
    def setUp(self):
        self.send_otp_url = reverse('auth-register-send-otp')
        self.verify_otp_url = reverse('auth-register-verify-otp')
        self.me_url = reverse('auth-me')
        self.logout_url = reverse('auth-logout')
        self.email = 'user@example.com'
        self.username = 'testuser'
        self.password = 'StrongP@ss123'

    def test_send_otp_method_not_allowed(self):
        response = self.client.get(self.send_otp_url)
        self.assertEqual(response.status_code, status.HTTP_405_METHOD_NOT_ALLOWED)

    def test_send_otp_invalid_email(self):
        response = self.client.post(self.send_otp_url, {'email': 'not-an-email'})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_send_otp_success(self):
        response = self.client.post(self.send_otp_url, {'email': self.email})
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['message'], 'OTP sent to email.')
        
        # Verify EmailOTP created
        otp_record = EmailOTP.objects.filter(email=self.email).first()
        self.assertIsNotNone(otp_record)
        self.assertFalse(otp_record.is_verified)
        
        # Verify email sent
        self.assertEqual(len(mail.outbox), 1)
        self.assertIn(self.email, mail.outbox[0].to)

    def test_send_otp_already_registered(self):
        # Create user
        User.objects.create_user(username=self.username, email=self.email, password=self.password)
        response = self.client.post(self.send_otp_url, {'email': self.email})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('email', response.data)

    def test_verify_otp_success(self):
        # Send OTP first to create record
        self.client.post(self.send_otp_url, {'email': self.email})
        otp_record = EmailOTP.objects.get(email=self.email)
        
        # We need the generated OTP. Since it is sent by email and is random,
        # we can retrieve it directly from the database or outbox to test.
        # Let's mock a fixed OTP or get it from the mail outbox.
        body = mail.outbox[0].body
        # Body contains "Your OTP for email verification is: <otp>"
        import re
        otp_match = re.search(r'Your OTP for email verification is:\s*(\d{6})', body)
        self.assertTrue(otp_match)
        otp = otp_match.group(1)

        payload = {
            'email': self.email,
            'username': self.username,
            'password': self.password,
            'password2': self.password,
            'otp': otp
        }
        response = self.client.post(self.verify_otp_url, payload)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['message'], 'Registration successful.')
        self.assertIn('access', response.data)
        self.assertIn('refresh', response.data)

        # Verify User created
        user_exists = User.objects.filter(username=self.username, email=self.email).exists()
        self.assertTrue(user_exists)

    def test_verify_otp_mismatched_passwords(self):
        self.client.post(self.send_otp_url, {'email': self.email})
        body = mail.outbox[0].body
        import re
        otp = re.search(r'Your OTP for email verification is:\s*(\d{6})', body).group(1)

        payload = {
            'email': self.email,
            'username': self.username,
            'password': self.password,
            'password2': 'differentPassword',
            'otp': otp
        }
        response = self.client.post(self.verify_otp_url, payload)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('password', response.data)

    def test_verify_otp_invalid_otp(self):
        self.client.post(self.send_otp_url, {'email': self.email})
        
        payload = {
            'email': self.email,
            'username': self.username,
            'password': self.password,
            'password2': self.password,
            'otp': '999999' # wrong OTP
        }
        response = self.client.post(self.verify_otp_url, payload)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('otp', response.data)

    def test_verify_otp_no_otp_record(self):
        payload = {
            'email': 'uninitiated@example.com',
            'username': self.username,
            'password': self.password,
            'password2': self.password,
            'otp': '123456'
        }
        response = self.client.post(self.verify_otp_url, payload)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('email', response.data)

    def test_me_unauthenticated(self):
        response = self.client.get(self.me_url)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_me_authenticated(self):
        user = User.objects.create_user(username=self.username, email=self.email, password=self.password)
        self.client.force_authenticate(user=user)
        response = self.client.get(self.me_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['username'], self.username)
        self.assertEqual(response.data['email'], self.email)

    def test_logout_success(self):
        user = User.objects.create_user(username=self.username, email=self.email, password=self.password)
        self.client.force_authenticate(user=user)
        
        # Generate token
        refresh = RefreshToken.for_user(user)
        response = self.client.post(self.logout_url, {'refresh': str(refresh)})
        self.assertEqual(response.status_code, status.HTTP_205_RESET_CONTENT)

    def test_logout_missing_refresh(self):
        user = User.objects.create_user(username=self.username, email=self.email, password=self.password)
        self.client.force_authenticate(user=user)
        
        response = self.client.post(self.logout_url, {})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('detail', response.data)

    def test_logout_invalid_refresh(self):
        user = User.objects.create_user(username=self.username, email=self.email, password=self.password)
        self.client.force_authenticate(user=user)
        
        response = self.client.post(self.logout_url, {'refresh': 'invalid-token-value'})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
