import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/topic_model.dart';
import '../services/api_service.dart';
import '../widgets/app_theme.dart';
import '../widgets/common_widgets.dart';

// ─────────────────────────────────────────────
//  Topics Page
// ─────────────────────────────────────────────

class TopicsPage extends StatefulWidget {
  final ValueChanged<TopicModel>? onTopicSelected;

  const TopicsPage({super.key, this.onTopicSelected});

  @override
  State<TopicsPage> createState() => _TopicsPageState();
}

class _TopicsPageState extends State<TopicsPage>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  final List<TopicModel> _topics = [];
  TopicModel? _selectedTopic;
  bool _isLoading = true;

  static const _cacheKey = 'cached_topics';

  @override
  void initState() {
    super.initState();
    _loadCachedTopics();
  }

  // ── Persistence ──────────────────────────────

  Future<void> _loadCachedTopics() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null) {
        final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
        final topics = decoded
            .map((e) => TopicModel.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() => _topics.addAll(topics));
      }
    } catch (_) {
      // Silently ignore cache errors
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cacheTopics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_topics.map((t) => t.toJson()).toList());
      await prefs.setString(_cacheKey, encoded);
    } catch (_) {}
  }

  // ── Topic CRUD ───────────────────────────────

  Future<void> _createTopic({
    required String className,
    required String topicName,
    File? pdfFile,
  }) async {
    try {
      final topic = await _api.createTopic(
        className: className,
        topic: topicName,
        pdfFile: pdfFile,
      );
      setState(() => _topics.insert(0, topic));
      await _cacheTopics();

      if (mounted) {
        _showSuccess(
          'Topic "${topic.topic}" created successfully'
          '${pdfFile != null ? ' with PDF notes' : ''}.',
        );
      }
    } on UnauthorizedException {
      if (mounted) {
        _showError('Session expired. Please log in again.');
      }
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) {
        _showError('Failed to create topic. Check your connection.');
      }
    }
  }

  void _selectTopic(TopicModel topic) {
    setState(() => _selectedTopic = topic);
    widget.onTopicSelected?.call(topic);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '"${topic.topic}" selected for Q&A.',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _deleteTopic(TopicModel topic) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Topic'),
        content: Text(
          'Remove "${topic.topic}" from your list?\n\nNote: This only removes it locally — the knowledge base on the server is preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _topics.removeWhere((t) => t.id == topic.id);
        if (_selectedTopic?.id == topic.id) _selectedTopic = null;
      });
      await _cacheTopics();
    }
  }

  // ── Snackbars ────────────────────────────────

  void _showError(String message) {
    if (!mounted) return;
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  // ── Bottom sheet ─────────────────────────────

  void _openCreateSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CreateTopicSheet(
        onSubmit: ({
          required String className,
          required String topicName,
          File? pdfFile,
        }) {
          _createTopic(
            className: className,
            topicName: topicName,
            pdfFile: pdfFile,
          );
        },
      ),
    );
  }

  // ── Build ────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return Stack(
      children: [
        _topics.isEmpty
            ? _buildEmptyState(isDark)
            : _buildTopicList(isDark),

        // FAB
        Positioned(
          right: AppSpacing.md,
          bottom: AppSpacing.md,
          child: FloatingActionButton.extended(
            onPressed: _openCreateSheet,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 4,
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'New Topic',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return EmptyState(
      icon: Icons.library_books_outlined,
      title: 'No Topics Yet',
      subtitle:
          'Create your first topic by uploading your study notes. ClarifAI will index them for intelligent Q&A and assessment generation.',
      action: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: GradientButton(
          label: 'Create First Topic',
          icon: Icons.add_rounded,
          onPressed: _openCreateSheet,
        ),
      ),
    );
  }

  Widget _buildTopicList(bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        100, // FAB clearance
      ),
      children: [
        // ── Header info ──────────────────────────
        if (_selectedTopic != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: InfoBanner(
              message:
                  'Using "${_selectedTopic!.topic}" for Q&A. Tap another topic to switch.',
              variant: BadgeVariant.primary,
              icon: Icons.info_outline_rounded,
            ),
          ),

        SectionHeader(
          title: '${_topics.length} Topic${_topics.length == 1 ? '' : 's'}',
          subtitle: 'Tap to select for Q&A',
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          trailing: Text(
            'Swipe to delete',
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // ── Topic cards ──────────────────────────
        ...List.generate(_topics.length, (index) {
          final topic = _topics[index];
          final isSelected = _selectedTopic?.id == topic.id;

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _DismissibleTopicCard(
              topic: topic,
              isSelected: isSelected,
              onTap: () => _selectTopic(topic),
              onDelete: () => _deleteTopic(topic),
            ),
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Dismissible Topic Card
// ─────────────────────────────────────────────

class _DismissibleTopicCard extends StatelessWidget {
  final TopicModel topic;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DismissibleTopicCard({
    required this.topic,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Dismissible(
      key: ValueKey(topic.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.error.withAlpha(26),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline_rounded, color: AppColors.error),
            SizedBox(height: 4),
            Text(
              'Remove',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // Let the delete handler manage state
      },
      child: _TopicCard(
        topic: topic,
        isSelected: isSelected,
        onTap: onTap,
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Topic Card
// ─────────────────────────────────────────────

class _TopicCard extends StatelessWidget {
  final TopicModel topic;
  final bool isSelected;
  final VoidCallback onTap;

  const _TopicCard({
    required this.topic,
    required this.isSelected,
    required this.onTap,
  });

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _classInitials(String className) {
    final parts = className.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return className.length >= 2
        ? className.substring(0, 2).toUpperCase()
        : className.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
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
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ]
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Class badge ──────────────────────────
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isSelected
                    ? AppColors.primaryGradient
                    : (isDark
                        ? [
                            AppColors.darkSurfaceVariant,
                            AppColors.darkSurfaceVariant,
                          ]
                        : [
                            AppColors.surfaceVariant,
                            AppColors.surfaceVariant,
                          ]),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              _classInitials(topic.className),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isSelected
                    ? Colors.white
                    : (isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary),
                letterSpacing: 0.5,
              ),
            ),
          ),

          const SizedBox(width: AppSpacing.md),

          // ── Topic info ───────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        topic.topic,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      StatusBadge(
                        label: 'Active',
                        variant: BadgeVariant.success,
                        icon: Icons.check_rounded,
                        compact: true,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.class_outlined,
                      size: 13,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        topic.className,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary.withAlpha(153)
                          : AppColors.textHint,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _formatDate(topic.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextSecondary.withAlpha(153)
                            : AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: AppSpacing.sm),

          // ── Arrow ────────────────────────────────
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: isSelected
                ? AppColors.primary
                : (isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textHint),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Create Topic Bottom Sheet
// ─────────────────────────────────────────────

typedef _CreateTopicCallback = void Function({
  required String className,
  required String topicName,
  File? pdfFile,
});

class _CreateTopicSheet extends StatefulWidget {
  final _CreateTopicCallback onSubmit;

  const _CreateTopicSheet({required this.onSubmit});

  @override
  State<_CreateTopicSheet> createState() => _CreateTopicSheetState();
}

class _CreateTopicSheetState extends State<_CreateTopicSheet> {
  final _formKey = GlobalKey<FormState>();
  final _classController = TextEditingController();
  final _topicController = TextEditingController();
  final _classFocus = FocusNode();
  final _topicFocus = FocusNode();

  File? _pickedPdf;
  String? _pdfFileName;
  bool _isSubmitting = false;
  bool _isPicking = false;

  @override
  void dispose() {
    _classController.dispose();
    _topicController.dispose();
    _classFocus.dispose();
    _topicFocus.dispose();
    super.dispose();
  }

  // ── Validators ───────────────────────────────

  String? _validateClass(String? v) {
    if (v == null || v.trim().isEmpty) return 'Class / Grade is required';
    if (v.trim().length < 2) return 'Must be at least 2 characters';
    return null;
  }

  String? _validateTopic(String? v) {
    if (v == null || v.trim().isEmpty) return 'Topic name is required';
    if (v.trim().length < 3) return 'Must be at least 3 characters';
    return null;
  }

  // ── File picker ──────────────────────────────

  Future<void> _pickPdf() async {
    setState(() => _isPicking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final path = result.files.single.path;
        final name = result.files.single.name;
        if (path != null) {
          setState(() {
            _pickedPdf = File(path);
            _pdfFileName = name;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick file: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _clearPdf() => setState(() {
        _pickedPdf = null;
        _pdfFileName = null;
      });

  // ── Submit ───────────────────────────────────

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    // Close the sheet immediately for a snappy feel
    Navigator.pop(context);

    widget.onSubmit(
      className: _classController.text.trim(),
      topicName: _topicController.text.trim(),
      pdfFile: _pickedPdf,
    );
  }

  // ── Build ────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg + viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Handle bar ───────────────────────────
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceVariant
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── Sheet title ──────────────────────────
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.primaryGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.add_circle_outline_rounded,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New Topic',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Organise your study materials',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                  tooltip: 'Cancel',
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.md),

            // ── Form ─────────────────────────────────
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Class / Grade
                  _SheetFieldLabel(label: 'Class / Grade', isDark: isDark),
                  const SizedBox(height: AppSpacing.xs),
                  AppTextField(
                    controller: _classController,
                    focusNode: _classFocus,
                    hint: 'e.g. Class 12, Year 2, Grade 10',
                    prefixIcon: Icons.school_outlined,
                    textInputAction: TextInputAction.next,
                    validator: _validateClass,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Topic name
                  _SheetFieldLabel(label: 'Topic Name', isDark: isDark),
                  const SizedBox(height: AppSpacing.xs),
                  AppTextField(
                    controller: _topicController,
                    focusNode: _topicFocus,
                    hint: 'e.g. Thermodynamics, World War II, Calculus',
                    prefixIcon: Icons.topic_outlined,
                    textInputAction: TextInputAction.done,
                    validator: _validateTopic,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // PDF upload
                  _SheetFieldLabel(
                    label: 'Study Notes (PDF) — Optional',
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  _pickedPdf == null
                      ? _PdfPickerButton(
                          isPicking: _isPicking,
                          isDark: isDark,
                          onTap: _pickPdf,
                        )
                      : _PdfPreviewCard(
                          fileName: _pdfFileName ?? 'document.pdf',
                          filePath: _pickedPdf!.path,
                          isDark: isDark,
                          onRemove: _clearPdf,
                        ),

                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Only PDF files are supported. Text will be extracted and semantically indexed.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Action buttons ───────────────────────
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.pop(context),
                    height: 48,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: GradientButton(
                    label: 'Create Topic',
                    icon: Icons.check_rounded,
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting ? null : _submit,
                    height: 48,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  _SheetFieldLabel
// ─────────────────────────────────────────────

class _SheetFieldLabel extends StatelessWidget {
  final String label;
  final bool isDark;

  const _SheetFieldLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        letterSpacing: 0.2,
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  _PdfPickerButton
// ─────────────────────────────────────────────

class _PdfPickerButton extends StatelessWidget {
  final bool isPicking;
  final bool isDark;
  final VoidCallback onTap;

  const _PdfPickerButton({
    required this.isPicking,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isPicking ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 80,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          border: Border.all(
            color: isDark
                ? AppColors.darkSurfaceVariant
                : const Color(0xFFDDE1F0),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
        ),
        child: isPicking
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(26),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tap to select a PDF',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Notes will be indexed for Q&A',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  _PdfPreviewCard
// ─────────────────────────────────────────────

class _PdfPreviewCard extends StatelessWidget {
  final String fileName;
  final String filePath;
  final bool isDark;
  final VoidCallback onRemove;

  const _PdfPreviewCard({
    required this.fileName,
    required this.filePath,
    required this.isDark,
    required this.onRemove,
  });

  String get _fileSize {
    try {
      final bytes = File(filePath).lengthSync();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.success.withAlpha(isDark ? 38 : 20),
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        border: Border.all(
          color: AppColors.success.withAlpha(77),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.success.withAlpha(38),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              size: 22,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const StatusBadge(
                      label: 'Ready',
                      variant: BadgeVariant.success,
                      compact: true,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _fileSize,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.success,
            ),
            tooltip: 'Remove PDF',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
