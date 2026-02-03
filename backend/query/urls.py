from django.urls import path
from .views import QueryView

urlpatterns = [
    path('ask/', QueryView.as_view(), name='query-ask'),
]
