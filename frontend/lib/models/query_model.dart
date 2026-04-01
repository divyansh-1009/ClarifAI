enum MessageSender { user, assistant }

class ChatMessage {
  final String id;
  final String content;
  final MessageSender sender;
  final DateTime timestamp;
  final bool usedRag;
  final List<String> context;
  final bool isLoading;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.sender,
    required this.timestamp,
    this.usedRag = false,
    this.context = const [],
    this.isLoading = false,
  });

  factory ChatMessage.userMessage({
    required String id,
    required String content,
  }) {
    return ChatMessage(
      id: id,
      content: content,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );
  }

  factory ChatMessage.loadingMessage({required String id}) {
    return ChatMessage(
      id: id,
      content: '',
      sender: MessageSender.assistant,
      timestamp: DateTime.now(),
      isLoading: true,
    );
  }

  factory ChatMessage.assistantMessage({
    required String id,
    required String content,
    bool usedRag = false,
    List<String> context = const [],
  }) {
    return ChatMessage(
      id: id,
      content: content,
      sender: MessageSender.assistant,
      timestamp: DateTime.now(),
      usedRag: usedRag,
      context: context,
    );
  }

  factory ChatMessage.fromQueryResponse({
    required String id,
    required Map<String, dynamic> json,
  }) {
    final rawContext = json['context'];
    List<String> contextList = [];
    if (rawContext != null && rawContext is List) {
      contextList = rawContext.map((e) => e.toString()).toList();
    }

    return ChatMessage(
      id: id,
      content: (json['answer'] as String?) ?? '',
      sender: MessageSender.assistant,
      timestamp: DateTime.now(),
      usedRag: (json['used_rag'] as bool?) ?? false,
      context: contextList,
    );
  }

  ChatMessage copyWith({
    String? id,
    String? content,
    MessageSender? sender,
    DateTime? timestamp,
    bool? usedRag,
    List<String>? context,
    bool? isLoading,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      sender: sender ?? this.sender,
      timestamp: timestamp ?? this.timestamp,
      usedRag: usedRag ?? this.usedRag,
      context: context ?? this.context,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  bool get isUser => sender == MessageSender.user;
  bool get isAssistant => sender == MessageSender.assistant;

  @override
  String toString() =>
      'ChatMessage(id: $id, sender: $sender, content: ${content.length > 30 ? '${content.substring(0, 30)}...' : content})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
