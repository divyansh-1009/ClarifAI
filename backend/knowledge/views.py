
from rest_framework import generics, permissions
from .models import KnowledgeNote
from .serializers import KnowledgeNoteSerializer
from .vector_utils import generate_embedding
from topic.models import Topic

class KnowledgeNoteCreateView(generics.CreateAPIView):
	queryset = KnowledgeNote.objects.all()
	serializer_class = KnowledgeNoteSerializer
	permission_classes = [permissions.IsAuthenticated]

	def perform_create(self, serializer):
		content = self.request.data.get('content')
		topic_id = self.request.data.get('topic')
		try:
			topic = Topic.objects.get(id=topic_id, user=self.request.user)
		except Topic.DoesNotExist:
			from rest_framework.exceptions import PermissionDenied
			raise PermissionDenied("You do not have permission to add notes to this topic.")
		note = serializer.save(user=self.request.user, topic=topic)
		embedding = generate_embedding(content)
		from .vector_utils import upsert_note_vector
		upsert_note_vector(note.id, embedding, {
			"user_id": str(self.request.user.id),
			"topic_id": str(topic.id),
		})
