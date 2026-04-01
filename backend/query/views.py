from rest_framework import generics, permissions, status
from rest_framework.response import Response
from .serializers import QueryRequestSerializer, QueryResponseSerializer
from knowledge.vector_utils import generate_embedding, query_similar_notes
from topic.models import Topic
from knowledge.models import KnowledgeNote
import os
import google.generativeai as genai

class QueryView(generics.GenericAPIView):
	serializer_class = QueryRequestSerializer
	permission_classes = [permissions.IsAuthenticated]

	def post(self, request, *args, **kwargs):
		serializer = self.get_serializer(data=request.data)
		serializer.is_valid(raise_exception=True)
		question = serializer.validated_data['question']
		topic_id = serializer.validated_data['topic']
		user = request.user

		try:
			topic = Topic.objects.get(id=topic_id, user=user)
		except Topic.DoesNotExist:
			return Response({'detail': 'Invalid topic.'}, status=status.HTTP_403_FORBIDDEN)

		context_texts = []
		used_rag = False

		try:
			embedding = generate_embedding(question)
			filter_dict = {"user_id": str(user.id), "topic_id": str(topic.id)}
			matches = query_similar_notes(embedding, top_k=5, filter_dict=filter_dict)
			
			if matches and len(matches) > 0:
				note_ids = [match['id'] for match in matches]
				notes = KnowledgeNote.objects.filter(id__in=note_ids)
				context_texts = [note.content for note in notes]
				used_rag = True
		except Exception as e:
			context_texts = []

		gemini_api_key = os.getenv('GOOGLE_API_KEY')
		if not gemini_api_key:
			return Response(
				{'detail': 'GOOGLE_API_KEY is not configured.'},
				status=status.HTTP_500_INTERNAL_SERVER_ERROR,
			)

		genai.configure(api_key=gemini_api_key)
		model_name = os.getenv('GEMINI_MODEL', 'gemini-2.5-flash')
		model = genai.GenerativeModel(model_name)

		if context_texts:
			prompt = f"Context: {' '.join(context_texts)}\n\nQuestion: {question}\n\nAnswer:"
		else:
			prompt = f"Question: {question}\n\nAnswer:"

		try:
			response = model.generate_content(prompt)
			answer = response.text.strip() if hasattr(response, 'text') and response.text else str(response)
		except Exception as e:
			return Response(
				{'detail': f'AI generation failed: {str(e)}'},
				status=status.HTTP_502_BAD_GATEWAY,
			)

		return Response(QueryResponseSerializer({
			'answer': answer,
			'context': context_texts,
			'used_rag': used_rag
		}).data)

