from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.renderers import TemplateHTMLRenderer
from django.shortcuts import render
import google.generativeai as genai
import os
import json
from topic.models import Topic


def get_assessment_from_gemini(name, class_name, subject, topic, difficulty):
    genai.configure(api_key=os.getenv('GOOGLE_API_KEY'))
    model = genai.GenerativeModel('gemini-2.5-flash')
    prompt = f"""You are an expert academic assessment generator for the Indian school and college curriculum.
Generate a highly structured assessment with the following parameters:

Student Name: {name}
Class: {class_name}
Subject: {subject}
Topic: {topic}
Difficulty: {difficulty}

CONTENT RULES:
- Generate between 5-10 questions based on difficulty (5 for easy, 7 for medium, 10 for hard).
- Include a mix of question types (multiple_choice, short_answer, problem_solving etc..).
- Ensure questions are perfectly aligned with the Indian curriculum for the specified class.

MATH AND FORMATTING RULES:
- Write all text in standard Markdown.
- Wrap all inline math equations in single dollar signs (e.g., $x^2 + y^2 = z^2$).
- Wrap all block/display math equations in double dollar signs (e.g., $$E=mc^2$$).
- CRITICAL: The output must remain a valid JSON. For example, output \\\\frac{{1}}{{2}} instead of \\frac{{1}}{{2}}.

OUTPUT FORMAT:
Return ONLY a valid, minified JSON object. Do not include markdown code blocks (like ```json), explanations, or any other text.
Follow this exact JSON schema:
{{
    "metadata": {{
        "title": "...",
        "total_marks": ...,
        "estimated_time_minutes": ...
    }},
    "questions": [
        {{
            "type": "multiple_choice | short_answer | problem_solving",
            "marks": ...,
            "question_text": "...",
            "options": ["...", "...", "...", "..."], // Only include if type is multiple_choice. Otherwise, null or empty array.
            "answer_key": "..." // Optional: Good to have if you plan to generate an answer sheet later.
        }}
    ]
}}
"""
    response = model.generate_content(prompt)
    return response.text


class GenerateAssessmentFromTopicView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        topic_obj = Topic.objects.filter(user=user).order_by('-created_at').first()
        if not topic_obj:
            return Response({
                'success': False,
                'error': 'No topic found for this user.'
            }, status=status.HTTP_404_NOT_FOUND)

        name = user.username
        class_name = topic_obj.class_name
        topic = topic_obj.topic
        subject = request.data.get('subject')
        difficulty = request.data.get('difficulty', 'medium')

        if not subject:
            return Response({
                'success': False,
                'error': 'Subject is required.'
            }, status=status.HTTP_400_BAD_REQUEST)

        try:
            assessment_data = get_assessment_from_gemini(name, class_name, subject, topic, difficulty)
            return Response({
                'success': True,
                'assessment_data': assessment_data,
                'details': {
                    'name': name,
                    'class': class_name,
                    'subject': subject,
                    'topic': topic,
                    'difficulty': difficulty
                }
            }, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({
                'success': False,
                'error': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class RenderAssessmentFromTopicView(APIView):
    permission_classes = [IsAuthenticated]
    renderer_classes = [TemplateHTMLRenderer]

    def get(self, request):
        user = request.user
        topic_obj = Topic.objects.filter(user=user).order_by('-created_at').first()
        if not topic_obj:
            return Response({'error': 'No topic found for this user.'}, template_name='assessment/error.html', status=status.HTTP_404_NOT_FOUND)

        name = user.username
        class_name = topic_obj.class_name
        topic = topic_obj.topic
        subject = request.GET.get('subject')
        difficulty = request.GET.get('difficulty', 'medium')

        if not subject:
            return Response({'error': 'Subject is required.'}, template_name='assessment/error.html', status=status.HTTP_400_BAD_REQUEST)

        try:
            assessment_data = get_assessment_from_gemini(name, class_name, subject, topic, difficulty)
            assessment_json = json.loads(assessment_data)
            context = {
                'name': name,
                'class_name': class_name,
                'subject': subject,
                'topic': topic,
                'difficulty': difficulty,
                'metadata': assessment_json.get('metadata', {}),
                'questions': assessment_json.get('questions', []),
            }
            return Response(context, template_name='assessment/assessment_paper.html', status=status.HTTP_200_OK)
        except Exception as e:
            return Response({'error': str(e)}, template_name='assessment/error.html', status=status.HTTP_500_INTERNAL_SERVER_ERROR)