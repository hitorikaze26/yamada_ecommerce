import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_animations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/auth_api.dart';
import 'pin_input_row.dart';

/// Email verification widget matching Next.js client EmailVerification component.
///
/// Flow:
/// 1. Auto-sends 6-digit code to [email] on mount
/// 2. User enters 6 digits into [PinInputRow]
/// 3. On complete, verifies code via [AuthApi.verifyEmailCode]
/// 4. On success → calls [onVerified]
/// 5. On failure → clears input, shows error, user can retry or "Resend code"
class EmailVerificationWidget extends StatefulWidget {
  final String email;
  final VoidCallback onVerified;

  const EmailVerificationWidget({
    super.key,
    required this.email,
    required this.onVerified,
  });

  @override
  State<EmailVerificationWidget> createState() =>
      _EmailVerificationWidgetState();
}

class _EmailVerificationWidgetState extends State<EmailVerificationWidget> {
  bool _isSending = false;
  bool _isVerifying = false;
  String? _error;
  int _resetKey = 0;

  @override
  void initState() {
    super.initState();
    _sendCode();
  }

  Future<void> _sendCode() async {
    setState(() {
      _isSending = true;
      _error = null;
    });
    try {
      await AuthApi.sendVerificationCode(widget.email);
      developer.log('Verification code sent to ${widget.email}',
          name: 'EmailVerification');
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _handleCodeComplete(String code) async {
    setState(() {
      _isVerifying = true;
      _error = null;
    });
    try {
      await AuthApi.verifyEmailCode(email: widget.email, code: code);
      if (mounted) widget.onVerified();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _resetKey++; // Clear pin input on failure (matches web client)
          _isVerifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Email display
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.email_outlined,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.email,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Instruction
        Text(
          'Enter the 6-digit code sent to your email',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),

        // Error
        if (_error != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.destructive.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.destructive, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.destructive,
                    ),
                  ),
                ),
              ],
            ),
          ).animate(effects: AppAnimations.fadeIn(delay: 0)),
          const SizedBox(height: 16),
        ],

        // Pin input
        PinInputRow(
          key: ValueKey('pin_$_resetKey'),
          length: 6,
          onComplete: _isVerifying ? (_) {} : _handleCodeComplete,
          enabled: !_isVerifying,
        ),
        const SizedBox(height: 16),

        // Loading indicator
        if (_isVerifying)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ),

        // Resend button
        TextButton.icon(
          onPressed: (_isSending || _isVerifying) ? null : _sendCode,
          icon: Icon(
            Icons.refresh,
            size: 16,
            color: (_isSending || _isVerifying)
                ? null
                : AppColors.primary,
          ),
          label: Text(
            _isSending ? 'Sending...' : 'Resend code',
          ),
        ),
      ],
    );
  }
}
