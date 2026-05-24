import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/routes/app_router.dart';
import '../../../data/models/user_model.dart';
import '../../../data/providers/auth_notifier.dart';
import '../../widgets/hero_button.dart';
import '../../widgets/yamada_logo.dart';

/// Login Page - Integrates with Flask backend API
/// Matches Next.js client login behavior with same error messages and flow
class LoginPage extends ConsumerStatefulWidget {
  final UserRole role;

  const LoginPage({
    super.key,
    this.role = UserRole.buyer,
  });

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _roleTitle {
    switch (widget.role) {
      case UserRole.buyer:
        return 'Welcome Back'; // Generic for customer app
      case UserRole.seller:
        return 'Seller Portal';
      case UserRole.rider:
        return 'Rider Portal';
      case UserRole.admin:
        return 'Admin Portal';
    }
  }

  String get _roleDescription {
    switch (widget.role) {
      case UserRole.buyer:
        return 'Sign in to continue shopping'; // Generic customer message
      case UserRole.seller:
        return 'Manage your shop and products';
      case UserRole.rider:
        return 'Manage your deliveries';
      case UserRole.admin:
        return 'Manage the platform';
    }
  }

  Color get _roleColor {
    switch (widget.role) {
      case UserRole.buyer:
        return AppColors.primary;
      case UserRole.seller:
      case UserRole.rider:
        return AppColors.secondary;
      case UserRole.admin:
        return AppColors.destructive;
    }
  }

  String get _registerRoute {
    switch (widget.role) {
      case UserRole.buyer:
        return AppRouter.registerBuyer;
      case UserRole.seller:
        return AppRouter.registerSeller;
      case UserRole.rider:
        return AppRouter.registerRider;
      case UserRole.admin:
        return AppRouter.login;
    }
  }

  String get _registerText {
    switch (widget.role) {
      case UserRole.buyer:
        return 'Don\'t have an account?';
      case UserRole.seller:
        return 'Want to sell on YAMADA?';
      case UserRole.rider:
        return 'Want to deliver for YAMADA?';
      case UserRole.admin:
        return '';
    }
  }

  String get _registerLinkText {
    switch (widget.role) {
      case UserRole.buyer:
        return 'Create account';
      case UserRole.seller:
        return 'Apply as seller';
      case UserRole.rider:
        return 'Apply as rider';
      case UserRole.admin:
        return '';
    }
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      final success = await ref.read(authProvider.notifier).login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: widget.role,
      );

      if (mounted) {
        setState(() => _isLoading = false);

        if (success) {
          // Get the correct dashboard route based on user role
          final dashboardRoute = ref.read(authProvider.notifier).getDashboardRoute();

          // Show buttonless success dialog — auto-dismisses after 2s then navigates
          await AlertService.showAutoSuccess(
            context: context,
            title: 'Success',
            message: 'Successfully logged in!',
            onDismiss: () {
              context.go(dashboardRoute);
            },
          );
        } else {
          // Error is handled by the provider and shown in UI
          final error = ref.read(authProvider).error;
          if (error != null) {
            AlertService.showSnackBar(
              context: context,
              message: error,
              variant: AlertVariant.error,
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authError = ref.watch(authErrorProvider);
    final pendingApproval = GoRouterState.of(context)
            .uri
            .queryParameters['registered'] ==
        'pending_approval';

    // Show error in snackbar when it changes
    if (authError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AlertService.showSnackBar(
          context: context,
          message: authError,
          variant: AlertVariant.error,
        );
        ref.read(authProvider.notifier).clearError();
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.pushReplacement(AppRouter.landing);
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, isDark),
                  const SizedBox(height: 32),
                  if (pendingApproval && widget.role == UserRole.buyer) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.processing.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.processing.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        'Registration submitted. Please sign in after an admin approves your account. You can browse but cannot checkout until verified.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.darkForeground
                                  : AppColors.charcoal,
                            ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // Only show role banner for non-buyer roles
                  if (widget.role != UserRole.buyer) ...[
                    _buildRoleBanner(context),
                    const SizedBox(height: 32),
                  ],
                  // Show logo and welcome text for buyer
                  if (widget.role == UserRole.buyer) ...[
                    _buildWelcomeSection(context, isDark),
                    const SizedBox(height: 32),
                  ],
                  _buildForm(context, isDark),
                  const SizedBox(height: 24),
                  _buildRegisterLink(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => context.pushReplacement(AppRouter.landing),
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? AppColors.darkForeground : AppColors.charcoal,
          ),
        ),
        Row(
          children: [
            const YamadaLogo(height: 40),
            const SizedBox(width: 12),
            Text(
              'YAMADA',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkForeground
                        : AppColors.charcoal,
                  ),
            ),
          ],
        ),
        IconButton(
          onPressed: () {
            // Toggle theme
          },
          icon: Icon(
            isDark ? Icons.light_mode : Icons.dark_mode,
            color: isDark ? AppColors.darkForeground : AppColors.charcoal,
          ),
        ),
      ],
    ).animate()
      .fadeIn(duration: 600.ms);
  }

  Widget _buildWelcomeSection(BuildContext context, bool isDark) {
    return Column(
      children: [
        const Center(child: YamadaLogo(height: 80)),
        const SizedBox(height: 24),
        // Welcome Text
        Text(
          'Welcome Back',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.charcoal,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to continue shopping',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.mutedForeground,
              ),
        ),
      ],
    );
  }

  Widget _buildRoleBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _roleColor,
            _roleColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _roleTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _roleDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
          ),
        ],
      ),
    ).animate()
      .fadeIn(duration: 600.ms, delay: 100.ms);
  }

  Widget _buildForm(BuildContext context, bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkForeground : AppColors.charcoal,
                ),
          ).animate()
            .fadeIn(duration: 600.ms, delay: 200.ms),
          const SizedBox(height: 8),
          Text(
            'Enter your credentials to access your account',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.mutedForeground : AppColors.warmGray,
                ),
          ).animate()
            .fadeIn(duration: 600.ms, delay: 250.ms),
          const SizedBox(height: 24),

          // Email Field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !_isLoading,
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'you@example.com',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Email is required';
              }
              if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+').hasMatch(value)) {
                return 'Invalid email format';
              }
              return null;
            },
          ).animate()
            .fadeIn(duration: 600.ms, delay: 300.ms),
          const SizedBox(height: 16),

          // Password Field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            enabled: !_isLoading,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password is required';
              }
              return null;
            },
          ).animate()
            .fadeIn(duration: 600.ms, delay: 350.ms),
          const SizedBox(height: 8),

          // Forgot Password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push(AppRouter.forgotPassword),
              child: const Text('Forgot password?'),
            ),
          ).animate()
            .fadeIn(duration: 600.ms, delay: 400.ms),
          const SizedBox(height: 24),

          // Login Button
          HeroButton(
            onPressed: _isLoading ? null : _handleLogin,
            text: _isLoading ? 'Signing in...' : 'Sign In',
            icon: _isLoading ? null : Icons.arrow_forward,
            isLoading: _isLoading,
            isSecondary: widget.role != UserRole.buyer,
          ).animate()
            .fadeIn(duration: 600.ms, delay: 450.ms),
          const SizedBox(height: 24),

          // Divider - Or continue with
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Or continue with',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
              ),
            ],
          ).animate()
            .fadeIn(duration: 600.ms, delay: 500.ms),
          const SizedBox(height: 24),

          // Social Login Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SocialLoginButton(
                icon: Icons.g_mobiledata,
                onTap: () {
                  // Google sign in (placeholder)
                  AlertService.showSnackBar(
                    context: context,
                    message: 'Google sign in coming soon',
                    variant: AlertVariant.info,
                  );
                },
              ),
              const SizedBox(width: 16),
              _SocialLoginButton(
                icon: Icons.facebook,
                onTap: () {
                  // Facebook sign in (placeholder)
                  AlertService.showSnackBar(
                    context: context,
                    message: 'Facebook sign in coming soon',
                    variant: AlertVariant.info,
                  );
                },
              ),
              const SizedBox(width: 16),
              _SocialLoginButton(
                icon: Icons.apple,
                onTap: () {
                  // Apple sign in (placeholder)
                  AlertService.showSnackBar(
                    context: context,
                    message: 'Apple sign in coming soon',
                    variant: AlertVariant.info,
                  );
                },
              ),
            ],
          ).animate()
            .fadeIn(duration: 600.ms, delay: 550.ms),
        ],
      ),
    );
  }

  Widget _buildRegisterLink(BuildContext context) {
    if (widget.role == UserRole.admin) return const SizedBox.shrink();

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _registerText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
              ),
              TextButton(
                onPressed: () => context.push(_registerRoute),
                child: Text(_registerLinkText),
              ),
            ],
          ),
          // Partner/Seller link for those interested in selling/delivering
          if (widget.role == UserRole.buyer)
            TextButton.icon(
              onPressed: () => context.push(AppRouter.landing),
              icon: const Icon(Icons.storefront_outlined, size: 18),
              label: const Text(
                'Sell or Deliver with us',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    ).animate()
      .fadeIn(duration: 600.ms, delay: 600.ms);
  }

  Widget _SocialLoginButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isDark ? AppColors.darkCard : AppColors.card,
        ),
        child: Icon(
          icon,
          size: 24,
          color: isDark ? AppColors.darkForeground : AppColors.charcoal,
        ),
      ),
    );
  }
}
