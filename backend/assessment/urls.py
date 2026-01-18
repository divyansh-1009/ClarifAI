from django.urls import path
from .views import GenerateAssessmentFromTopicView, RenderAssessmentFromTopicView

urlpatterns = [
    path('generate-from-topic/', GenerateAssessmentFromTopicView.as_view(), name='generate-from-topic'),
    path('render-from-topic/', RenderAssessmentFromTopicView.as_view(), name='render-from-topic'),
]