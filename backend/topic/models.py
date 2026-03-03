import uuid
from django.db import models
from django.conf import settings

def pdf_upload_path(instance, filename):
    return f"topic_{instance.topic.id}/{filename}"

class Topic(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="topics")
    class_name = models.CharField(max_length=100)
    topic = models.CharField(max_length=255)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.class_name} - {self.topic} ({self.user.username})"

class PDF(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    topic = models.ForeignKey(Topic, on_delete=models.CASCADE, related_name="pdfs")
    file = models.FileField(upload_to=pdf_upload_path)
    is_generated = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"PDF for {self.topic} ({self.id})"
