from django.urls import path
from .views import GenerateLatexView, RenderAssessmentView

urlpatterns = [
    path('generate-json/', GenerateLatexView.as_view(), name='generate-json'),
    path('render/', RenderAssessmentView.as_view(), name='render-assessment'),
]