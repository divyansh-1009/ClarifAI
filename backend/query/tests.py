from django.urls import reverse
from django.contrib.auth.models import User
from rest_framework import status
from rest_framework.test import APITestCase
from unittest.mock import patch, MagicMock
from topic.models import Topic
from knowledge.models import KnowledgeNote

class QueryTests(APITestCase):
    def setUp(self):
        self.ask_url = reverse('query-ask')
        self.user1 = User.objects.create_user(username='q_user1', email='q1@example.com', password='Password123!')
        self.user2 = User.objects.create_user(username='q_user2', email='q2@example.com', password='Password123!')
        
        self.topic1 = Topic.objects.create(user=self.user1, class_name='Class 10', topic='Chemistry')
        self.topic2 = Topic.objects.create(user=self.user2, class_name='Class 10', topic='Biology')
        
        self.note1 = KnowledgeNote.objects.create(user=self.user1, topic=self.topic1, content="Water is H2O.")
        self.note2 = KnowledgeNote.objects.create(user=self.user1, topic=self.topic1, content="Carbon is key to life.")

    @patch('query.views.generate_embedding')
    @patch('query.views.query_similar_notes')
    @patch('query.views.genai.GenerativeModel')
    @patch.dict('os.environ', {'GOOGLE_API_KEY': 'fake-key'})
    def test_query_ask_with_rag_success(self, mock_model_class, mock_query, mock_embed):
        self.client.force_authenticate(user=self.user1)
        mock_embed.return_value = [0.1] * 768
        
        # Mock vector search matches
        mock_query.return_value = [
            {'id': str(self.note1.id), 'score': 0.9},
            {'id': str(self.note2.id), 'score': 0.8}
        ]
        
        # Mock Gemini Model
        mock_model = MagicMock()
        mock_response = MagicMock()
        mock_response.text = "Water is a compound of hydrogen and oxygen, and carbon is essential."
        mock_model.generate_content.return_value = mock_response
        mock_model_class.return_value = mock_model

        payload = {
            'question': 'Tell me about water and carbon.',
            'topic': str(self.topic1.id)
        }
        response = self.client.post(self.ask_url, payload)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['answer'], mock_response.text)
        self.assertTrue(response.data['used_rag'])
        self.assertIn("Water is H2O.", response.data['context'])
        self.assertIn("Carbon is key to life.", response.data['context'])

        # Verify prompt included context
        expected_prompt = f"Context: Water is H2O. Carbon is key to life.\n\nQuestion: {payload['question']}\n\nAnswer:"
        # Since database order could change context list sequence, we check both are in mock_model.generate_content call arg
        called_prompt = mock_model.generate_content.call_args[0][0]
        self.assertIn("Water is H2O.", called_prompt)
        self.assertIn("Carbon is key to life.", called_prompt)
        self.assertIn(payload['question'], called_prompt)

    @patch('query.views.generate_embedding')
    @patch('query.views.query_similar_notes')
    @patch('query.views.genai.GenerativeModel')
    @patch.dict('os.environ', {'GOOGLE_API_KEY': 'fake-key'})
    def test_query_ask_without_rag_success(self, mock_model_class, mock_query, mock_embed):
        self.client.force_authenticate(user=self.user1)
        mock_embed.return_value = [0.1] * 768
        
        # Mock vector search matches returning nothing
        mock_query.return_value = []
        
        # Mock Gemini
        mock_model = MagicMock()
        mock_response = MagicMock()
        mock_response.text = "This is a general answer from LLM."
        mock_model.generate_content.return_value = mock_response
        mock_model_class.return_value = mock_model

        payload = {
            'question': 'Tell me a joke.',
            'topic': str(self.topic1.id)
        }
        response = self.client.post(self.ask_url, payload)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['answer'], mock_response.text)
        self.assertFalse(response.data['used_rag'])
        self.assertEqual(len(response.data['context']), 0)
        
        # Verify prompt had no context prefix
        called_prompt = mock_model.generate_content.call_args[0][0]
        self.assertEqual(called_prompt, f"Question: {payload['question']}\n\nAnswer:")

    def test_query_ask_forbidden_topic(self):
        self.client.force_authenticate(user=self.user1)
        
        # user1 asks on user2's topic
        payload = {
            'question': 'Can I access this?',
            'topic': str(self.topic2.id)
        }
        response = self.client.post(self.ask_url, payload)
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    @patch('query.views.generate_embedding')
    @patch('query.views.query_similar_notes')
    @patch('query.views.genai.GenerativeModel')
    @patch.dict('os.environ', {'GOOGLE_API_KEY': 'fake-key'})
    def test_query_ask_gemini_failure(self, mock_model_class, mock_query, mock_embed):
        self.client.force_authenticate(user=self.user1)
        mock_embed.return_value = [0.1] * 768
        mock_query.return_value = []
        
        # Mock Gemini to raise error
        mock_model = MagicMock()
        mock_model.generate_content.side_effect = Exception("API Connection failure")
        mock_model_class.return_value = mock_model

        payload = {
            'question': 'Should fail.',
            'topic': str(self.topic1.id)
        }
        response = self.client.post(self.ask_url, payload)
        self.assertEqual(response.status_code, status.HTTP_502_BAD_GATEWAY)
        self.assertIn("AI generation failed", response.data['detail'])
