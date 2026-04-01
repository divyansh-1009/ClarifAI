import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'quiz_page.dart';

// ─────────────────────────────────────────────
//  Difficulty option data
// ─────────────────────────────────────────────

class _DifficultyOption {
  final String value;
  final String label;
  final String description;
  final String emoji;
  final int questionCount;
  final List<Color> gradient;
  final IconData icon;

  const _DifficultyOption({
    required this.value,
    required this.label,
    required this.description,
    required this.emoji,
    required this.questionCount,
    required this.gradient,
    required this.icon,
  });
}

const _difficultyOptions = [
  _DifficultyOption(
    value: 'easy',
    label: 'Easy',
    description: 'Foundational concepts\n& recall questions',
    emoji: '🌱',
    questionCount: 5,
    gradient: [Color(0xFF66BB6A), Color(0xFF43A047)],
    icon: Icons.sentiment_satisfied_rounded,
  ),
  _DifficultyOption(
    value: 'medium',
    label: 'Medium',
    description: 'Mixed question types\n& applied reasoning',
    emoji: '⚡',
    questionCount: 7,
    gradient: [Color(0xFFFFA726), Color(0xFFF57C00)],
    icon: Icons.sentiment_neutral_rounded,
  ),
  _DifficultyOption(
    value: 'hard',
    label: 'Hard',
    description: 'Exam-grade problems\n& deep analysis',
    emoji: '🔥',
    questionCount: 10,
    gradient: [Color(0xFFEF5350), Color(0xFFB71C1C)],
    icon: Icons.local_fire_department_rounded,
  ),
];

// ─────────────────────────────────────────────
//  AssessmentSetupPage
// ─────────────────────────────────────────────

class AssessmentSetupPage extends StatefulWidget {
  const AssessmentSetupPage({super.key});

  @override
  State<AssessmentSetupPage> createState() => _AssessmentSetupPageState();
}

class _AssessmentSetupPageState extends State<AssessmentSetupPage>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _topicController = TextEditingController();
  final _subjectFocus = FocusNode();
  final _topicFocus = FocusNode();

  String _selectedDifficulty = 'medium';
  bool _isGenerating = false;
  String? _generatingMessage;

  late AnimationController _entryController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Suggested subjects list
  static const _subjectSuggestions = [
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'History',
    'Geography',
    'Economics',
    'English',
    'Computer Science',
    'Political Science',
  ];

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.07),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _entryController, curve: Curves.easeOut));

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _subjectController.dispose();
    _topicController.dispose();
    _subjectFocus.dispose();
    _topicFocus.dispose();
    super.dispose();
  }

  // ── Getters ──────────────────────────────────

  _DifficultyOption get _currentDifficulty =>
      _difficultyOptions.firstWhere((d) => d.value == _selectedDifficulty);

  // ── Validation ───────────────────────────────

  String? _validateSubject(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Subject is required';
    }
    if (value.trim().length < 2) {
      return 'Subject must be at least 2 characters';
    }
    if (value.trim().length > 100) {
      return 'Subject must be under 100 characters';
    }
    return null;
  }

  String? _validateTopic(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Topic is required';
    }
    if (value.trim().length < 2) {
      return 'Topic must be at least 2 characters';
    }
    if (value.trim().length > 100) {
      return 'Topic must be under 100 characters';
    }
    return null;
  }

  // ── Generate assessment ──────────────────────

  Future<void> _generateAssessment() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isGenerating = true;
      _generatingMessage = 'Analysing your topic…';
    });

    // Cycle through loading messages for better UX
    _cycleLoadingMessages();

    try {
      final assessment = await _api.generateAssessment(
        subject: _subjectController.text.trim(),
        topic: _topicController.text.trim(),
        difficulty: _selectedDifficulty,
      );

      if (!mounted) return;

      // Navigate to quiz page
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => QuizPage(
            assessment: assessment,
            subject: _subjectController.text.trim(),
            topic: _topicController.text.trim(),
            difficulty: _selectedDifficulty,
          ),
          transitionsBuilder: (_, animation, __, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOut),
              ),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) {
        _showError(
          'Could not generate assessment. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _generatingMessage = null;
        });
      }
    }
  }

  void _cycleLoadingMessages() async {
    final messages = [
      'Analysing your topic…',
      'Crafting questions with AI…',
      'Calibrating difficulty…',
      'Almost ready…',
    ];
    for (int i = 1; i < messages.length; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted && _isGenerating) {
        setState(() => _generatingMessage = messages[i]);
      }
    }
  }

  // ── Error display ────────────────────────────

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 5),
        ),
      );
  }

  // ── Subject suggestion picked ────────────────

  void _pickSuggestion(String subject) {
    _subjectController.text = subject;
    _subjectFocus.unfocus();
    _formKey.currentState?.validate();
  }

  // ════════════════════════════════════════════
  //  Build
  // ════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return LoadingOverlay(
      isLoading: _isGenerating,
      message: _generatingMessage,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            children: [
              // ── Hero banner ──────────────────────────
              _buildHeroBanner(isDark),

              const SizedBox(height: AppSpacing.xl),

              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Subject section ──────────────────────
                    _buildSectionLabel(
                      context,
                      icon: Icons.menu_book_outlined,
                      title: 'Subject',
                      subtitle: 'What subject should the quiz cover?',
                      isDark: isDark,
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    AppTextField(
                      controller: _subjectController,
                      focusNode: _subjectFocus,
                      hint: 'e.g. Mathematics, Physics, History…',
                      prefixIcon: Icons.menu_book_outlined,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.done,
                      validator: _validateSubject,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      maxLength: 100,
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // Subject suggestions
                    _buildSubjectSuggestions(isDark),

                    const SizedBox(height: AppSpacing.lg),

                    _buildSectionLabel(
                      context,
                      icon: Icons.topic_outlined,
                      title: 'Topic',
                      subtitle: 'What exact chapter/topic should be tested?',
                      isDark: isDark,
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    AppTextField(
                      controller: _topicController,
                      focusNode: _topicFocus,
                      hint: 'e.g. Quadratic Equations, Thermodynamics…',
                      prefixIcon: Icons.topic_outlined,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.done,
                      validator: _validateTopic,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      maxLength: 100,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Difficulty section ───────────────────
              _buildSectionLabel(
                context,
                icon: Icons.bar_chart_rounded,
                title: 'Difficulty',
                subtitle: 'Choose the challenge level',
                isDark: isDark,
              ),

              const SizedBox(height: AppSpacing.md),

              _buildDifficultySelector(isDark),

              const SizedBox(height: AppSpacing.xl),

              // ── Quiz preview card ────────────────────
              _buildPreviewCard(isDark),

              const SizedBox(height: AppSpacing.xl),

              // ── Generate button ──────────────────────
              GradientButton(
                label: 'Generate Assessment',
                icon: Icons.auto_awesome_rounded,
                isLoading: _isGenerating,
                onPressed: _isGenerating ? null : _generateAssessment,
                gradient: _currentDifficulty.gradient,
              ),

              const SizedBox(height: AppSpacing.md),

              // Disclaimer
              Center(
                child: Text(
                  'Quiz is generated directly from your subject, topic, and selected difficulty.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Hero Banner
  // ─────────────────────────────────────────────

  Widget _buildHeroBanner(bool isDark) {
    return GradientCard(
      gradient: [
        const Color(0xFF5C6BC0),
        const Color(0xFF7E57C2),
      ],
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(38),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'AI-Generated Quiz',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Assessment Generator',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'AI crafts personalised questions from your topic, subject and difficulty — tailored to the Indian curriculum.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withAlpha(204),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(38),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withAlpha(77),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.quiz_rounded,
              size: 32,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Section Label
  // ─────────────────────────────────────────────

  Widget _buildSectionLabel(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppColors.primaryGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  Subject Suggestions
  // ─────────────────────────────────────────────

  Widget _buildSubjectSuggestions(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick picks:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: _subjectSuggestions
              .map(
                (s) => _SubjectChip(
                  label: s,
                  isSelected: _subjectController.text.trim() == s,
                  isDark: isDark,
                  onTap: () => _pickSuggestion(s),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  Difficulty Selector
  // ─────────────────────────────────────────────

  Widget _buildDifficultySelector(bool isDark) {
    return Row(
      children: _difficultyOptions
          .map(
            (option) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: option.value == 'hard' ? 0 : AppSpacing.sm,
                ),
                child: _DifficultyCard(
                  option: option,
                  isSelected: _selectedDifficulty == option.value,
                  isDark: isDark,
                  onTap: () =>
                      setState(() => _selectedDifficulty = option.value),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  // ─────────────────────────────────────────────
  //  Preview Card
  // ─────────────────────────────────────────────

  Widget _buildPreviewCard(bool isDark) {
    final diff = _currentDifficulty;
    final subject = _subjectController.text.trim().isNotEmpty
        ? _subjectController.text.trim()
        : 'your subject';
    final topic = _topicController.text.trim().isNotEmpty
        ? _topicController.text.trim()
        : 'your topic';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      border: Border.all(
        color: AppColors.primary.withAlpha(51),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withAlpha(20),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: diff.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(diff.icon, size: 18, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quiz Preview',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'What your assessment will look like',
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
              StatusBadge.difficulty(_selectedDifficulty),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          Divider(
            color: isDark
                ? const Color(0xFF353850)
                : const Color(0xFFEEEFF8),
            height: 1,
          ),

          const SizedBox(height: AppSpacing.md),

          // Stats row
          Row(
            children: [
              _PreviewStat(
                icon: Icons.quiz_rounded,
                label: 'Questions',
                value: '${diff.questionCount}',
                isDark: isDark,
              ),
              _PreviewDivider(isDark: isDark),
              _PreviewStat(
                icon: Icons.menu_book_rounded,
                label: 'Subject',
                value: subject.length > 14
                    ? '${subject.substring(0, 14)}…'
                    : subject,
                isDark: isDark,
              ),
              _PreviewDivider(isDark: isDark),
              _PreviewStat(
                icon: Icons.topic_rounded,
                label: 'Topic',
                value: topic.length > 14
                    ? '${topic.substring(0, 14)}…'
                    : topic,
                isDark: isDark,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Question types info
          _buildQuestionTypesRow(isDark),
        ],
      ),
    );
  }

  Widget _buildQuestionTypesRow(bool isDark) {
    final types = [
      (Icons.check_circle_outline_rounded, 'MCQ', BadgeVariant.primary),
      (Icons.short_text_rounded, 'Short Answer', BadgeVariant.info),
      (Icons.calculate_outlined, 'Problem Solving', BadgeVariant.warning),
    ];

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: types
          .map(
            (t) => StatusBadge(
              label: t.$2,
              variant: t.$3,
              icon: t.$1,
              compact: true,
            ),
          )
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────
//  _DifficultyCard
// ─────────────────────────────────────────────

class _DifficultyCard extends StatefulWidget {
  final _DifficultyOption option;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _DifficultyCard({
    required this.option,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_DifficultyCard> createState() => _DifficultyCardState();
}

class _DifficultyCardState extends State<_DifficultyCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
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
    final option = widget.option;
    final isSelected = widget.isSelected;
    final isDark = widget.isDark;

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: option.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected
                ? null
                : (isDark
                    ? AppColors.darkSurface
                    : AppColors.surface),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : (isDark
                      ? const Color(0xFF353850)
                      : const Color(0xFFEEEFF8)),
              width: isSelected ? 0 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: option.gradient.first.withAlpha(77),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withAlpha(38)
                          : const Color(0x0A5C6BC0),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Emoji
              Text(
                option.emoji,
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(height: 6),

              // Label
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.white
                      : (isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary),
                  letterSpacing: 0.1,
                ),
                child: Text(option.label),
              ),

              const SizedBox(height: 4),

              // Description
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: isSelected
                      ? Colors.white.withAlpha(204)
                      : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary),
                  height: 1.4,
                ),
                child: Text(
                  option.description,
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 8),

              // Question count badge
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withAlpha(51)
                      : option.gradient.first.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '~${option.questionCount}Q',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? Colors.white
                        : option.gradient.first,
                    letterSpacing: 0.3,
                  ),
                ),
              ),

              // Selected indicator
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isSelected ? 20 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(isSelected ? 179 : 0),
                  borderRadius: BorderRadius.circular(2),
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
//  _SubjectChip
// ─────────────────────────────────────────────

class _SubjectChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _SubjectChip({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark
                  ? AppColors.darkSurfaceVariant
                  : AppColors.surfaceVariant),
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark
                    ? const Color(0xFF353850)
                    : const Color(0xFFDDE1F0)),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(51),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  _PreviewStat
// ─────────────────────────────────────────────

class _PreviewStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _PreviewStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 18,
            color: isDark ? AppColors.primaryLight : AppColors.primary,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
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
    );
  }
}

// ─────────────────────────────────────────────
//  _PreviewDivider
// ─────────────────────────────────────────────

class _PreviewDivider extends StatelessWidget {
  final bool isDark;

  const _PreviewDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: isDark ? const Color(0xFF353850) : const Color(0xFFEEEFF8),
    );
  }
}
