import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';
import '../models/topic_model.dart';
import '../widgets/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'topics_page.dart';
import 'query_page.dart';
import 'assessment_setup_page.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late final List<Widget> _pages;
  late AnimationController _fabAnimController;

  // For cross-tab topic selection
  TopicModel? _selectedTopic;

  @override
  void initState() {
    super.initState();
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();

    _pages = [
      _DashboardTab(
        onTopicSelected: _handleTopicSelected,
        onNavigate: _navigateTo,
      ),
      TopicsPage(
        onTopicSelected: _handleTopicSelected,
      ),
      QueryPage(selectedTopic: _selectedTopic),
      AssessmentSetupPage(),
    ];
  }

  @override
  void dispose() {
    _fabAnimController.dispose();
    super.dispose();
  }

  void _handleTopicSelected(TopicModel topic) {
    setState(() {
      _selectedTopic = topic;
      // Rebuild pages list with updated topic
      _pages[2] = QueryPage(selectedTopic: _selectedTopic);
    });
  }

  void _navigateTo(int index) {
    setState(() => _selectedIndex = index);
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out of ClarifAI?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (_, animation, __) => const LoginPage(),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
          (route) => false,
        );
      }
    }
  }

  // ── Navigation bar labels & icons ────────────

  static const _navItems = [
    _NavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    _NavItem(
      label: 'Topics',
      icon: Icons.library_books_outlined,
      activeIcon: Icons.library_books_rounded,
    ),
    _NavItem(
      label: 'Ask AI',
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
    ),
    _NavItem(
      label: 'Quiz',
      icon: Icons.quiz_outlined,
      activeIcon: Icons.quiz_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: _buildAppBar(isDark, user?.username ?? 'Learner'),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_selectedIndex),
          child: _pages[_selectedIndex],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(isDark),
    );
  }

  // ── App bar ──────────────────────────────────

  PreferredSizeWidget _buildAppBar(bool isDark, String username) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        title: _selectedIndex == 0
            ? _buildHomeTitle(isDark, username)
            : Text(
                _navItems[_selectedIndex].label,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
        actions: [
          // Topic indicator for Query tab
          if (_selectedIndex == 2 && _selectedTopic != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: StatusBadge(
                label: _selectedTopic!.topic,
                variant: BadgeVariant.primary,
                icon: Icons.topic_rounded,
              ),
            ),

          // User avatar + logout
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _showUserMenu,
              child: AvatarWidget(
                name: context.watch<AuthProvider>().user?.username ?? '?',
                radius: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTitle(bool isDark, String username) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good morning,';
    } else if (hour < 17) {
      greeting = 'Good afternoon,';
    } else {
      greeting = 'Good evening,';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          greeting,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
        Text(
          username,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ── User menu ────────────────────────────────

  void _showUserMenu() {
    final user = context.read<AuthProvider>().user;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UserMenuSheet(
        username: user?.username ?? 'Unknown',
        email: user?.email ?? '',
        onLogout: () {
          Navigator.pop(ctx);
          _confirmLogout();
        },
      ),
    );
  }

  // ── Bottom navigation ────────────────────────

  Widget _buildBottomNav(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withAlpha(77)
                : const Color(0x1A5C6BC0),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (index) {
              final item = _navItems[index];
              final isSelected = _selectedIndex == index;

              return _NavBarItem(
                item: item,
                isSelected: isSelected,
                isDark: isDark,
                onTap: () => setState(() => _selectedIndex = index),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
//  Dashboard Tab
// ════════════════════════════════════════════

class _DashboardTab extends StatefulWidget {
  final ValueChanged<TopicModel> onTopicSelected;
  final ValueChanged<int> onNavigate;

  const _DashboardTab({
    required this.onTopicSelected,
    required this.onNavigate,
  });

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  final ApiService _api = ApiService();

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final user = context.watch<AuthProvider>().user;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await context.read<AuthProvider>().refreshUser();
        setState(() {});
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          // ── Hero banner ──────────────────────────
          _HeroBanner(username: user?.username ?? 'Learner'),

          const SizedBox(height: AppSpacing.lg),

          // ── Quick actions ────────────────────────
          SectionHeader(
            title: 'Quick Actions',
            subtitle: 'What would you like to do?',
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm,
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          _QuickActionsGrid(onNavigate: widget.onNavigate),

          const SizedBox(height: AppSpacing.lg),

          // ── Feature highlights ───────────────────
          SectionHeader(
            title: 'How It Works',
            subtitle: 'ClarifAI features at a glance',
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          ),

          const SizedBox(height: AppSpacing.sm),

          _FeatureHighlights(),

          const SizedBox(height: AppSpacing.lg),

          // ── Tips ─────────────────────────────────
          _TipsBanner(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Hero Banner
// ─────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final String username;
  const _HeroBanner({required this.username});

  @override
  Widget build(BuildContext context) {
    return GradientCard(
      gradient: AppColors.heroGradient,
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
                        'AI-Powered Learning',
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
                const SizedBox(height: 12),
                Text(
                  'Ready to learn,\n$username?',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.25,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload notes, ask questions, and\ngenerate smart assessments.',
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
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(38),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withAlpha(77),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.psychology_rounded,
              size: 36,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Quick Actions Grid
// ─────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  final ValueChanged<int> onNavigate;

  const _QuickActionsGrid({required this.onNavigate});

  static const _actions = [
    _QuickAction(
      icon: Icons.add_circle_outline_rounded,
      label: 'New Topic',
      subtitle: 'Upload PDF notes',
      gradient: [Color(0xFF5C6BC0), Color(0xFF7E57C2)],
      tabIndex: 1,
    ),
    _QuickAction(
      icon: Icons.chat_bubble_outline_rounded,
      label: 'Ask AI',
      subtitle: 'RAG-powered Q&A',
      gradient: [Color(0xFF26C6DA), Color(0xFF00ACC1)],
      tabIndex: 2,
    ),
    _QuickAction(
      icon: Icons.quiz_outlined,
      label: 'Take Quiz',
      subtitle: 'AI assessments',
      gradient: [Color(0xFFFF7043), Color(0xFFE64A19)],
      tabIndex: 3,
    ),
    _QuickAction(
      icon: Icons.library_books_outlined,
      label: 'My Topics',
      subtitle: 'Browse knowledge',
      gradient: [Color(0xFF66BB6A), Color(0xFF388E3C)],
      tabIndex: 1,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.55,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: _actions
          .map((action) => _QuickActionCard(
                action: action,
                onTap: () => onNavigate(action.tabIndex),
              ))
          .toList(),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> gradient;
  final int tabIndex;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.tabIndex,
  });
}

class _QuickActionCard extends StatelessWidget {
  final _QuickAction action;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: action.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          boxShadow: [
            BoxShadow(
              color: action.gradient.first.withAlpha(77),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(38),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(action.icon, size: 20, color: Colors.white),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  action.subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withAlpha(179),
                    fontWeight: FontWeight.w400,
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
//  Feature Highlights
// ─────────────────────────────────────────────

class _FeatureHighlights extends StatelessWidget {
  const _FeatureHighlights();

  static const _features = [
    _Feature(
      icon: Icons.cloud_upload_outlined,
      title: 'Upload Notes',
      description:
          'Upload your PDF study materials. ClarifAI automatically extracts text and creates semantic embeddings.',
      badgeLabel: 'Step 1',
      badgeVariant: BadgeVariant.primary,
    ),
    _Feature(
      icon: Icons.psychology_outlined,
      title: 'Ask Questions',
      description:
          'Ask any question about your topic. Our RAG engine finds relevant context from your notes and crafts precise answers.',
      badgeLabel: 'Step 2',
      badgeVariant: BadgeVariant.info,
    ),
    _Feature(
      icon: Icons.star_outline_rounded,
      title: 'Generate Quiz',
      description:
          'Get AI-generated assessments tailored to your class, topic, subject, and preferred difficulty level.',
      badgeLabel: 'Step 3',
      badgeVariant: BadgeVariant.success,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _features
          .map((f) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _FeatureCard(feature: f),
              ))
          .toList(),
    );
  }
}

class _Feature {
  final IconData icon;
  final String title;
  final String description;
  final String badgeLabel;
  final BadgeVariant badgeVariant;

  const _Feature({
    required this.icon,
    required this.title,
    required this.description,
    required this.badgeLabel,
    required this.badgeVariant,
  });
}

class _FeatureCard extends StatelessWidget {
  final _Feature feature;
  const _FeatureCard({required this.feature});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            child: Icon(feature.icon, size: 22, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        feature.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    StatusBadge(
                      label: feature.badgeLabel,
                      variant: feature.badgeVariant,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  feature.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                    height: 1.5,
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
//  Tips Banner
// ─────────────────────────────────────────────

class _TipsBanner extends StatelessWidget {
  const _TipsBanner();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: AppColors.primary.withAlpha(13),
      border: Border.all(
        color: AppColors.primary.withAlpha(51),
        width: 1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Pro Tips',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...[
            '📄 Upload well-formatted PDFs for better extraction quality.',
            '🔍 Be specific with questions to get grounded, accurate answers.',
            '🎯 Set difficulty to "Hard" for exam-style preparation.',
            '📚 Create separate topics for different subjects.',
          ].map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                tip,
                style: TextStyle(
                  fontSize: 13,
                  color: context.isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                  height: 1.4,
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
//  User Menu Bottom Sheet
// ════════════════════════════════════════════

class _UserMenuSheet extends StatelessWidget {
  final String username;
  final String email;
  final VoidCallback onLogout;

  const _UserMenuSheet({
    required this.username,
    required this.email,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceVariant
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // User info
          Row(
            children: [
              AvatarWidget(name: username, radius: 28),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
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
              StatusBadge(
                label: 'Student',
                variant: BadgeVariant.primary,
                icon: Icons.school_rounded,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),

          // Menu items
          ListTile(
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(26),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.logout_rounded,
                size: 20,
                color: AppColors.error,
              ),
            ),
            title: const Text(
              'Sign Out',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
            subtitle: const Text(
              'Log out from your account',
              style: TextStyle(fontSize: 12),
            ),
            onTap: onLogout,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
//  Navigation bar item
// ════════════════════════════════════════════

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

class _NavBarItem extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.item,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final inactiveColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final indicatorColor = isDark
        ? AppColors.primary.withAlpha(51)
        : AppColors.primary.withAlpha(26);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? indicatorColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
                ),
                child: Icon(
                  isSelected ? item.activeIcon : item.icon,
                  size: 22,
                  color: isSelected ? activeColor : inactiveColor,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? activeColor : inactiveColor,
                ),
                child: Text(item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
