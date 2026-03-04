class TopicModel {
  final String id;
  final String className;
  final String topic;
  final DateTime createdAt;

  const TopicModel({
    required this.id,
    required this.className,
    required this.topic,
    required this.createdAt,
  });

  factory TopicModel.fromJson(Map<String, dynamic> json) {
    return TopicModel(
      id: json['id'] as String,
      className: json['class_name'] as String,
      topic: json['topic'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'class_name': className,
      'topic': topic,
      'created_at': createdAt.toIso8601String(),
    };
  }

  TopicModel copyWith({
    String? id,
    String? className,
    String? topic,
    DateTime? createdAt,
  }) {
    return TopicModel(
      id: id ?? this.id,
      className: className ?? this.className,
      topic: topic ?? this.topic,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'TopicModel(id: $id, className: $className, topic: $topic)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TopicModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
