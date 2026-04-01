import 'package:flutter/material.dart';
import 'app_theme.dart';

// ─────────────────────────────────────────────
//  GradientButton
// ─────────────────────────────────────────────

class GradientButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final List<Color>? gradient;
  final IconData? icon;
  final double? width;
  final double height;
  final double borderRadius;

  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.gradient,
    this.icon,
    this.width,
    this.height = AppSpacing.buttonHeight,
    this.borderRadius = AppSpacing.buttonRadius,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isDisabled => widget.onPressed == null || widget.isLoading;

  @override
  Widget build(BuildContext context) {
    final gradient = widget.gradient ?? AppColors.primaryGradient;

    return GestureDetector(
      onTapDown: _isDisabled ? null : (_) => _controller.forward(),
      onTapUp: _isDisabled ? null : (_) => _controller.reverse(),
      onTapCancel: _isDisabled ? null : () => _controller.reverse(),
      onTap: _isDisabled ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _isDisabled ? 0.6 : 1.0,
          child: Container(
            width: widget.width ?? double.infinity,
            height: widget.height,
            decoration: BoxDecoration(
              gradient: _isDisabled
                  ? null
                  : LinearGradient(
                      colors: gradient,
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
              color: _isDisabled ? AppColors.textHint : null,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: _isDisabled
                  ? null
                  : [
                      BoxShadow(
                        color: gradient.first.withAlpha(77),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            alignment: Alignment.center,
            child: widget.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SecondaryButton (outlined + gradient text)
// ─────────────────────────────────────────────

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double height;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.height = AppSpacing.buttonHeight,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: OutlinedButton(
        onPressed: isDisabled ? null : onPressed,
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  AppCard
// ─────────────────────────────────────────────

class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double borderRadius;
  final List<BoxShadow>? boxShadow;
  final Border? border;
  final Gradient? gradient;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.color,
    this.borderRadius = AppSpacing.cardRadius,
    this.boxShadow,
    this.border,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final defaultBorder = Border.all(
      color: isDark ? const Color(0xFF353850) : const Color(0xFFEEEFF8),
      width: 1,
    );

    final container = Container(
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? defaultColor) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ?? defaultBorder,
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: isDark
                    ? Colors.black.withAlpha(51)
                    : const Color(0x0F5C6BC0),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: AppColors.primary.withAlpha(26),
          highlightColor: AppColors.primary.withAlpha(13),
          child: container,
        ),
      );
    }

    return container;
  }
}

// ─────────────────────────────────────────────
//  GradientCard (hero-style card with gradient)
// ─────────────────────────────────────────────

class GradientCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final List<Color>? gradient;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const GradientCard({
    super.key,
    required this.child,
    this.onTap,
    this.gradient,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.borderRadius = AppSpacing.cardRadius,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: padding,
      borderRadius: borderRadius,
      border: Border.all(color: Colors.transparent),
      boxShadow: [
        BoxShadow(
          color: (gradient ?? AppColors.primaryGradient)
              .first
              .withAlpha(77),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
      gradient: LinearGradient(
        colors: gradient ?? AppColors.primaryGradient,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────
//  StatusBadge
// ─────────────────────────────────────────────

enum BadgeVariant { success, warning, error, info, primary, neutral }

class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeVariant variant;
  final IconData? icon;
  final bool compact;

  const StatusBadge({
    super.key,
    required this.label,
    this.variant = BadgeVariant.primary,
    this.icon,
    this.compact = false,
  });

  factory StatusBadge.rag({bool usedRag = true}) {
    return StatusBadge(
      label: usedRag ? 'Grounded' : 'General AI',
      variant: usedRag ? BadgeVariant.success : BadgeVariant.warning,
      icon: usedRag ? Icons.verified_rounded : Icons.auto_awesome_rounded,
    );
  }

  factory StatusBadge.difficulty(String difficulty) {
    BadgeVariant variant;
    switch (difficulty.toLowerCase()) {
      case 'easy':
        variant = BadgeVariant.success;
        break;
      case 'hard':
        variant = BadgeVariant.error;
        break;
      default:
        variant = BadgeVariant.warning;
    }
    return StatusBadge(
      label: difficulty[0].toUpperCase() + difficulty.substring(1),
      variant: variant,
      icon: Icons.bar_chart_rounded,
    );
  }

  _BadgeColors _resolveColors(bool isDark) {
    switch (variant) {
      case BadgeVariant.success:
        return _BadgeColors(
          background: isDark
              ? AppColors.success.withAlpha(38)
              : AppColors.successLight,
          foreground: AppColors.success,
        );
      case BadgeVariant.warning:
        return _BadgeColors(
          background: isDark
              ? AppColors.warning.withAlpha(38)
              : AppColors.warningLight,
          foreground: AppColors.warning,
        );
      case BadgeVariant.error:
        return _BadgeColors(
          background: isDark
              ? AppColors.error.withAlpha(38)
              : AppColors.errorLight,
          foreground: AppColors.error,
        );
      case BadgeVariant.info:
        return _BadgeColors(
          background: isDark
              ? AppColors.info.withAlpha(38)
              : AppColors.infoLight,
          foreground: AppColors.info,
        );
      case BadgeVariant.primary:
        return _BadgeColors(
          background: isDark
              ? AppColors.primary.withAlpha(51)
              : AppColors.surfaceVariant,
          foreground: isDark ? AppColors.primaryLight : AppColors.primary,
        );
      case BadgeVariant.neutral:
        return _BadgeColors(
          background: isDark
              ? AppColors.darkSurfaceVariant
              : AppColors.surfaceVariant,
          foreground: isDark
              ? AppColors.darkTextSecondary
              : AppColors.textSecondary,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _resolveColors(isDark);
    final iconSize = compact ? 12.0 : 13.0;
    final fontSize = compact ? 11.0 : 12.0;
    final hPadding = compact ? 8.0 : 10.0;
    final vPadding = compact ? 3.0 : 5.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: colors.foreground),
            SizedBox(width: compact ? 3 : 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: colors.foreground,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeColors {
  final Color background;
  final Color foreground;
  const _BadgeColors({required this.background, required this.foreground});
}

// ─────────────────────────────────────────────
//  LoadingOverlay
// ─────────────────────────────────────────────

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;
  final Color? barrierColor;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.barrierColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          AnimatedOpacity(
            opacity: isLoading ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              color: barrierColor ?? Colors.black.withAlpha(102),
              alignment: Alignment.center,
              child: _LoadingCard(message: message),
            ),
          ),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final String? message;
  const _LoadingCard({this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(51),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primary,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              message!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  ShimmerLoader (skeleton loading)
// ─────────────────────────────────────────────

class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? AppColors.darkSurfaceVariant : const Color(0xFFEEEFF8);
    final highlightColor = isDark ? AppColors.darkSurface : Colors.white;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: [
                (_animation.value - 1).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 1).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  AppTextField
// ─────────────────────────────────────────────

class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final IconData? prefixIcon;
  final Widget? suffix;
  final int maxLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool enabled;
  final FocusNode? focusNode;
  final String? Function(String?)? validator;
  final AutovalidateMode autovalidateMode;

  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.prefixIcon,
    this.suffix,
    this.maxLines = 1,
    this.maxLength,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.enabled = true,
    this.focusNode,
    this.validator,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: maxLines,
      maxLength: maxLength,
      onChanged: onChanged,
      onTap: onTap,
      readOnly: readOnly,
      enabled: enabled,
      focusNode: focusNode,
      validator: validator,
      autovalidateMode: autovalidateMode,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        errorText: errorText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffix,
        counterText: '',
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SectionHeader
// ─────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  EmptyState
// ─────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.primary.withAlpha(38)
                    : AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: isDark ? AppColors.primaryLight : AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  ErrorState
// ─────────────────────────────────────────────

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try Again',
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Something went wrong',
      subtitle: message,
      action: onRetry != null
          ? SizedBox(
              width: 160,
              child: GradientButton(
                label: retryLabel,
                gradient: const [AppColors.error, Color(0xFFE53935)],
                onPressed: onRetry,
                height: 44,
              ),
            )
          : null,
    );
  }
}

// ─────────────────────────────────────────────
//  InfoBanner
// ─────────────────────────────────────────────

class InfoBanner extends StatelessWidget {
  final String message;
  final BadgeVariant variant;
  final IconData? icon;
  final VoidCallback? onDismiss;

  const InfoBanner({
    super.key,
    required this.message,
    this.variant = BadgeVariant.info,
    this.icon,
    this.onDismiss,
  });

  Color _bgColor(bool isDark) {
    switch (variant) {
      case BadgeVariant.success:
        return isDark
            ? AppColors.success.withAlpha(38)
            : AppColors.successLight;
      case BadgeVariant.warning:
        return isDark
            ? AppColors.warning.withAlpha(38)
            : AppColors.warningLight;
      case BadgeVariant.error:
        return isDark ? AppColors.error.withAlpha(38) : AppColors.errorLight;
      case BadgeVariant.info:
        return isDark ? AppColors.info.withAlpha(38) : AppColors.infoLight;
      default:
        return isDark ? AppColors.primary.withAlpha(38) : AppColors.surfaceVariant;
    }
  }

  Color _fgColor(bool isDark) {
    switch (variant) {
      case BadgeVariant.success:
        return AppColors.success;
      case BadgeVariant.warning:
        return AppColors.warning;
      case BadgeVariant.error:
        return AppColors.error;
      case BadgeVariant.info:
        return AppColors.info;
      default:
        return isDark ? AppColors.primaryLight : AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _bgColor(isDark);
    final fg = _fgColor(isDark);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
      ),
      child: Row(
        children: [
          Icon(icon ?? Icons.info_outline_rounded, size: 18, color: fg),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: fg,
                height: 1.4,
              ),
            ),
          ),
          if (onDismiss != null)
            GestureDetector(
              onTap: onDismiss,
              child: Icon(Icons.close_rounded, size: 16, color: fg),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  AppDivider
// ─────────────────────────────────────────────

class AppDivider extends StatelessWidget {
  final String? label;
  final double indent;

  const AppDivider({super.key, this.label, this.indent = 0});

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return Divider(indent: indent, endIndent: indent);
    }

    return Row(
      children: [
        Expanded(child: Divider(indent: indent)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            label!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(child: Divider(endIndent: indent)),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  AvatarWidget
// ─────────────────────────────────────────────

class AvatarWidget extends StatelessWidget {
  final String name;
  final double radius;
  final List<Color>? gradient;

  const AvatarWidget({
    super.key,
    required this.name,
    this.radius = AppSpacing.avatarRadius,
    this.gradient,
  });

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradient ?? AppColors.primaryGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  AnimatedCounter
// ─────────────────────────
