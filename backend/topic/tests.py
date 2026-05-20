from django.urls import reverse
from django.contrib.auth.models import User
from django.core.files.uploadedfile import SimpleUploadedFile
from rest_framework import status
from rest_framework.test import APITestCase
from unittest.mock import patch, MagicMock
from .models import Topic

class TopicTests(APITestCase):
    def setUp(self):
        self.create_url = reverse('topic-create')
        self.user = User.objects.create_user(username='topicuser', email='topic@example.com', password='Password123!')
        self.client.force_authenticate(user=self.user)
        self.payload = {
            'class_name': 'Class 10',
            'topic': 'Quadratic Equations'
        }

    def test_create_topic_success(self):
        response = self.client.post(self.create_url, self.payload)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['class_name'], self.payload['class_name'])
        self.assertEqual(response.data['topic'], self.payload['topic'])
        
        # Verify db record
        self.assertTrue(Topic.objects.filter(user=self.user, topic=self.payload['topic']).exists())

    def test_create_topic_missing_fields(self):
        # Missing class_name
        response = self.client.post(self.create_url, {'topic': 'Physics'})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        
        # Missing topic
        response = self.client.post(self.create_url, {'class_name': '10th'})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    @patch('knowledge.vector_utils.generate_embedding')
    @patch('knowledge.vector_utils.upsert_note_vector')
    def test_create_topic_with_pdf_success(self, mock_upsert, mock_embed):
        mock_embed.return_value = [0.1] * 768
        
        # Mock PdfReader
        mock_reader = MagicMock()
        mock_page = MagicMock()
        mock_page.extract_text.return_value = "This is some dummy text extracted from notes."
        mock_reader.pages = [mock_page]
        
        pdf_file = SimpleUploadedFile('notes.pdf', b'fake pdf bytes', content_type='application/pdf')
        data = self.payload.copy()
        data['notes'] = pdf_file

        with patch('PyPDF2.PdfReader', return_value=mock_reader):
            response = self.client.post(self.create_url, data, format='multipart')

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(Topic.objects.filter(user=self.user, topic=self.payload['topic']).exists())
        
        # Verify knowledge note was created in db
        from knowledge.models import KnowledgeNote
        note = KnowledgeNote.objects.filter(user=self.user, content="This is some dummy text extracted from notes.").first()
        self.assertIsNotNone(note)
        
        # Verify Pinecone/embedding mock calls
        mock_embed.assert_called_once_with("This is some dummy text extracted from notes.")
        mock_upsert.assert_called_once()

    def test_create_topic_with_invalid_file_type(self):
        txt_file = SimpleUploadedFile('notes.txt', b'fake txt bytes', content_type='text/plain')
        data = self.payload.copy()
        data['notes'] = txt_file

        response = self.client.post(self.create_url, data, format='multipart')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('error', response.data)
        
        # Verify topic was deleted/not saved
        self.assertFalse(Topic.objects.filter(user=self.user, topic=self.payload['topic']).exists())

    @patch('knowledge.vector_utils.generate_embedding')
    def test_create_topic_with_empty_pdf(self, mock_embed):
        # Mock PdfReader returning no text
        mock_reader = MagicMock()
        mock_page = MagicMock()
        mock_page.extract_text.return_value = "" # No text
        mock_reader.pages = [mock_page]
        
        pdf_file = SimpleUploadedFile('empty.pdf', b'fake empty pdf', content_type='application/pdf')
        data = self.payload.copy()
        data['notes'] = pdf_file

        with patch('PyPDF2.PdfReader', return_value=mock_reader):
            response = self.client.post(self.create_url, data, format='multipart')

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('Failed to process PDF', response.data['error'])
        
        # Verify topic was deleted
        self.assertFalse(Topic.objects.filter(user=self.user, topic=self.payload['topic']).exists())
