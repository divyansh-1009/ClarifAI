from rest_framework import serializers
from .models import Topic, PDF

class PDFSerializer(serializers.ModelSerializer):
    class Meta:
        model = PDF
        fields = ['id', 'file', 'is_generated', 'created_at']

class TopicSerializer(serializers.ModelSerializer):
    pdfs = PDFSerializer(many=True, read_only=True)
    class Meta:
        model = Topic
        fields = ['id', 'user', 'class_name', 'topic', 'created_at', 'pdfs']
        read_only_fields = ['user', 'created_at', 'pdfs']
