import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/query_model.dart';
import '../models/topic_model.dart';
import '../services/api_service.dart';
import '../widgets/app_theme.dart';
import '../widgets/common_widgets.dart';

// ─────────────────────────────────────────────
//  Query Page
// ─────────────────────────────────────────────

class QueryPage extends StatefulWidget {
  final TopicModel? selectedTopic;

  const QueryPage({super.key, this.selectedTopic});

  @override
  State<QueryPage> createState() => _QueryPageState();
}

class _QueryPageState extends State<QueryPage>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  bool _isSending = false;
  int _messageIdCounter = 0;
  TopicModel? _activeTopic;

  // Greeting message shown when no messages yet
  static const String _greetingText =
      "Hi! I'm your ClarifAI assistant. Select a topic from the **Topics** tab, "
      "then ask me anything about it. I'll search your uploaded notes first "
      "and fall back to general knowledge when needed.";

  @override
  void initState() {
    super.initState();
    _activeTopic = widget.selectedTopic;
  }

  @override
  void didUpdateWidget(QueryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedTopic != oldWidget.selectedTopic) {
      _activeTopic = widget.selectedTopic;
      if (_activeTopic != null && _messages.isEmpty) {
        // Nothing to do — greeting handles it
      } else if (_activeTopic != null && _messages.isNotEmpty) {
        _injectSystemMessage(
          'Topic switched to **${_activeTopic!.topic}** (${_activeTopic!.className}). '
          'Your next question will be scoped to this topic.',
        );
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────

  String _nextId() => '${++_messageIdCounter}';

  void _injectSystemMessage(String content) {
    final msg = ChatMessage(
      id: _nextId(),
      content: content,
      sender: MessageSender.assistant,
      timestamp: DateTime.now(),
    );
    setState(() => _messages.add(msg));
    _scrollToBottom();
  }

  void _scrollToBottom({bool immediate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (immediate) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Send message ─────────────────────────────

  Future<void> _sendMessage() async {
    final question = _inputController.text.trim();
    if (question.isEmpty) return;
    if (_activeTopic == null) {
      _showNoTopicSnack();
      return;
    }
    if (_isSending) return;

    _inputController.clear();
    setState(() => _isSending = true);

    // Add user message
    final userMsg = ChatMessage.userMessage(
      id: _nextId(),
      content: question,
    );

    // Add loading placeholder
    final loadingId = _nextId();
    final loadingMsg = ChatMessage.loadingMessage(id: loadingId);

    setState(() {
      _messages.add(userMsg);
      _messages.add(loadingMsg);
    });
    _scrollToBottom();

    try {
      final responseId = _nextId();
      final response = await _api.askQuestion(
        question: question,
        topicId: _activeTopic!.id,
        messageId: responseId,
      );

      // Replace loading placeholder with real response
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == loadingId);
        if (idx != -1) {
          _messages[idx] = response;
        } else {
          _messages.add(response);
        }
      });
    } on UnauthorizedException {
      _replaceLoading(loadingId, '⚠️ Session expired. Please log in again.');
    } on ApiException catch (e) {
      _replaceLoading(loadingId, '⚠️ ${e.message}');
    } catch (_) {
      _replaceLoading(
        loadingId,
        '⚠️ Could not reach the server. Check your connection and try again.',
      );
    } finally {
      setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  void _replaceLoading(String loadingId, String errorText) {
    final idx = _messages.indexWhere((m) => m.id == loadingId);
    final errMsg = ChatMessage.assistantMessage(
      id: loadingId,
      content: errorText,
    );
    setState(() {
      if (idx != -1) {
        _messages[idx] = errMsg;
      } else {
        _messages.add(errMsg);
      }
    });
  }

  void _showNoTopicSnack() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                    'Please select a topic in the Topics tab before asking a question.'),
              ),
            ],
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  void _clearChat() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Remove all messages from this conversation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        setState(() => _messages.clear());
      }
    });
  }

  // ════════════════════════════════════════════
  //  Build
  // ════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Column(
      children: [
        // ── Topic selector bar ──────────────────
        _TopicBar(
          activeTopic: _activeTopic,
          isDark: isDark,
          messageCount: _messages.length,
          onClear: _messages.isNotEmpty ? _clearChat : null,
        ),

        // ── Message list ────────────────────────
        Expanded(
          child: _messages.isEmpty
              ? _buildGreeting(isDark)
              : _buildMessageList(isDark),
        ),

        // ── Input bar ───────────────────────────
        _InputBar(
          controller: _inputController,
          focusNode: _inputFocus,
          isSending: _isSending,
          isTopicSelected: _activeTopic != null,
          isDark: isDark,
          onSend: _sendMessage,
        ),
      ],
    );
  }

  // ── Greeting screen ──────────────────────────

  Widget _buildGreeting(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      children: [
        // AI avatar
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.heroGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withAlpha(77),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.psychology_rounded,
              size: 36,
              color: Colors.white,
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        Center(
          child: Text(
            'ClarifAI Assistant',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color:
                  isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Greeting bubble
        _AssistantBubble(
          message: ChatMessage.assistantMessage(
            id: '0',
            content: _greetingText,
          ),
          isDark: isDark,
          animate: true,
        ),

        const SizedBox(height: AppSpacing.lg),

        // Suggestion chips
        if (_activeTopic != null) ...[
          Text(
            'Try asking:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _buildSuggestions(_activeTopic!.topic),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildSuggestions(String topicName) {
    final suggestions = [
      'What is the main concept of $topicName?',
      'Summarise the key points of $topicName.',
      'Give me an example related to $topicName.',
      'What are common mistakes in $topicName?',
    ];
    return suggestions
        .map((s) => _SuggestionChip(
              label: s,
              onTap: () {
                _inputController.text = s;
                _inputFocus.requestFocus();
              },
            ))
        .toList();
  }

  // ── Message list ─────────────────────────────

  Widget _buildMessageList(bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isLast = index == _messages.length - 1;

        // Show date separator if new day
        final showDateSep = index == 0 ||
            !_isSameDay(
              _messages[index - 1].timestamp,
              message.timestamp,
            );

        return Column(
          children: [
            if (showDateSep)
              _DateSeparator(date: message.timestamp, isDark: isDark),
            if (message.isUser)
              _UserBubble(message: message, isDark: isDark, animate: isLast)
            else if (message.isLoading)
              _TypingIndicator(isDark: isDark)
            else
              _AssistantBubble(
                message: message,
                isDark: isDark,
                animate: isLast,
              ),
          ],
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

// ════════════════════════════════════════════
//  Topic Bar
// ════════════════════════════════════════════

class _TopicBar extends StatelessWidget {
  final TopicModel? activeTopic;
  final bool isDark;
  final int messageCount;
  final VoidCallback? onClear;

  const _TopicBar({
    required this.activeTopic,
    required this.isDark,
    required this.messageCount,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.darkSurface : AppColors.surface;
    final border = isDark ? const Color(0xFF353850) : const Color(0xFFEEEFF8);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          bottom: BorderSide(color: border, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          // Topic info
          Expanded(
            child: activeTopic == null
                ? Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'No topic selected — go to Topics tab',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.warning,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: AppColors.primaryGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.topic_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activeTopic!.topic,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              activeTopic!.className,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),

          // Clear button
          if (onClear != null) ...[
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              onPressed: onClear,
              icon: Icon(
                Icons.delete_sweep_outlined,
                size: 20,
                color:
                    isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
              tooltip: 'Clear chat',
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                minimumSize: const Size(36, 36),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
//  User Bubble
// ════════════════════════════════════════════

class _UserBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isDark;
  final bool animate;

  const _UserBubble({
    required this.message,
    required this.isDark,
    required this.animate,
  });

  @override
  State<_UserBubble> createState() => _UserBubbleState();
}

class _UserBubbleState extends State<_UserBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0.1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    if (widget.animate) {
      _ctrl.forward();
    } else {
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Timestamp
              Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 2),
                child: Text(
                  _formatTime(widget.message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: widget.isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textHint,
                  ),
                ),
              ),
              // Bubble
              Flexible(
                child: GestureDetector(
                  onLongPress: () =>
                      _copyToClipboard(context, widget.message.content),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.72,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.primaryGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withAlpha(51),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.message.content,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

// ════════════════════════════════════════════
//  Assistant Bubble
// ════════════════════════════════════════════

class _AssistantBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isDark;
  final bool animate;

  const _AssistantBubble({
    required this.message,
    required this.isDark,
    required this.animate,
  });

  @override
  State<_AssistantBubble> createState() => _AssistantBubbleState();
}

class _AssistantBubbleState extends State<_AssistantBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  bool _showContext = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(-0.1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    if (widget.animate) {
      _ctrl.forward();
    } else {
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final msg = widget.message;
    final bubbleColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final borderColor =
        isDark ? const Color(0xFF353850) : const Color(0xFFEEEFF8);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // AI avatar
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 2),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.heroGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.psychology_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),

              // Bubble
              Flexible(
                child: GestureDetector(
                  onLongPress: () =>
                      _copyToClipboard(context, msg.content),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(4),
                        bottomRight: Radius.circular(16),
                      ),
                      border: Border.all(color: borderColor, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withAlpha(38)
                              : const Color(0x0A5C6BC0),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── RAG badge row ────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 10, 0),
                          child: Row(
                            children: [
                              StatusBadge.rag(usedRag: msg.usedRag),
                              const Spacer(),
                              // Timestamp
                              Text(
                                _formatTime(msg.timestamp),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.textHint,
                                ),
                              ),
                              const SizedBox(width: 4),
                              // Copy icon
                              GestureDetector(
                                onTap: () =>
                                    _copyToClipboard(context, msg.content),
                                child: Icon(
                                  Icons.copy_outlined,
                                  size: 14,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.textHint,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ── Answer (Markdown) ────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                          child: MarkdownBody(
                            data: msg.content,
                            styleSheet: _buildMdStyle(context, isDark),
                            softLineBreak: true,
                            shrinkWrap: true,
                          ),
                        ),

                        // ── Context toggle ───────────────────
                        if (msg.usedRag && msg.context.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Divider(
                            height: 1,
                            color: borderColor,
                            indent: 14,
                            endIndent: 14,
                          ),
                          InkWell(
                            onTap: () =>
                                setState(() => _showContext = !_showContext),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(4),
                              bottomRight: Radius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                              child: Row(
                                children: [
                                  Icon(
                                    _showContext
                                        ? Icons.expand_less_rounded
                                        : Icons.expand_more_rounded,
                                    size: 16,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _showContext
                                        ? 'Hide source context'
                                        : 'Show source context (${msg.context.length})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Context snippets
                          AnimatedSize(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOut,
                            child: _showContext
                                ? _ContextSection(
                                    contexts: msg.context,
                                    isDark: isDark,
                                    borderColor: borderColor,
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ] else ...[
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  MarkdownStyleSheet _buildMdStyle(BuildContext context, bool isDark) {
    final baseColor =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final codeBg =
        isDark ? AppColors.darkSurfaceVariant : const Color(0xFFF0F2FA);

    return MarkdownStyleSheet(
      p: TextStyle(
        fontSize: 14,
        height: 1.6,
        color: baseColor,
        fontWeight: FontWeight.w400,
      ),
      h1: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: baseColor,
        height: 1.4,
      ),
      h2: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: baseColor,
        height: 1.4,
      ),
      h3: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: baseColor,
        height: 1.4,
      ),
      strong: TextStyle(
        fontWeight: FontWeight.w700,
        color: baseColor,
      ),
      em: TextStyle(
        fontStyle: FontStyle.italic,
        color: baseColor,
      ),
      code: TextStyle(
        fontSize: 13,
        fontFamily: 'monospace',
        color: isDark ? AppColors.primaryLight : AppColors.primary,
        backgroundColor: codeBg,
      ),
      codeblockDecoration: BoxDecoration(
        color: codeBg,
        borderRadius: BorderRadius.circular(8),
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: AppColors.primary, width: 3),
        ),
        color: AppColors.primary.withAlpha(13),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      listBullet: TextStyle(color: secondaryColor, fontSize: 14),
      tableHead: TextStyle(
        fontWeight: FontWeight.w700,
        color: baseColor,
        fontSize: 13,
      ),
      tableBody: TextStyle(color: baseColor, fontSize: 13),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF353850) : const Color(0xFFEEEFF8),
            width: 1,
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Context Section
// ─────────────────────────────────────────────

class _ContextSection extends StatelessWidget {
  final List<String> contexts;
  final bool isDark;
  final Color borderColor;

  const _ContextSection({
    required this.contexts,
    required this.isDark,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceVariant.withAlpha(128)
            : AppColors.surfaceVariant.withAlpha(128),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(16),
        ),
        border: Border(
          top: BorderSide(color: borderColor, width: 1),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.source_outlined,
                size: 13,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                'Source context from your notes',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...contexts.asMap().entries.map((entry) {
            final idx = entry.key;
            final snippet = entry.value;
            final displayText = snippet.length > 200
                ? '${snippet.substring(0, 200)}…'
                : snippet;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Snippet ${idx + 1}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.primaryLight
                            : AppColors.primary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      displayText,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
//  Typing Indicator
// ════════════════════════════════════════════

class _TypingIndicator extends StatefulWidget {
  final bool isDark;
  const _TypingIndicator({required this.isDark});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
    );
    _animations = _controllers
        .map((c) => Tween<double>(begin: 0, end: -6).animate(
              CurvedAnimation(parent: c, curve: Curves.easeInOut),
            ))
        .toList();

    _startAnimation();
  }

  void _startAnimation() async {
    for (int i = 0; i < _controllers.length; i++) {
      await Future.delayed(Duration(milliseconds: i * 150));
      if (mounted) {
        _controllers[i].repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor =
        widget.isDark ? AppColors.darkSurface : AppColors.surface;
    final borderColor = widget.isDark
        ? const Color(0xFF353850)
        : const Color(0xFFEEEFF8);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 2),
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.heroGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.psychology_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: _animations[i],
                  builder: (context, _) {
                    return Transform.translate(
                      offset: Offset(0, _animations[i].value),
                      child: Container(
                        width: 7,
                        height: 7,
                        margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                        decoration: BoxDecoration(
                          color: widget.isDark
                              ? AppColors.primaryLight
                              : AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
//  Date Separator
// ════════════════════════════════════════════

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  final bool isDark;

  const _DateSeparator({required this.date, required this.isDark});

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(msgDay).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: isDark
                  ? const Color(0xFF353850)
                  : const Color(0xFFEEEFF8),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              _label(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: isDark
                  ? const Color(0xFF353850)
                  : const Color(0xFFEEEFF8),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
//  Input Bar
// ════════════════════════════════════════════

class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final bool isTopicSelected;
  final bool isDark;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.isTopicSelected,
    required this.isDark,
    required this.onSend,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? AppColors.darkSurface : AppColors.surface;
    final borderColor = isDark
        ? const Color(0xFF353850)
        : const Color(0xFFEEEFF8);
    final inputBg =
        isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(color: borderColor, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withAlpha(51)
                : const Color(0x0F5C6BC0),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Text field
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                enabled: !widget.isSending,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: widget.isTopicSelected
                      ? 'Ask anything about this topic…'
                      : 'Select a topic first…',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textHint,
                  ),
                  filled: true,
                  fillColor: inputBg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
                onSubmitted: (_) {
                  if (_hasText && !widget.isSending) widget.onSend();
                },
              ),
            ),
          ),

          const SizedBox(width: AppSpacing.sm),

          // Send button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: (_hasText && !widget.isSending)
                  ? const LinearGradient(
                      colors: AppColors.primaryGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: (!_hasText || widget.isSending)
                  ? (isDark
                      ? AppColors.darkSurfaceVariant
                      : AppColors.surfaceVariant)
                  : null,
              shape: BoxShape.circle,
              boxShadow: (_hasText && !widget.isSending)
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(77),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: (_hasText && !widget.isSending) ? widget.onSend : null,
                child: widget.isSending
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.send_rounded,
                        size: 20,
                        color: _hasText
                            ? Colors.white
                            : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
//  Suggestion Chip
// ════════════════════════════════════════════

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.primary.withAlpha(38)
              : AppColors.primary.withAlpha(13),
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
          border: Border.all(
            color: AppColors.primary.withAlpha(51),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.primaryLight : AppColors.primary,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
//  Shared helpers
// ════════════════════════════════════════════

String _formatTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
