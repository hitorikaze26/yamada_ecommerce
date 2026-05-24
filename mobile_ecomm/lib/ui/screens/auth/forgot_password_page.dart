import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/auth_api.dart';
import '../../widgets/hero_button.dart';
import '../../widgets/yamada_logo.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _submitted = false;
  String? _accountEmail;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      AlertService.showSnackBar(
        context: context,
        message: 'Please enter your email address',
        variant: AlertVariant.error,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await AuthApi.forgotPassword(
        email: email,
        channel: 'email',
      );
      if (mounted) {
        setState(() {
          _submitted = true;
          _accountEmail = result['email'] as String? ?? email;
        });
      }
    } catch (e) {
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: e.toString().replaceFirst('Exception: ', ''),
          variant: AlertVariant.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const YamadaLogo(height: 32),
            const SizedBox(width: 8),
            const Text('YAMADA'),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _submitted ? _buildSuccess(context, isDark) : _buildForm(context, isDark),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.lock_outline, size: 48, color: AppColors.primary),
        const SizedBox(height: 16),
        Text(
          'Forgot Password?',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your email to receive a 6-digit reset code.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.mutedForeground,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.muted.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.sms_outlined, size: 18, color: AppColors.mutedForeground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SMS reset is coming soon. Please use email for now.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Email address',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 32),
        HeroButton(
          onPressed: _isLoading ? null : _submit,
          text: _isLoading ? 'Sending...' : 'Send 6-digit code',
          isLoading: _isLoading,
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => context.go('${AppRouter.login}?role=buyer'),
          child: const Text('Back to sign in'),
        ),
      ],
    );
  }

  Widget _buildSuccess(BuildContext context, bool isDark) {
    final destination = _emailController.text.trim();
    final resetEmail = _accountEmail ?? destination;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.mark_email_read_outlined, size: 48, color: AppColors.primary),
        const SizedBox(height: 16),
        Text(
          'Check your email',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a 6-digit PIN to $destination. Enter it on the next screen to reset your password.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.mutedForeground,
              ),
        ),
        const SizedBox(height: 32),
        HeroButton(
          onPressed: resetEmail.isEmpty
              ? null
              : () => context.push(
                    '${AppRouter.resetPin}?email=${Uri.encodeComponent(resetEmail)}&channel=email',
                  ),
          text: 'Enter PIN',
        ),
      ],
    );
  }
}
