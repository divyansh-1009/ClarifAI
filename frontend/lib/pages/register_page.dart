import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../widgets/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'home_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  // ── Page step ────────────────────────────────
  int _step = 0; // 0 = send OTP, 1 = verify + register

  // ── Form keys ────────────────────────────────
  final _step0FormKey = GlobalKey<FormState>();
  final _step1FormKey = GlobalKey<FormState>();

  // ── Controllers ──────────────────────────────
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _password2Controller = TextEditingController();
  final _otpController = TextEditingController();

  // ── Focus nodes ──────────────────────────────
  final _emailFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _password2Focus = FocusNode();
  final _otpFocus = FocusNode();

  // ── UI state ─────────────────────────────────
  bool _obscurePassword = true;
  bool _obscurePassword2 = true;
  bool _isSubmitting = false;

  // ── Animation ────────────────────────────────
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _password2Controller.dispose();
    _otpController.dispose();
    _emailFocus.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _password2Focus.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════
  //  Validators
  // ════════════════════════════════════════════

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(v.trim())) return 'Enter a valid email address';
    return null;
  }

  String? _validateUsername(String? v) {
    if (v == null || v.trim().isEmpty) return 'Username is required';
    if (v.trim().length < 3) return 'At least 3 characters required';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) {
      return 'Only letters, numbers and underscores allowed';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Minimum 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Include at least one uppercase letter';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Include at least one number';
    return null;
  }

  String? _validatePassword2(String? v) {
    if (v == null || v.isEmpty) return 'Please confirm your password';
    if (v != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  String? _validateOtp(String? v) {
    if (v == null || v.trim().isEmpty) return 'OTP is required';
    if (v.trim().length != 6) return 'OTP must be 6 digits';
    if (!RegExp(r'^\d{6}$').hasMatch(v.trim())) return 'OTP must contain only digits';
    return null;
  }

  // ════════════════════════════════════════════
  //  Actions
  // ════════════════════════════════════════════

  Future<void> _sendOtp() async {
    FocusScope.of(context).unfocus();
    if (!_step0FormKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final auth = context.read<AuthProvider>();
    auth.clearError();

    final success = await auth.sendOtp(_emailController.text.trim());

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      _showSuccess('OTP sent to ${_emailController.text.trim()}');
      _advanceToStep1();
    } else {
      _showError(auth.error ?? 'Failed to send OTP. Please try again.');
    }
  }

  void _advanceToStep1() {
    setState(() {
      _step = 1;
    });
    // Re-run entrance animation for step 1
    _animController
      ..reset()
      ..forward();
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    if (!_step1FormKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final auth = context.read<AuthProvider>();
    auth.clearError();

    final success = await auth.verifyOtpAndRegister(
      email: _emailController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      password2: _password2Controller.text,
      otp: _otpController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      _navigateToHome();
    } else {
      _showError(auth.error ?? 'Registration failed. Please try again.');
    }
  }

  void _goBackToStep0() {
    setState(() {
      _step = 0;
      _otpController.clear();
    });
    _animController
      ..reset()
      ..forward();
  }

  void _navigateToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const HomePage(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
      (route) => false,
    );
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
          duration: const Duration(seconds: 5),
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

  // ════════════════════════════════════════════
  //  Build
  // ════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: _step == 1 ? _goBackToStep0 : () => Navigator.pop(context),
          tooltip: _step == 1 ? 'Back to email' : 'Back to login',
        ),
        title: _buildStepIndicator(isDark),
        centerTitle: true,
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: size.height - 160),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      _buildHeader(isDark),
                      const SizedBox(height: AppSpacing.xl),
                      _step == 0
                          ? _buildStep0Form(isDark)
                          : _buildStep1Form(isDark),
                      const SizedBox(height: AppSpacing.xl),
                      _buildActionButton(isDark),
                      const SizedBox(height: AppSpacing.lg),
                      if (_step == 0) _buildLoginPrompt(isDark),
                      if (_step == 1) _buildResendOtpHint(isDark),
                      const Spacer(),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Step indicator ───────────────────────────

  Widget _buildStepIndicator(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepDot(
          index: 1,
          isActive: _step == 0,
          isCompleted: _step > 0,
          isDark: isDark,
        ),
        Container(
          width: 32,
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(1),
            color: _step > 0
                ? AppColors.primary
                : (isDark
                    ? AppColors.darkSurfaceVariant
                    : AppColors.surfaceVariant),
          ),
        ),
        _StepDot(
          index: 2,
          isActive: _step == 1,
          isCompleted: false,
          isDark: isDark,
        ),
      ],
    );
  }

  // ── Header ───────────────────────────────────

  Widget _buildHeader(bool isDark) {
    final titles = ['Create Account', 'Verify & Complete'];
    final subtitles = [
      "Enter your email to receive a one-time password",
      "Enter the OTP we sent to ${_emailController.text.isNotEmpty ? _emailController.text : 'your email'} along with your details",
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon badge
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppColors.heroGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withAlpha(77),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(
            _step == 0
                ? Icons.person_add_alt_1_rounded
                : Icons.verified_user_rounded,
            size: 28,
            color: Colors.white,
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        Text(
          titles[_step],
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          subtitles[_step],
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ── Step 0 form: email ───────────────────────

  Widget _buildStep0Form(bool isDark) {
    return Form(
      key: _step0FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FieldLabel(label: 'Email Address', isDark: isDark),
          const SizedBox(height: AppSpacing.xs),
          AppTextField(
            controller: _emailController,
            focusNode: _emailFocus,
            hint: 'you@example.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            validator: _validateEmail,
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
          const SizedBox(height: AppSpacing.md),
          InfoBanner(
            message:
                'A 6-digit verification code will be sent to this email address.',
            variant: BadgeVariant.info,
            icon: Icons.info_outline_rounded,
          ),
        ],
      ),
    );
  }

  // ── Step 1 form: OTP + user details ──────────

  Widget _buildStep1Form(bool isDark) {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── OTP ──────────────────────────────────
          _FieldLabel(label: 'One-Time Password', isDark: isDark),
          const SizedBox(height: AppSpacing.xs),
          AppTextField(
            controller: _otpController,
            focusNode: _otpFocus,
            hint: '6-digit OTP',
            prefixIcon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            maxLength: 6,
            validator: _validateOtp,
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Username ─────────────────────────────
          _FieldLabel(label: 'Username', isDark: isDark),
          const SizedBox(height: AppSpacing.xs),
          AppTextField(
            controller: _usernameController,
            focusNode: _usernameFocus,
            hint: 'e.g. john_doe',
            prefixIcon: Icons.person_outline_rounded,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            validator: _validateUsername,
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Password ─────────────────────────────
          _FieldLabel(label: 'Password', isDark: isDark),
          const SizedBox(height: AppSpacing.xs),
          AppTextField(
            controller: _passwordController,
            focusNode: _passwordFocus,
            hint: 'Min 8 chars, 1 uppercase, 1 number',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.next,
            validator: _validatePassword,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            suffix: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              tooltip: _obscurePassword ? 'Show' : 'Hide',
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Confirm password ─────────────────────
          _FieldLabel(label: 'Confirm Password', isDark: isDark),
          const SizedBox(height: AppSpacing.xs),
          AppTextField(
            controller: _password2Controller,
            focusNode: _password2Focus,
            hint: 'Repeat your password',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword2,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            validator: _validatePassword2,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            suffix: IconButton(
              icon: Icon(
                _obscurePassword2
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword2 = !_obscurePassword2),
              tooltip: _obscurePassword2 ? 'Show' : 'Hide',
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Email (read-only recap) ───────────────
          _FieldLabel(label: 'Email', isDark: isDark),
          const SizedBox(height: AppSpacing.xs),
          AppTextField(
            controller: _emailController,
            prefixIcon: Icons.email_outlined,
            readOnly: true,
            enabled: false,
            suffix: Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // ── Action button ────────────────────────────

  Widget _buildActionButton(bool isDark) {
    if (_step == 0) {
      return GradientButton(
        label: 'Send OTP',
        icon: Icons.send_rounded,
        isLoading: _isSubmitting,
        onPressed: _isSubmitting ? null : _sendOtp,
      );
    }
    return GradientButton(
      label: 'Create Account',
      icon: Icons.check_rounded,
      isLoading: _isSubmitting,
      onPressed: _isSubmitting ? null : _register,
      gradient: const [Color(0xFF5C6BC0), Color(0xFF26C6DA)],
    );
  }

  // ── Footer helpers ───────────────────────────

  Widget _buildLoginPrompt(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account?',
          style: TextStyle(
            fontSize: 14,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Sign in',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResendOtpHint(bool isDark) {
    return Center(
      child: TextButton.icon(
        onPressed: _isSubmitting ? null : _goBackToStep0,
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: const Text(
          'Resend OTP / change email',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        style: TextButton.styleFrom(
          foregroundColor: isDark
              ? AppColors.darkTextSecondary
              : AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  _StepDot
// ─────────────────────────────────────────────

class _StepDot extends StatelessWidget {
  final int index;
  final bool isActive;
  final bool isCompleted;
  final bool isDark;

  const _StepDot({
    required this.index,
    required this.isActive,
    required this.isCompleted,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    if (isCompleted) {
      bg = AppColors.success;
      fg = Colors.white;
    } else if (isActive) {
      bg = AppColors.primary;
      fg = Colors.white;
    } else {
      bg = isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant;
      fg = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.primary.withAlpha(77),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: isCompleted
          ? Icon(Icons.check_rounded, color: fg, size: 16)
          : Text(
              '$index',
              style: TextStyle(
                color: fg,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────
//  _FieldLabel
// ─────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool isDark;

  const _FieldLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark
            ? AppColors.darkTextSecondary
            : AppColors.textSecondary,
        letterSpacing: 0.2,
      ),
    );
  }
}
