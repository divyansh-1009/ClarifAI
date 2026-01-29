from django.contrib import admin
from django.urls import include, path

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/accounts/', include('accounts.urls')),
    path('api/topic/', include('topic.urls')),
    path('api/assessment/', include('assessment.urls')),
]
