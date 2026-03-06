from rest_framework import serializers

class QueryRequestSerializer(serializers.Serializer):
    question = serializers.CharField()
    topic = serializers.UUIDField()

class QueryResponseSerializer(serializers.Serializer):
    answer = serializers.CharField()
    context = serializers.ListField(child=serializers.CharField())
