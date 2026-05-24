import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Alert/Notification service that replicates the Next.js client's
/// SweetAlert behavior with same messages and flow
class AlertService {
  /// Show a success alert (matches "Registration Successful" in Next.js)
  static Future<void> showSuccess({
    required BuildContext context,
    required String title,
    required String message,
    String confirmButtonText = 'OK',
    VoidCallback? onConfirm,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ThemedAlertDialog(
        icon: Icons.check_circle_outline,
        iconColor: AppColors.delivered,
        title: title,
        message: message,
        accentColor: AppColors.delivered,
        actions: [
          _DialogButton(
            text: confirmButtonText,
            color: AppColors.delivered,
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm?.call();
            },
          ),
        ],
      ),
    );
  }

  /// Show a buttonless success dialog that auto-dismisses after [duration]
  /// then fires [onDismiss]. Used for login success — no tap required.
  static Future<void> showAutoSuccess({
    required BuildContext context,
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 2),
    VoidCallback? onDismiss,
  }) async {
    // Auto-close after [duration]
    Future.delayed(duration, () {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        onDismiss?.call();
      }
    });

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ThemedAlertDialog(
        icon: Icons.check_circle_outline,
        iconColor: AppColors.delivered,
        title: title,
        message: message,
        accentColor: AppColors.delivered,
        actions: const [], // no buttons
      ),
    );
  }

  /// Show an error alert
  static Future<void> showError({
    required BuildContext context,
    String title = 'Error',
    required String message,
    String confirmButtonText = 'OK',
  }) async {
    return showDialog(
      context: context,
      builder: (context) => _ThemedAlertDialog(
        icon: Icons.error_outline,
        iconColor: AppColors.destructive,
        title: title,
        message: message,
        accentColor: AppColors.destructive,
        actions: [
          _DialogButton(
            text: confirmButtonText,
            color: AppColors.destructive,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// Show a warning alert
  static Future<void> showWarning({
    required BuildContext context,
    String title = 'Warning',
    required String message,
    String confirmButtonText = 'OK',
  }) async {
    return showDialog(
      context: context,
      builder: (context) => _ThemedAlertDialog(
        icon: Icons.warning_amber_outlined,
        iconColor: AppColors.pending,
        title: title,
        message: message,
        accentColor: AppColors.pending,
        actions: [
          _DialogButton(
            text: confirmButtonText,
            color: AppColors.pending,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// Show an info alert
  static Future<void> showInfo({
    required BuildContext context,
    String title = 'Notice',
    required String message,
    String confirmButtonText = 'OK',
  }) async {
    return showDialog(
      context: context,
      builder: (context) => _ThemedAlertDialog(
        icon: Icons.info_outline,
        iconColor: AppColors.processing,
        title: title,
        message: message,
        accentColor: AppColors.processing,
        actions: [
          _DialogButton(
            text: confirmButtonText,
            color: AppColors.processing,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// Show a confirmation dialog with Yes/No options
  static Future<bool> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Yes',
    String cancelText = 'No',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _ThemedAlertDialog(
        icon: Icons.help_outline,
        iconColor: AppColors.rosewood,
        title: title,
        message: message,
        accentColor: AppColors.rosewood,
        actions: [
          _DialogButton(
            text: cancelText,
            color: AppColors.mutedForeground,
            isOutlined: true,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          _DialogButton(
            text: confirmText,
            color: AppColors.rosewood,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Show a top toast notification — appears at the TOP via Overlay,
  /// auto-dismisses after [duration], tap to dismiss early.
  static void showSnackBar({
    required BuildContext context,
    required String message,
    AlertVariant variant = AlertVariant.info,
    Duration duration = const Duration(seconds: 2),
  }) {
    final color = _getColorForVariant(variant);
    final icon = _getIconForVariant(variant);

    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _TopToast(
        message: message,
        color: color,
        icon: icon,
        duration: duration,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }

  /// Show a loading dialog
  static Future<void> showLoading({
    required BuildContext context,
    String message = 'Loading...',
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.rosewood,
                  ),
                ),
                const SizedBox(width: 20),
                Text(
                  message,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Hide the loading dialog
  static void hideLoading(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  /// Helper methods
  static IconData _getIconForVariant(AlertVariant variant) {
    switch (variant) {
      case AlertVariant.success:
        return Icons.check_circle;
      case AlertVariant.error:
        return Icons.error;
      case AlertVariant.warning:
        return Icons.warning;
      case AlertVariant.info:
        return Icons.info;
    }
  }

  static Color _getColorForVariant(AlertVariant variant) {
    switch (variant) {
      case AlertVariant.success:
        return AppColors.delivered;       // #22C55E
      case AlertVariant.error:
        return AppColors.destructive;     // #E53E3E
      case AlertVariant.warning:
        return AppColors.pending;         // #F59E0B
      case AlertVariant.info:
        return AppColors.processing;      // #3B82F6
    }
  }
}

enum AlertVariant { success, error, warning, info }

// ---------------------------------------------------------------------------
// Internal themed dialog widget
// ---------------------------------------------------------------------------

class _ThemedAlertDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color accentColor;
  final String title;
  final String message;
  final List<Widget> actions;

  const _ThemedAlertDialog({
    required this.icon,
    required this.iconColor,
    required this.accentColor,
    required this.title,
    required this.message,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkCard : Colors.white;
    final titleColor = isDark ? AppColors.darkForeground : AppColors.charcoal;
    final bodyColor = isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Accent top bar
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon circle
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 36),
                ),
                const SizedBox(height: 16),
                // Title
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 8),
                // Message
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: bodyColor,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                // Actions — omitted when empty (auto-dismiss dialogs)
                if (actions.isNotEmpty)
                  Row(
                    mainAxisAlignment: actions.length == 1
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.spaceBetween,
                    children: actions
                        .map((a) => Expanded(child: a))
                        .toList()
                        .expand((w) => [w, if (actions.length > 1) const SizedBox(width: 12)])
                        .toList()
                      ..removeLast(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal dialog button widget
// ---------------------------------------------------------------------------

class _DialogButton extends StatelessWidget {
  final String text;
  final Color color;
  final bool isOutlined;
  final VoidCallback onPressed;

  const _DialogButton({
    required this.text,
    required this.color,
    required this.onPressed,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          minimumSize: const Size(double.infinity, 44),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        minimumSize: const Size(double.infinity, 44),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top toast overlay widget — always visible at the top of the screen
// ---------------------------------------------------------------------------

class _TopToast extends StatefulWidget {
  final String message;
  final Color color;
  final IconData icon;
  final Duration duration;
  final VoidCallback onDismiss;

  const _TopToast({
    required this.message,
    required this.color,
    required this.icon,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<_TopToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    // Slide in
    _controller.forward();

    // Auto-dismiss after duration
    Future.delayed(widget.duration, _dismiss);
  }

  void _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        widget.icon,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.close,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Extension to easily show alerts from any BuildContext
extension AlertServiceExtension on BuildContext {
  void showAlert({
    required String message,
    AlertVariant variant = AlertVariant.info,
  }) {
    AlertService.showSnackBar(
      context: this,
      message: message,
      variant: variant,
    );
  }

  void showSuccess(String message) {
    AlertService.showSnackBar(
      context: this,
      message: message,
      variant: AlertVariant.success,
    );
  }

  void showError(String message) {
    AlertService.showSnackBar(
      context: this,
      message: message,
      variant: AlertVariant.error,
    );
  }
}
