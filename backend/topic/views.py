import os
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser
from .models import Topic, PDF
from .serializers import TopicSerializer
from .vector_service import generate_and_store_embedding
from PyPDF2 import PdfReader


def store_vector_embedding(pdf_obj, text):
    embedding_id = generate_and_store_embedding(pdf_obj, text)
    pdf_obj.embedding_id = embedding_id
    pdf_obj.is_processed = True
    pdf_obj.save()


class TopicCreateView(generics.CreateAPIView):
    queryset = Topic.objects.all()
    serializer_class = TopicSerializer
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request, *args, **kwargs):
        class_name = request.data.get('class_name')
        topic = request.data.get('topic')
        notes = request.FILES.get('notes')
        user = request.user

        if not class_name or not topic:
            return Response({'error': 'class_name and topic are required.'}, status=status.HTTP_400_BAD_REQUEST)

        topic_obj = Topic.objects.create(user=user, class_name=class_name, topic=topic)

        if notes:
            if not notes.name.lower().endswith('.pdf'):
                topic_obj.delete()
                return Response({'error': 'Only PDF files are allowed for notes.'}, status=status.HTTP_400_BAD_REQUEST)
            pdf_obj = PDF.objects.create(topic=topic_obj)
            try:
                pdf_reader = PdfReader(notes)
                text = " ".join(page.extract_text() or '' for page in pdf_reader.pages)
                if text.strip():
                    store_vector_embedding(pdf_obj, text)
                else:
                    raise Exception("No text found in PDF")
            except Exception as e:
                topic_obj.delete()
                pdf_obj.delete()
                return Response({'error': f'Failed to process PDF and generate embedding: {str(e)}'}, status=status.HTTP_400_BAD_REQUEST)

        serializer = self.get_serializer(topic_obj)
        return Response(serializer.data, status=status.HTTP_201_CREATED)
