class Assessment {
  final Metadata metadata;
  final List<Question> questions;

  const Assessment({required this.metadata, required this.questions});

  factory Assessment.fromJson(Map<String, dynamic> json) {
    return Assessment(
      metadata: Metadata.fromJson(json['metadata'] as Map<String, dynamic>),
      questions: (json['questions'] as List<dynamic>)
          .map((q) => Question.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'metadata': metadata.toJson(),
      'questions': questions.map((q) => q.toJson()).toList(),
    };
  }
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

class Metadata {
  final String title;
  final int totalMarks;
  final int estimatedTime;

  const Metadata({
    required this.title,
    required this.totalMarks,
    required this.estimatedTime,
  });

  factory Metadata.fromJson(Map<String, dynamic> json) {
    return Metadata(
      title: (json['title'] as String?) ?? 'Assessment',
      totalMarks: _toInt(json['total_marks']),
      estimatedTime: _toInt(json['estimated_time_minutes']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'total_marks': totalMarks,
      'estimated_time_minutes': estimatedTime,
    };
  }
}

enum QuestionType { multipleChoice, shortAnswer, problemSolving, unknown }

class Question {
  final QuestionType type;
  final int marks;
  final String questionText;
  final List<String>? options;
  final String? answerKey;

  const Question({
    required this.type,
    required this.marks,
    required this.questionText,
    this.options,
    this.answerKey,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    final rawType = (json['type'] as String?) ?? '';
    QuestionType type;
    switch (rawType) {
      case 'multiple_choice':
        type = QuestionType.multipleChoice;
        break;
      case 'short_answer':
        type = QuestionType.shortAnswer;
        break;
      case 'problem_solving':
        type = QuestionType.problemSolving;
        break;
      default:
        type = QuestionType.unknown;
    }

    final rawOptions = json['options'];
    List<String>? options;
    if (rawOptions != null && rawOptions is List && rawOptions.isNotEmpty) {
      options = rawOptions.map((e) => e.toString()).toList();
    }

    return Question(
      type: type,
      marks: _toInt(json['marks'], fallback: 1),
      questionText: (json['question_text'] as String?) ?? '',
      options: options,
      answerKey: json['answer_key'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'marks': marks,
      'question_text': questionText,
      'options': options,
      'answer_key': answerKey,
    };
  }

  bool get isMultipleChoice => type == QuestionType.multipleChoice;
}
