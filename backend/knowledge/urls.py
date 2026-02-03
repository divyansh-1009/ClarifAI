from django.urls import path
from .views import KnowledgeNoteCreateView

urlpatterns = [
    path('create/', KnowledgeNoteCreateView.as_view(), name='knowledge-note-create'),
]
