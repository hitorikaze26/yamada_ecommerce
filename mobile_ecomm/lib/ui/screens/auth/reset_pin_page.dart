import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/auth_api.dart';
import '../../widgets/hero_button.dart';
import '../../widgets/pin_input_row.dart';
import '../../widgets/yamada_logo.dart';

class ResetPinPage extends StatefulWidget {
  final String email;
  final String channel;

  const ResetPinPage({
    super.key,
    required this.email,
    this.channel = 'email',
  });

  @override
  State<ResetPinPage> createState() => _ResetPinPageState();
}

class _ResetPinPageState extends State<ResetPinPage> {
  int _step = 0;
  String _pin = '';
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _verifyPin(String pin) async {
    setState(() => _isLoading = true);
    try {
      await AuthApi.verifyPin(email: widget.email, pin: pin);
      if (mounted) {
        setState(() {
          _pin = pin;
          _step = 1;
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

  Future<void> _resetPassword() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    if (password.length < 8) {
      AlertService.showSnackBar(
        context: context,
        message: 'Password must be at least 8 characters',
        variant: AlertVariant.error,
      );
      return;
    }
    if (password != confirm) {
      AlertService.showSnackBar(
        context: context,
        message: 'Passwords do not match',
        variant: AlertVariant.error,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthApi.resetPassword(
        email: widget.email,
        pin: _pin,
        newPassword: password,
      );
      if (mounted) {
        await AlertService.showAutoSuccess(
          context: context,
          title: 'Password updated',
          message: 'You can now sign in with your new password.',
          onDismiss: () => context.go('${AppRouter.login}?role=buyer'),
        );
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
            const Text('Reset password'),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _step == 0 ? _buildPinStep(context) : _buildPasswordStep(context),
        ),
      ),
    );
  }

  Widget _buildPinStep(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSms = widget.channel == 'sms';
    final fg = isDark ? AppColors.darkForeground : AppColors.charcoal;
    final muted = isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSms ? Icons.sms_outlined : Icons.mark_email_read_outlined,
                  size: 28,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Enter 6-digit PIN',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: fg,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                isSms
                    ? 'Enter the code sent to your phone.\nAccount: ${widget.email}'
                    : 'Enter the code sent to\n${widget.email}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: muted,
                      height: 1.4,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        PinInputRow(
          enabled: !_isLoading,
          onComplete: _verifyPin,
        ),
        const SizedBox(height: 12),
        Text(
          'Tap each box to enter one digit',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
        ),
        if (_isLoading) ...[
          const SizedBox(height: 28),
          Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Verifying PIN…',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ],
    );
  }

  Widget _buildPasswordStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'New password',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _passwordController,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: 'New password',
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmController,
          obscureText: _obscure,
          decoration: const InputDecoration(labelText: 'Confirm password'),
        ),
        const SizedBox(height: 32),
        HeroButton(
          onPressed: _isLoading ? null : _resetPassword,
          text: _isLoading ? 'Saving...' : 'Reset password',
          isLoading: _isLoading,
        ),
      ],
    );
  }
}
