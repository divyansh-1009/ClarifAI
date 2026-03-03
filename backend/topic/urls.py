from django.urls import path
from .views import TopicCreateView

urlpatterns = [
    path('create/', TopicCreateView.as_view(), name='topic-create'),
]
