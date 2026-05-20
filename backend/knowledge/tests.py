from django.urls import reverse
from django.contrib.auth.models import User
from rest_framework import status
from rest_framework.test import APITestCase
from unittest.mock import patch
from topic.models import Topic
from .models import KnowledgeNote

class KnowledgeTests(APITestCase):
    def setUp(self):
        self.create_url = reverse('knowledge-note-create')
        self.user1 = User.objects.create_user(username='user1', email='user1@example.com', password='Password123!')
        self.user2 = User.objects.create_user(username='user2', email='user2@example.com', password='Password123!')
        
        # Create topics
        self.topic1 = Topic.objects.create(user=self.user1, class_name='Class 10', topic='Algebra')
        self.topic2 = Topic.objects.create(user=self.user2, class_name='Class 11', topic='Physics')

    @patch('knowledge.views.generate_embedding')
    @patch('knowledge.vector_utils.upsert_note_vector')
    def test_create_note_success(self, mock_upsert, mock_embed):
        mock_embed.return_value = [0.1] * 768
        self.client.force_authenticate(user=self.user1)

        payload = {
            'content': 'Quadratic formulas and roots definition.',
            'topic': str(self.topic1.id)
        }
        response = self.client.post(self.create_url, payload)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        
        # Verify db record
        note = KnowledgeNote.objects.filter(user=self.user1, topic=self.topic1).first()
        self.assertIsNotNone(note)
        self.assertEqual(note.content, payload['content'])
        
        # Verify mock calls
        mock_embed.assert_called_once_with(payload['content'])
        mock_upsert.assert_called_once_with(note.id, mock_embed.return_value, {
            "user_id": str(self.user1.id),
            "topic_id": str(self.topic1.id),
        })

    def test_create_note_permission_denied(self):
        self.client.force_authenticate(user=self.user1)
        
        # user1 attempts to add a note to user2's topic
        payload = {
            'content': 'Unauthorized note content.',
            'topic': str(self.topic2.id)
        }
        response = self.client.post(self.create_url, payload)
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        
        # Verify no note created in db
        self.assertFalse(KnowledgeNote.objects.filter(topic=self.topic2).exists())

    def test_create_note_missing_fields(self):
        self.client.force_authenticate(user=self.user1)
        
        # Missing content
        response = self.client.post(self.create_url, {'topic': str(self.topic1.id)})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

        # Missing topic
        response = self.client.post(self.create_url, {'content': 'some content'})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
