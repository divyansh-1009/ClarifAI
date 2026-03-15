from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.renderers import TemplateHTMLRenderer
import google.generativeai as genai
from google.api_core import exceptions as google_exceptions
import os
import json
import re


def get_assessment_from_gemini(name, class_name, subject, topic, difficulty):
    api_key = os.getenv("GOOGLE_API_KEY")
    if not api_key:
        raise ValueError("GOOGLE_API_KEY is not configured.")

    genai.configure(api_key=api_key)
    model_name = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
    model = genai.GenerativeModel(model_name)
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
    return response.text or ""


def parse_assessment_json(raw_text):
    if not raw_text or not raw_text.strip():
        raise ValueError("AI returned an empty response.")

    text = raw_text.strip()

    fence_match = re.search(
        r"```(?:json)?\s*(.*?)\s*```", text, flags=re.DOTALL | re.IGNORECASE
    )
    if fence_match:
        text = fence_match.group(1).strip()

    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        start = text.find("{")
        end = text.rfind("}")
        if start == -1 or end == -1 or end <= start:
            raise ValueError("AI returned invalid JSON.")
        try:
            parsed = json.loads(text[start : end + 1])
        except json.JSONDecodeError as exc:
            raise ValueError(f"AI returned invalid JSON: {str(exc)}")

    if not isinstance(parsed, dict):
        raise ValueError("Assessment JSON must be an object.")

    metadata = parsed.get("metadata")
    questions = parsed.get("questions")

    if not isinstance(metadata, dict):
        raise ValueError("Assessment metadata is missing or invalid.")
    if not isinstance(questions, list) or not questions:
        raise ValueError("Assessment questions are missing or empty.")

    return parsed


class GenerateAssessmentFromTopicView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        name = user.username
        class_name = request.data.get("class_name", "Not specified")
        subject = (request.data.get("subject") or "").strip()
        topic = (request.data.get("topic") or "").strip()
        difficulty = (request.data.get("difficulty") or "medium").strip().lower()

        if not subject:
            return Response(
                {"success": False, "error": "Subject is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not topic:
            return Response(
                {"success": False, "error": "Topic is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if difficulty not in {"easy", "medium", "hard"}:
            return Response(
                {
                    "success": False,
                    "error": "Difficulty must be easy, medium, or hard.",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            assessment_raw = get_assessment_from_gemini(
                name, class_name, subject, topic, difficulty
            )
            assessment_data = parse_assessment_json(assessment_raw)
            return Response(
                {
                    "success": True,
                    "assessment_data": assessment_data,
                    "details": {
                        "name": name,
                        "class": class_name,
                        "subject": subject,
                        "topic": topic,
                        "difficulty": difficulty,
                    },
                },
                status=status.HTTP_200_OK,
            )
        except google_exceptions.ResourceExhausted:
            return Response(
                {
                    "success": False,
                    "error": "Gemini quota exceeded. Please wait a bit and try again, or upgrade API quota/billing.",
                },
                status=status.HTTP_429_TOO_MANY_REQUESTS,
            )
        except google_exceptions.PermissionDenied:
            return Response(
                {
                    "success": False,
                    "error": "Gemini API key is invalid or lacks permission.",
                },
                status=status.HTTP_502_BAD_GATEWAY,
            )
        except Exception as e:
            return Response(
                {"success": False, "error": str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )


class RenderAssessmentFromTopicView(APIView):
    permission_classes = [IsAuthenticated]
    renderer_classes = [TemplateHTMLRenderer]

    def get(self, request):
        user = request.user
        name = user.username
        class_name = request.GET.get("class_name", "Not specified")
        topic = (request.GET.get("topic") or "").strip()
        subject = (request.GET.get("subject") or "").strip()
        difficulty = (request.GET.get("difficulty") or "medium").strip().lower()

        if not subject:
            return Response(
                {"error": "Subject is required."},
                template_name="assessment/error.html",
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not topic:
            return Response(
                {"error": "Topic is required."},
                template_name="assessment/error.html",
                status=status.HTTP_400_BAD_REQUEST,
            )

        if difficulty not in {"easy", "medium", "hard"}:
            return Response(
                {"error": "Difficulty must be easy, medium, or hard."},
                template_name="assessment/error.html",
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            assessment_raw = get_assessment_from_gemini(
                name, class_name, subject, topic, difficulty
            )
            assessment_json = parse_assessment_json(assessment_raw)
            context = {
                "name": name,
                "class_name": class_name,
                "subject": subject,
                "topic": topic,
                "difficulty": difficulty,
                "metadata": assessment_json.get("metadata", {}),
                "questions": assessment_json.get("questions", []),
            }
            return Response(
                context,
                template_name="assessment/assessment_paper.html",
                status=status.HTTP_200_OK,
            )
        except Exception as e:
            return Response(
                {"error": str(e)},
                template_name="assessment/error.html",
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )
