from rest_framework import serializers
from .models import KnowledgeNote

class KnowledgeNoteSerializer(serializers.ModelSerializer):
    class Meta:
        model = KnowledgeNote
        fields = ['id', 'topic', 'user', 'content', 'created_at']
        read_only_fields = ['id', 'created_at', 'user']
