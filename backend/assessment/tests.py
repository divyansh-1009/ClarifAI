from django.urls import reverse
from django.contrib.auth.models import User
from rest_framework import status
from rest_framework.test import APITestCase
from unittest.mock import patch, MagicMock
from google.api_core import exceptions as google_exceptions

class AssessmentTests(APITestCase):
    def setUp(self):
        self.generate_url = reverse('generate-from-topic')
        self.render_url = reverse('render-from-topic')
        self.user = User.objects.create_user(username='assess_user', email='a@example.com', password='Password123!')
        self.client.force_authenticate(user=self.user)
        
        self.payload = {
            'class_name': 'Class 10',
            'subject': 'Mathematics',
            'topic': 'Trigonometry',
            'difficulty': 'medium'
        }
        
        self.mock_json = """{
            "metadata": {
                "title": "Trigonometry Midterm",
                "total_marks": 10,
                "estimated_time_minutes": 15
            },
            "questions": [
                {
                    "type": "multiple_choice",
                    "marks": 5,
                    "question_text": "What is sin(90)?",
                    "options": ["0", "1", "0.5", "-1"],
                    "answer_key": "1"
                }
            ]
        }"""

    @patch('assessment.views.genai.GenerativeModel')
    @patch.dict('os.environ', {'GOOGLE_API_KEY': 'fake-key'})
    def test_generate_assessment_success_raw_json(self, mock_model_class):
        mock_model = MagicMock()
        mock_response = MagicMock()
        mock_response.text = self.mock_json
        mock_model.generate_content.return_value = mock_response
        mock_model_class.return_value = mock_model

        response = self.client.post(self.generate_url, self.payload)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data['success'])
        self.assertEqual(response.data['assessment_data']['metadata']['title'], "Trigonometry Midterm")
        self.assertEqual(len(response.data['assessment_data']['questions']), 1)

    @patch('assessment.views.genai.GenerativeModel')
    @patch.dict('os.environ', {'GOOGLE_API_KEY': 'fake-key'})
    def test_generate_assessment_success_markdown_fenced(self, mock_model_class):
        mock_model = MagicMock()
        mock_response = MagicMock()
        # Wrap JSON in markdown code blocks
        mock_response.text = f"```json\n{self.mock_json}\n```"
        mock_model.generate_content.return_value = mock_response
        mock_model_class.return_value = mock_model

        response = self.client.post(self.generate_url, self.payload)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data['success'])
        self.assertEqual(response.data['assessment_data']['metadata']['title'], "Trigonometry Midterm")

    def test_generate_assessment_validation_failures(self):
        # Missing subject
        data = self.payload.copy()
        del data['subject']
        response = self.client.post(self.generate_url, data)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        
        # Missing topic
        data = self.payload.copy()
        del data['topic']
        response = self.client.post(self.generate_url, data)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        
        # Invalid difficulty
        data = self.payload.copy()
        data['difficulty'] = 'extreme'
        response = self.client.post(self.generate_url, data)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    @patch('assessment.views.genai.GenerativeModel')
    @patch.dict('os.environ', {'GOOGLE_API_KEY': 'fake-key'})
    def test_generate_assessment_quota_exhausted(self, mock_model_class):
        mock_model = MagicMock()
        # Raise Google's ResourceExhausted exception
        mock_model.generate_content.side_effect = google_exceptions.ResourceExhausted("Rate limit exceeded")
        mock_model_class.return_value = mock_model

        response = self.client.post(self.generate_url, self.payload)
        self.assertEqual(response.status_code, status.HTTP_429_TOO_MANY_REQUESTS)
        self.assertIn("Gemini quota exceeded", response.data['error'])

    @patch('assessment.views.genai.GenerativeModel')
    @patch.dict('os.environ', {'GOOGLE_API_KEY': 'fake-key'})
    def test_generate_assessment_permission_denied(self, mock_model_class):
        mock_model = MagicMock()
        # Raise Google's PermissionDenied exception
        mock_model.generate_content.side_effect = google_exceptions.PermissionDenied("Invalid API key")
        mock_model_class.return_value = mock_model

        response = self.client.post(self.generate_url, self.payload)
        self.assertEqual(response.status_code, status.HTTP_502_BAD_GATEWAY)
        self.assertIn("Gemini API key is invalid", response.data['error'])

    @patch('assessment.views.genai.GenerativeModel')
    @patch.dict('os.environ', {'GOOGLE_API_KEY': 'fake-key'})
    def test_render_assessment_success(self, mock_model_class):
        mock_model = MagicMock()
        mock_response = MagicMock()
        mock_response.text = self.mock_json
        mock_model.generate_content.return_value = mock_response
        mock_model_class.return_value = mock_model

        response = self.client.get(self.render_url, self.payload)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        # Verify rendered HTML template content
        self.assertContains(response, "Trigonometry Midterm")
        self.assertContains(response, "What is sin(90)?")

    def test_render_assessment_validation_failures(self):
        # Missing subject - HTML template response (returns 400 and renders error.html)
        response = self.client.get(self.render_url, {'topic': 'Trigonometry'})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertContains(response, "Subject is required.", status_code=400)
        
        # Invalid difficulty
        response = self.client.get(self.render_url, {
            'topic': 'Trigonometry', 
            'subject': 'Math',
            'difficulty': 'insane'
        })
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertContains(response, "Difficulty must be easy, medium, or hard.", status_code=400)
