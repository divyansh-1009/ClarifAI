from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import AllowAny
from django.shortcuts import render
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
import google.generativeai as genai
import json
import os

def get_assessment_from_gemini(name, class_name, subject, topic, difficulty):
    genai.configure(api_key=os.getenv('GOOGLE_API_KEY'))
    
    model = genai.GenerativeModel(
        'gemini-2.5-flash'
    )
    
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
- CRITICAL: You must double-escape all LaTeX backslashes so the output remains valid JSON. For example, output \\\\frac{{1}}{{2}} instead of \\frac{{1}}{{2}}.

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
    assessment_json = response.text
    
    return assessment_json


class GenerateLatexView(APIView):
    permission_classes = [AllowAny]  # Allow unauthenticated access for testing
    
    def post(self, request):
        name = request.data.get('name')
        class_name = request.data.get('class')
        subject = request.data.get('subject')
        topic = request.data.get('topic')
        difficulty = request.data.get('difficulty')
        
        if not all([name, class_name, subject, topic]):
            return Response({
                'success': False,
                'error': 'All fields are required: name, class, subject, topic'
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


@method_decorator(csrf_exempt, name='dispatch')
class RenderAssessmentView(APIView):
    permission_classes = [AllowAny]
    
    def post(self, request):
        name = request.data.get('name')
        class_name = request.data.get('class')
        subject = request.data.get('subject')
        topic = request.data.get('topic')
        difficulty = request.data.get('difficulty', 'medium')
        
        if not all([name, class_name, subject, topic]):
            return render(request, 'assessment/error.html', {
                'error': 'All fields are required: name, class, subject, topic'
            })
        
        try:
            # Get assessment JSON from Gemini
            assessment_json_str = get_assessment_from_gemini(name, class_name, subject, topic, difficulty)
            
            # Clean up markdown code blocks if present
            if assessment_json_str.startswith('```json'):
                assessment_json_str = assessment_json_str.replace('```json', '').replace('```', '').strip()
            elif assessment_json_str.startswith('```'):
                assessment_json_str = assessment_json_str.replace('```', '').strip()
            
            # Parse JSON
            assessment_data = json.loads(assessment_json_str)
            
            # Prepare context for template
            context = {
                'student_name': name,
                'class_name': class_name,
                'subject': subject,
                'topic': topic,
                'difficulty': difficulty,
                'metadata': assessment_data.get('metadata', {}),
                'questions': assessment_data.get('questions', []),
            }
            
            return render(request, 'assessment/test_paper.html', context)
                
        except json.JSONDecodeError as e:
            return render(request, 'assessment/error.html', {
                'error': f'Invalid JSON response: {str(e)}',
                'raw_data': assessment_json_str
            })
        except Exception as e:
            return render(request, 'assessment/error.html', {
                'error': str(e)
            })