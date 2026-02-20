class Assessment {
  final Metadata metadata;
  final List<Question> questions;

  Assessment({required this.metadata, required this.questions});

  factory Assessment.fromJson(Map<String, dynamic> json) {
    return Assessment(
      metadata: Metadata.fromJson(json['metadata']),
      questions: (json['questions'] as List)
          .map((q) => Question.fromJson(q))
          .toList(),
    );
  }
}

class Metadata {
  final String title;
  final int totalMarks;
  final int estimatedTime;

  Metadata({
    required this.title,
    required this.totalMarks,
    required this.estimatedTime,
  });

  factory Metadata.fromJson(Map<String, dynamic> json) {
    return Metadata(
      title: json['title'] ?? 'Assessment',
      totalMarks: json['total_marks'] ?? 0,
      estimatedTime: json['estimated_time_minutes'] ?? 0,
    );
  }
}

class Question {
  final String type;
  final int marks;
  final String questionText;
  final List<String>? options;
  final String? answerKey;

  Question({
    required this.type,
    required this.marks,
    required this.questionText,
    this.options,
    this.answerKey,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      type: json['type'],
      marks: json['marks'],
      questionText: json['question_text'],
      options: json['options'] != null ? List<String>.from(json['options']) : null,
      answerKey: json['answer_key'],
    );
  }
}
