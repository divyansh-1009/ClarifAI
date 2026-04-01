import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/assessment_model.dart';
import '../widgets/app_theme.dart';
import '../widgets/common_widgets.dart';

// ═════════════════════════════════════════════
//  QuizPage — entry point
// ═════════════════════════════════════════════

class QuizPage extends StatefulWidget {
  final Assessment assessment;
  final String subject;
  final String topic;
  final String difficulty;

  const QuizPage({
    super.key,
    required this.assessment,
    required this.subject,
    required this.topic,
    required this.difficulty,
  });

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> with TickerProviderStateMixin {
  // ── Page controller ──────────────────────────
  final PageController _pageController = PageController();

  // ── State ────────────────────────────────────
  int _currentIndex = 0;
  final Map<int, String> _userAnswers = {};
  bool _quizFinished = false;

  // ── Timer ────────────────────────────────────
  late AnimationController _timerController;
  static const int _totalSeconds = 0; // 0 = no hard limit; kept for future use

  // ── Progress animation ────────────────────────
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  // ── Entry animation ───────────────────────────
  late AnimationController _entryController;
  late Animation<double> _entryFade;
  late Animation<Offset> _entrySlide;

  // ── Question transition ───────────────────────
  late AnimationController _questionController;
  late Animation<double> _questionFade;
  late Animation<Offset> _questionSlide;

  @override
  void initState() {
    super.initState();

    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _progressAnimation = Tween<double>(
      begin: 0,
      end: 1 / widget.assessment.questions.length,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOut,
    ));
    _progressController.forward();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _entryFade =
        CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _entryController, curve: Curves.easeOut));
    _entryController.forward();

    _questionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _questionFade = CurvedAnimation(
      parent: _questionController,
      curve: Curves.easeOut,
    );
    _questionSlide = Tween<Offset>(
      begin: const Offset(0.08, 0),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _questionController, curve: Curves.easeOut));
    _questionController.value = 1.0; // Start fully visible
  }

  @override
  void dispose() {
    _pageController.dispose();
    _timerController.dispose();
    _progressController.dispose();
    _entryController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════
  //  Helpers
  // ════════════════════════════════════════════

  int get _totalQuestions => widget.assessment.questions.length;
  bool get _isLastQuestion => _currentIndex == _totalQuestions - 1;
  bool get _currentAnswered => _userAnswers.containsKey(_currentIndex);

  double _calcScore() {
    double score = 0;
    for (int i = 0; i < _totalQuestions; i++) {
      final q = widget.assessment.questions[i];
      final ans = _userAnswers[i];
      if (ans == null) continue;
      if (q.isMultipleChoice) {
        if (ans.trim().toLowerCase() ==
            (q.answerKey ?? '').trim().toLowerCase()) {
          score += q.marks;
        }
      } else {
        // Partial credit for free-text: award marks if answered
        if (ans.trim().isNotEmpty) score += q.marks;
      }
    }
    return score;
  }

  int get _totalMarks => widget.assessment.metadata.totalMarks;

  // ── Navigation ───────────────────────────────

  void _goToQuestion(int index) {
    if (index < 0 || index >= _totalQuestions) return;
    _questionController.reset();
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
    _progressController.animateTo(
      (index + 1) / _totalQuestions,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
    _questionController.forward();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  void _next() {
    if (_isLastQuestion) {
      _finishQuiz();
    } else {
      _goToQuestion(_currentIndex + 1);
    }
  }

  void _previous() {
    if (_currentIndex > 0) {
      _goToQuestion(_currentIndex - 1);
    }
  }

  void _finishQuiz() {
    // Confirm if unanswered questions remain
    final unanswered = _totalQuestions - _userAnswers.length;
    if (unanswered > 0) {
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Submit Quiz?'),
          content: Text(
            '$unanswered question${unanswered == 1 ? '' : 's'} '
            '${unanswered == 1 ? 'is' : 'are'} unanswered. '
            'You can still submit — unanswered questions will score 0.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Review'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
              ),
              child: const Text('Submit'),
            ),
          ],
        ),
      ).then((confirmed) {
        if (confirmed == true) {
          setState(() => _quizFinished = true);
        }
      });
    } else {
      setState(() => _quizFinished = true);
    }
  }

  void _restartQuiz() {
    setState(() {
      _userAnswers.clear();
      _quizFinished = false;
      _currentIndex = 0;
    });
    _pageController.jumpToPage(0);
    _progressController.animateTo(
      1 / _totalQuestions,
      duration: const Duration(milliseconds: 300),
    );
  }

  // ════════════════════════════════════════════
  //  Build
  // ════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_quizFinished) {
      return _ResultsPage(
        assessment: widget.assessment,
        userAnswers: _userAnswers,
        score: _calcScore(),
        totalMarks: _totalMarks,
        subject: widget.subject,
        difficulty: widget.difficulty,
        onRestart: _restartQuiz,
        onExit: () => Navigator.of(context).pop(),
      );
    }

    return Scaffold(
      backgroundColor:
          context.isDark ? AppColors.darkBackground : AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _entryFade,
          child: SlideTransition(
            position: _entrySlide,
            child: Column(
              children: [
                // ── Top bar ──────────────────────────────
                _QuizTopBar(
                  currentIndex: _currentIndex,
                  totalQuestions: _totalQuestions,
                  progressAnimation: _progressAnimation,
                  progressController: _progressController,
                  subject: widget.subject,
                  topic: widget.topic,
                  difficulty: widget.difficulty,
                  answeredCount: _userAnswers.length,
                  isDark: context.isDark,
                  onExit: () => _showExitDialog(context),
                ),

                // ── Question pager ───────────────────────
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: _onPageChanged,
                    itemCount: _totalQuestions,
                    itemBuilder: (context, index) {
                      final question = widget.assessment.questions[index];
                      return FadeTransition(
                        opacity: _questionFade,
                        child: SlideTransition(
                          position: _questionSlide,
                          child: _QuestionCard(
                            question: question,
                            index: index,
                            total: _totalQuestions,
                            userAnswer: _userAnswers[index],
                            isDark: context.isDark,
                            onAnswerChanged: (ans) {
                              setState(() => _userAnswers[index] = ans);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // ── Bottom bar ───────────────────────────
                _QuizBottomBar(
                  currentIndex: _currentIndex,
                  totalQuestions: _totalQuestions,
                  isAnswered: _currentAnswered,
                  isLast: _isLastQuestion,
                  isDark: context.isDark,
                  onPrevious: _currentIndex > 0 ? _previous : null,
                  onNext: _next,
                  onSkip: _isLastQuestion
                      ? null
                      : () => _goToQuestion(_currentIndex + 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Exit dialog ──────────────────────────────

  void _showExitDialog(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit Quiz?'),
        content: const Text(
          'Your progress will be lost if you exit now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Exit'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        Navigator.of(context).pop();
      }
    });
  }
}

// ════════════════════════════════════════════
//  _QuizTopBar
// ════════════════════════════════════════════

class _QuizTopBar extends StatelessWidget {
  final int currentIndex;
  final int totalQuestions;
  final Animation<double> progressAnimation;
  final AnimationController progressController;
  final String subject;
  final String topic;
  final String difficulty;
  final int answeredCount;
  final bool isDark;
  final VoidCallback onExit;

  const _QuizTopBar({
    required this.currentIndex,
    required this.totalQuestions,
    required this.progressAnimation,
    required this.progressController,
    required this.subject,
    required this.topic,
    required this.difficulty,
    required this.answeredCount,
    required this.isDark,
    required this.onExit,
  });

  Color get _progressColor {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return AppColors.success;
      case 'hard':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.darkSurface : AppColors.surface;
    final border =
        isDark ? const Color(0xFF353850) : const Color(0xFFEEEFF8);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: border, width: 1)),
      ),
      child: Column(
        children: [
          // ── Header row ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                // Exit button
                IconButton(
                  onPressed: onExit,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Exit quiz',
                  visualDensity: VisualDensity.compact,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),

                const SizedBox(width: AppSpacing.xs),

                // Subject + question counter
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Question ${currentIndex + 1} of $totalQuestions  •  $answeredCount answered  •  $topic',
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

                // Difficulty badge
                StatusBadge.difficulty(difficulty),
              ],
            ),
          ),

          // ── Progress bar ─────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
            child: Column(
              children: [
                Row(
                  children: List.generate(totalQuestions, (i) {
                    final isAnswered = i < answeredCount;
                    final isCurrent = i == currentIndex;
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(
                            right: i < totalQuestions - 1 ? 2 : 0),
                        decoration: BoxDecoration(
                          color: isAnswered || isCurrent
                              ? _progressColor
                              : (isDark
                                  ? AppColors.darkSurfaceVariant
                                  : AppColors.surfaceVariant),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
//  _QuestionCard
// ════════════════════════════════════════════

class _QuestionCard extends StatelessWidget {
  final Question question;
  final int index;
  final int total;
  final String? userAnswer;
  final bool isDark;
  final ValueChanged<String> onAnswerChanged;

  const _QuestionCard({
    required this.question,
    required this.index,
    required this.total,
    required this.userAnswer,
    required this.isDark,
    required this.onAnswerChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Question type + marks row ────────────
          Row(
            children: [
              _QuestionTypeBadge(type: question.type),
              const Spacer(),
              _MarksBadge(marks: question.marks, isDark: isDark),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Question text ────────────────────────
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            border: Border.all(
              color: AppColors.primary.withAlpha(38),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withAlpha(13),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Q number indicator
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors.primaryGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Question ${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.sm),

                // Question markdown body
                MarkdownBody(
                  data: question.questionText,
                  shrinkWrap: true,
                  styleSheet: _questionMdStyle(context, isDark),
                  softLineBreak: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Answer section ───────────────────────
          if (question.isMultipleChoice && question.options != null) ...[
            _AnswerSectionLabel(
              label: 'Choose the correct answer',
              isDark: isDark,
            ),
            const SizedBox(height: AppSpacing.sm),
            _MCQOptions(
              options: question.options!,
              selected: userAnswer,
              isDark: isDark,
              onSelect: onAnswerChanged,
            ),
          ] else ...[
            _AnswerSectionLabel(
              label: question.type == QuestionType.problemSolving
                  ? 'Show your working & answer'
                  : 'Write your answer',
              isDark: isDark,
            ),
            const SizedBox(height: AppSpacing.sm),
            _FreeTextAnswer(
              initialValue: userAnswer,
              isDark: isDark,
              isProblemSolving: question.type == QuestionType.problemSolving,
              onChanged: onAnswerChanged,
            ),
          ],

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  MarkdownStyleSheet _questionMdStyle(BuildContext context, bool isDark) {
    final base =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    return MarkdownStyleSheet(
      p: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: base,
        height: 1.6,
      ),
      strong: TextStyle(fontWeight: FontWeight.w700, color: base),
      em: TextStyle(fontStyle: FontStyle.italic, color: base),
      code: TextStyle(
        fontSize: 14,
        fontFamily: 'monospace',
        color: isDark ? AppColors.primaryLight : AppColors.primary,
        backgroundColor:
            isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  _QuestionTypeBadge
// ─────────────────────────────────────────────

class _QuestionTypeBadge extends StatelessWidget {
  final QuestionType type;
  const _QuestionTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String label;
    BadgeVariant variant;

    switch (type) {
      case QuestionType.multipleChoice:
        icon = Icons.check_circle_outline_rounded;
        label = 'Multiple Choice';
        variant = BadgeVariant.primary;
        break;
      case QuestionType.shortAnswer:
        icon = Icons.short_text_rounded;
        label = 'Short Answer';
        variant = BadgeVariant.info;
        break;
      case QuestionType.problemSolving:
        icon = Icons.calculate_outlined;
        label = 'Problem Solving';
        variant = BadgeVariant.warning;
        break;
      default:
        icon = Icons.help_outline_rounded;
        label = 'Question';
        variant = BadgeVariant.neutral;
    }

    return StatusBadge(label: label, variant: variant, icon: icon);
  }
}

// ─────────────────────────────────────────────
//  _MarksBadge
// ─────────────────────────────────────────────

class _MarksBadge extends StatelessWidget {
  final int marks;
  final bool isDark;
  const _MarksBadge({required this.marks, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.primaryGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 12, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            '$marks mark${marks == 1 ? '' : 's'}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  _AnswerSectionLabel
// ─────────────────────────────────────────────

class _AnswerSectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  const _AnswerSectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.edit_outlined,
          size: 15,
          color: isDark
              ? AppColors.darkTextSecondary
              : AppColors.textSecondary,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  _MCQOptions
// ─────────────────────────────────────────────

class _MCQOptions extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final bool isDark;
  final ValueChanged<String> onSelect;

  const _MCQOptions({
    required this.options,
    required this.selected,
    required this.isDark,
    required this.onSelect,
  });

  static const _optionLabels = ['A', 'B', 'C', 'D', 'E', 'F'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(options.length, (i) {
        final opt = options[i];
        final isSelected = selected == opt;
        final label = i < _optionLabels.length ? _optionLabels[i] : '${i + 1}';

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _MCQOptionTile(
            label: label,
            text: opt,
            isSelected: isSelected,
            isDark: isDark,
            onTap: () => onSelect(opt),
          ),
        );
      }),
    );
  }
}

class _MCQOptionTile extends StatefulWidget {
  final String label;
  final String text;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _MCQOptionTile({
    required this.label,
    required this.text,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_MCQOptionTile> createState() => _MCQOptionTileState();
}

class _MCQOptionTileState extends State<_MCQOptionTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final isSelected = widget.isSelected;

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? AppColors.primary.withAlpha(38)
                    : AppColors.primary.withAlpha(20))
                : (isDark ? AppColors.darkSurface : AppColors.surface),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isDark
                      ? const Color(0xFF353850)
                      : const Color(0xFFEEEFF8)),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(38),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withAlpha(26)
                          : const Color(0x0A5C6BC0),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // Label badge
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark
                          ? AppColors.darkSurfaceVariant
                          : AppColors.surfaceVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 17,
                          color: Colors.white,
                          key: ValueKey('check'),
                        )
                      : Text(
                          widget.label,
                          key: ValueKey(widget.label),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                ),
              ),

              const SizedBox(width: AppSpacing.sm),

              // Option text
              Expanded(
                child: Text(
                  widget.text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? (isDark ? AppColors.primaryLight : AppColors.primary)
                        : (isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  _FreeTextAnswer
// ─────────────────────────────────────────────

class _FreeTextAnswer extends StatefulWidget {
  final String? initialValue;
  final bool isDark;
  final bool isProblemSolving;
  final ValueChanged<String> onChanged;

  const _FreeTextAnswer({
    required this.initialValue,
    required this.isDark,
    required this.isProblemSolving,
    required this.onChanged,
  });

  @override
  State<_FreeTextAnswer> createState() => _FreeTextAnswerState();
}

class _FreeTextAnswerState extends State<_FreeTextAnswer> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue ?? '');
    _ctrl.addListener(() => widget.onChanged(_ctrl.text));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final inputBg =
        isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant;
    final focusBorder = AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.isProblemSolving) ...[
          InfoBanner(
            message:
                'Show your full working. You will receive marks based on your approach.',
            variant: BadgeVariant.warning,
            icon: Icons.info_outline_rounded,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        TextField(
          controller: _ctrl,
          maxLines: widget.isProblemSolving ? 8 : 4,
          minLines: widget.isProblemSolving ? 5 : 3,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: widget.isProblemSolving
                ? 'Step 1: …\nStep 2: …\nAnswer: …'
                : 'Type your answer here…',
            hintStyle: TextStyle(
              fontSize: 13,
              color:
                  isDark ? AppColors.darkTextSecondary : AppColors.textHint,
            ),
            filled: true,
            fillColor: inputBg,
            contentPadding: const EdgeInsets.all(AppSpacing.md),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${_ctrl.text.length} characters',
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════
//  _QuizBottomBar
// ════════════════════════════════════════════

class _QuizBottomBar extends StatelessWidget {
  final int currentIndex;
  final int totalQuestions;
  final bool isAnswered;
  final bool isLast;
  final bool isDark;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onSkip;

  const _QuizBottomBar({
    required this.currentIndex,
    required this.totalQuestions,
    required this.isAnswered,
    required this.isLast,
    required this.isDark,
    required this.onPrevious,
    required this.onNext,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.darkSurface : AppColors.surface;
    final border =
        isDark ? const Color(0xFF353850) : const Color(0xFFEEEFF8);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border, width: 1)),
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
        AppSpacing.md,
        AppSpacing.sm + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        children: [
          // Back button
          if (onPrevious != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 0),
                  ),
                ),
              ),
            ),

          // Skip button (for non-last questions)
          if (!isLast && onSkip != null && !isAnswered)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: SizedBox(
                height: 48,
                child: TextButton(
                  onPressed: onSkip,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),

          // Next / Submit button
          Expanded(
            child: SizedBox(
              height: 48,
              child: GradientButton(
                label: isLast ? 'Submit Quiz' : 'Next Question',
                icon: isLast
                    ? Icons.check_circle_outline_rounded
                    : Icons.arrow_forward_rounded,
                onPressed: onNext,
                gradient: isLast
                    ? [AppColors.success, const Color(0xFF388E3C)]
                    : AppColors.primaryGradient,
                height: 48,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
//  _ResultsPage
// ════════════════════════════════════════════

class _ResultsPage extends StatefulWidget {
  final Assessment assessment;
  final Map<int, String> userAnswers;
  final double score;
  final int totalMarks;
  final String subject;
  final String difficulty;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  const _ResultsPage({
    required this.assessment,
    required this.userAnswers,
    required this.score,
    required this.totalMarks,
    required this.subject,
    required this.difficulty,
    required this.onRestart,
    required this.onExit,
  });

  @override
  State<_ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<_ResultsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;
  bool _showReview = false;

  double get _percentage =>
      widget.totalMarks == 0 ? 0 : (widget.score / widget.totalMarks) * 100;

  String get _grade {
    if (_percentage >= 90) return 'A+';
    if (_percentage >= 80) return 'A';
    if (_percentage >= 70) return 'B';
    if (_percentage >= 60) return 'C';
    if (_percentage >= 50) return 'D';
    return 'F';
  }

  String get _gradeMessage {
    if (_percentage >= 90) return 'Outstanding! 🏆';
    if (_percentage >= 80) return 'Excellent work! 🌟';
    if (_percentage >= 70) return 'Good job! 👍';
    if (_percentage >= 60) return 'Keep it up! 💪';
    if (_percentage >= 50) return 'Almost there! 📚';
    return 'Keep practising! 🔥';
  }

  List<Color> get _gradeGradient {
    if (_percentage >= 80) {
      return [const Color(0xFF66BB6A), const Color(0xFF43A047)];
    }
    if (_percentage >= 60) {
      return [const Color(0xFFFFA726), const Color(0xFFF57C00)];
    }
    return [AppColors.error, const Color(0xFFB71C1C)];
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            children: [
              // Top exit bar
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm, AppSpacing.sm, AppSpacing.md, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: widget.onExit,
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Exit',
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: widget.onRestart,
                      icon: const Icon(Icons.replay_rounded, size: 16),
                      label: const Text('Retake'),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark
                            ? AppColors.primaryLight
                            : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _showReview
                    ? _buildReviewList(isDark)
                    : _buildResultsContent(isDark),
              ),

              // Bottom actions
              _buildBottomActions(isDark),
            ],
          ),
        ),
      ),
    );
  }

  // ── Results content ──────────────────────────

  Widget _buildResultsContent(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      children: [
        // Score card
        ScaleTransition(
          scale: _scale,
          child: GradientCard(
            gradient: _gradeGradient,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Text(
                  _grade,
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _gradeMessage,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(38),
                    borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
                  ),
                  child: Text(
                    '${widget.score.toStringAsFixed(0)} / ${widget.totalMarks} marks  •  ${_percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Stats grid
        _buildStatsGrid(isDark),

        const SizedBox(height: AppSpacing.lg),

        // Breakdown section
        SectionHeader(
          title: 'Performance Breakdown',
          subtitle: 'How you did on each question type',
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildBreakdown(isDark),
      ],
    );
  }

  // ── Stats grid ───────────────────────────────

  Widget _buildStatsGrid(bool isDark) {
    final answered = widget.userAnswers.length;
    final skipped = widget.assessment.questions.length - answered;

    int correct = 0;
    for (int i = 0; i < widget.assessment.questions.length; i++) {
      final q = widget.assessment.questions[i];
      if (q.isMultipleChoice &&
          widget.userAnswers[i]?.trim().toLowerCase() ==
              q.answerKey?.trim().toLowerCase()) {
        correct++;
      }
    }
    final mcqTotal = widget.assessment.questions
        .where((q) => q.isMultipleChoice)
        .length;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      childAspectRatio: 2.2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _StatCard(
          icon: Icons.check_circle_rounded,
          label: 'Answered',
          value: '$answered/${widget.assessment.questions.length}',
          color: AppColors.success,
          isDark: isDark,
        ),
        _StatCard(
          icon: Icons.cancel_rounded,
          label: 'Skipped',
          value: '$skipped',
          color: skipped > 0 ? AppColors.warning : AppColors.success,
          isDark: isDark,
        ),
        _StatCard(
          icon: Icons.thumb_up_rounded,
          label: 'MCQ Correct',
          value: '$correct/$mcqTotal',
          color: AppColors.info,
          isDark: isDark,
        ),
        _StatCard(
          icon: Icons.timer_outlined,
          label: 'Estimated Time',
          value: '${widget.assessment.metadata.estimatedTime} min',
          color: AppColors.primary,
          isDark: isDark,
        ),
      ],
    );
  }

  // ── Breakdown ────────────────────────────────

  Widget _buildBreakdown(bool isDark) {
    final mcq = widget.assessment.questions
        .where((q) => q.isMultipleChoice)
        .toList();
    final openEnded = widget.assessment.questions
        .where((q) => !q.isMultipleChoice)
        .toList();

    int mcqScore = 0;
    for (int i = 0; i < widget.assessment.questions.length; i++) {
      final q = widget.assessment.questions[i];
      if (q.isMultipleChoice &&
          widget.userAnswers[i]?.trim().toLowerCase() ==
              q.answerKey?.trim().toLowerCase()) {
        mcqScore += q.marks;
      }
    }

    final mcqTotal = mcq.fold<int>(0, (s, q) => s + q.marks);
    final mcqPct = mcqTotal == 0 ? 0.0 : mcqScore / mcqTotal;

    return Column(
      children: [
        if (mcq.isNotEmpty)
          _BreakdownBar(
            label: 'Multiple Choice',
            answered: mcq
                .where((q) {
                  final idx = widget.assessment.questions.indexOf(q);
                  return widget.userAnswers.containsKey(idx);
                })
                .length,
            total: mcq.length,
            percentage: mcqPct,
            color: AppColors.primary,
            isDark: isDark,
          ),
        if (openEnded.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _BreakdownBar(
            label: 'Open-ended',
            answered: openEnded
                .where((q) {
                  final idx = widget.assessment.questions.indexOf(q);
                  return (widget.userAnswers[idx] ?? '').trim().isNotEmpty;
                })
                .length,
            total: openEnded.length,
            percentage: openEnded
                        .where((q) {
                          final idx = widget.assessment.questions.indexOf(q);
                          return (widget.userAnswers[idx] ?? '').trim().isNotEmpty;
                        })
                        .length /
                    openEnded.length,
            color: AppColors.info,
            isDark: isDark,
          ),
        ],
      ],
    );
  }

  // ── Review list ──────────────────────────────

  Widget _buildReviewList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      itemCount: widget.assessment.questions.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: SectionHeader(
              title: 'Answer Review',
              subtitle:
                  '${widget.assessment.questions.length} questions  •  tap to expand',
              padding: EdgeInsets.zero,
            ),
          );
        }
        final i = index - 1;
        final q = widget.assessment.questions[i];
        final userAnswer = widget.userAnswers[i];
        final isCorrect = q.isMultipleChoice &&
            userAnswer?.trim().toLowerCase() ==
                q.answerKey?.trim().toLowerCase();
        final isAnswered =
            userAnswer != null && userAnswer.trim().isNotEmpty;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _ReviewCard(
            index: i,
            question: q,
            userAnswer: userAnswer,
            isCorrect: isCorrect,
            isAnswered: isAnswered,
            isDark: isDark,
          ),
        );
      },
    );
  }

  // ── Bottom actions ───────────────────────────

  Widget _buildBottomActions(bool isDark) {
    final bg = isDark ? AppColors.darkSurface : AppColors.surface;
    final border =
        isDark ? const Color(0xFF353850) : const Color(0xFFEEEFF8);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border, width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: SecondaryButton(
              label: _showReview ? 'Show Score' : 'Review Answers',
              icon: _showReview
                  ? Icons.bar_chart_rounded
                  : Icons.fact_check_outlined,
              onPressed: () =>
                  setState(() => _showReview = !_showReview),
              height: 48,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: GradientButton(
              label: 'New Quiz',
              icon: Icons.refresh_rounded,
              onPressed: widget.onExit,
              gradient: _gradeGradient,
              height: 48,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  _StatCard
// ─────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                Text(
                  label,
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
    );
  }
}

// ─────────────────────────────────────────────
//  _BreakdownBar
// ─────────────────────────────────────────────

class _BreakdownBar extends StatelessWidget {
  final String label;
  final int answered;
  final int total;
  final double percentage;
  final Color color;
  final bool isDark;

  const _BreakdownBar({
    required this.label,
    required this.answered,
    required this.total,
    required this.percentage,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '$answered/$total',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: isDark
                  ? AppColors.darkSurfaceVariant
                  : AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  _ReviewCard
// ─────────────────────────────────────────────

class _ReviewCard extends StatefulWidget {
  final int index;
  final Question question;
  final String? userAnswer;
  final bool isCorrect;
  final bool isAnswered;
  final bool isDark;

  const _ReviewCard({
    required this.index,
    required this.question,
    required this.userAnswer,
    required this.isCorrect,
    required this.isAnswered,
    required this.isDark,
  });

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final q = widget.question;

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    if (!widget.isAnswered) {
      statusColor = AppColors.textSecondary;
      statusIcon = Icons.remove_circle_outline_rounded;
      statusLabel = 'Skipped';
    } else if (q.isMultipleChoice) {
      statusColor = widget.isCorrect ? AppColors.success : AppColors.error;
      statusIcon = widget.isCorrect
          ? Icons.check_circle_rounded
          : Icons.cancel_rounded;
      statusLabel = widget.isCorrect ? 'Correct' : 'Incorrect';
    } else {
      statusColor = AppColors.info;
      statusIcon = Icons.edit_rounded;
      statusLabel = 'Answered';
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      border: Border.all(
        color: statusColor.withAlpha(51),
        width: 1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${widget.index + 1}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  q.questionText.length > 60
                      ? '${q.questionText.substring(0, 60)}…'
                      : q.questionText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Status badge
              StatusBadge(
                label: statusLabel,
                variant: !widget.isAnswered
                    ? BadgeVariant.neutral
                    : q.isMultipleChoice
                        ? (widget.isCorrect
                            ? BadgeVariant.success
                            : BadgeVariant.error)
                        : BadgeVariant.info,
                icon: statusIcon,
                compact: true,
              ),
              // Expand toggle
              IconButton(
                onPressed: () =>
                    setState(() => _expanded = !_expanded),
                icon: Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 20,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),

          // ── Expanded detail ──────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(
                          color: isDark
                              ? const Color(0xFF353850)
                              : const Color(0xFFEEEFF8),
                          height: 1,
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        // Full question text
                        Text(
                          'Question:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          q.questionText,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // Your answer
                        Text(
                          'Your answer:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(20),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.inputRadius),
                            border: Border.all(
                              color: statusColor.withAlpha(51),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            widget.isAnswered
                                ? (widget.userAnswer ?? '')
                                : 'Not answered',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textPrimary,
                              fontStyle: widget.isAnswered
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                            ),
                          ),
                        ),

                        // Correct answer (MCQ only)
                        if (q.isMultipleChoice &&
                            q.answerKey != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Correct answer:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textSecondary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.success.withAlpha(20),
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.inputRadius),
                              border: Border.all(
                                color: AppColors.success.withAlpha(51),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 14,
                                  color: AppColors.success,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    q.answerKey!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.5,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
