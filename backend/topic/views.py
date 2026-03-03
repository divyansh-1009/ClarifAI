
import os
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser
from .models import Topic, PDF
from .serializers import TopicSerializer
from PyPDF2 import PdfReader

# Dummy vector DB function (replace with real implementation)
def store_vector_embedding(topic_id, text):
	# Here you would generate embeddings and store them in your vector DB
	# For now, just print as a placeholder
	print(f"Storing embedding for topic {topic_id}: {text[:100]}")

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
			# Only accept PDF files
			if not notes.name.lower().endswith('.pdf'):
				topic_obj.delete()
				return Response({'error': 'Only PDF files are allowed for notes.'}, status=status.HTTP_400_BAD_REQUEST)
			pdf_obj = PDF.objects.create(topic=topic_obj, file=notes)
			# Extract text from PDF
			try:
				pdf_reader = PdfReader(pdf_obj.file)
				text = " ".join(page.extract_text() or '' for page in pdf_reader.pages)
				if text.strip():
					store_vector_embedding(topic_obj.id, text)
			except Exception as e:
				topic_obj.delete()
				pdf_obj.delete()
				return Response({'error': f'Failed to extract text from PDF: {str(e)}'}, status=status.HTTP_400_BAD_REQUEST)

		serializer = self.get_serializer(topic_obj)
		return Response(serializer.data, status=status.HTTP_201_CREATED)
