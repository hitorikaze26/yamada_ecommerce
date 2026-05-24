import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/auth_notifier.dart';
import '../../../data/services/auth_api.dart';

class SellerSettingsPage extends ConsumerWidget {
  const SellerSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final bg = isDark ? AppColors.darkBackground : AppColors.background;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              size: 20,
              color: isDark ? Colors.white : AppColors.charcoal),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Account Settings',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.charcoal,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('Security', isDark),
            const SizedBox(height: 10),
            _settingsCard(isDark, cardColor, borderColor, [
              _settingsTile(
                context,
                icon: Icons.lock_outline,
                iconColor: AppColors.rosewood,
                title: 'Change Password',
                subtitle: 'Update your account password',
                isDark: isDark,
                onTap: () => _showChangePasswordSheet(context, isDark, borderColor),
              ),
              _divider(borderColor),
              _settingsTile(
                context,
                icon: Icons.email_outlined,
                iconColor: const Color(0xFF3B82F6),
                title: 'Change Email',
                subtitle: 'Update your login email address',
                isDark: isDark,
                onTap: () => _showChangeEmailSheet(context, isDark, borderColor),
              ),
              _divider(borderColor),
              _settingsTile(
                context,
                icon: Icons.phone_outlined,
                iconColor: const Color(0xFF10B981),
                title: 'Contact Information',
                subtitle: 'Update your contact number',
                isDark: isDark,
                onTap: () => _showChangeContactSheet(context, ref, isDark, borderColor),
              ),
            ]),
            const SizedBox(height: 24),
            _sectionLabel('Danger Zone', isDark),
            const SizedBox(height: 10),
            _settingsCard(isDark, cardColor, borderColor, [
              _settingsTile(
                context,
                icon: Icons.delete_forever_outlined,
                iconColor: Colors.red,
                title: 'Delete Account',
                subtitle: 'Permanently remove your account and all data',
                isDark: isDark,
                titleColor: Colors.red,
                onTap: () => _showDeleteAccountSheet(context, ref, isDark, borderColor),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label, bool isDark) => Text(
        label,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : AppColors.mutedForeground),
      );

  Widget _settingsCard(bool isDark, Color cardColor, Color borderColor,
      List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(children: children),
    );
  }

  Widget _settingsTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
    Color? titleColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: titleColor ??
                            (isDark ? Colors.white : AppColors.charcoal))),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.mutedForeground)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios,
              size: 14, color: Colors.grey.shade400),
        ]),
      ),
    );
  }

  Widget _divider(Color borderColor) =>
      Divider(height: 1, color: borderColor, indent: 68);

  // ── Change Password ───────────────────────────────────────────────────────

  void _showChangePasswordSheet(
      BuildContext context, bool isDark, Color borderColor) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool saving = false;
    bool showCurrent = false;
    bool showNew = false;
    bool showConfirm = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => _sheet(
          ctx: ctx,
          isDark: isDark,
          title: 'Change Password',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetField(ctx, 'Current Password', currentCtrl, isDark,
                  borderColor,
                  obscure: !showCurrent,
                  suffixIcon: IconButton(
                    icon: Icon(
                        showCurrent
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                        color: AppColors.mutedForeground),
                    onPressed: () => setModal(() => showCurrent = !showCurrent),
                  )),
              const SizedBox(height: 12),
              _sheetField(ctx, 'New Password', newCtrl, isDark, borderColor,
                  obscure: !showNew,
                  hint: 'At least 6 characters',
                  suffixIcon: IconButton(
                    icon: Icon(
                        showNew
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                        color: AppColors.mutedForeground),
                    onPressed: () => setModal(() => showNew = !showNew),
                  )),
              const SizedBox(height: 12),
              _sheetField(
                  ctx, 'Confirm New Password', confirmCtrl, isDark, borderColor,
                  obscure: !showConfirm,
                  suffixIcon: IconButton(
                    icon: Icon(
                        showConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                        color: AppColors.mutedForeground),
                    onPressed: () =>
                        setModal(() => showConfirm = !showConfirm),
                  )),
              const SizedBox(height: 20),
              _sheetSaveButton(
                ctx: ctx,
                saving: saving,
                label: 'Change Password',
                onTap: () async {
                  if (currentCtrl.text.isEmpty ||
                      newCtrl.text.isEmpty ||
                      confirmCtrl.text.isEmpty) {
                    _snack(ctx, 'Please fill in all fields');
                    return;
                  }
                  if (newCtrl.text.length < 6) {
                    _snack(ctx, 'New password must be at least 6 characters');
                    return;
                  }
                  if (newCtrl.text != confirmCtrl.text) {
                    _snack(ctx, 'New passwords do not match');
                    return;
                  }
                  setModal(() => saving = true);
                  try {
                    await AuthApi.changePassword(
                      currentPassword: currentCtrl.text,
                      newPassword: newCtrl.text,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    _snack(context, 'Password changed successfully',
                        success: true);
                  } catch (e) {
                    _snack(ctx,
                        e.toString().replaceAll('Exception: ', ''));
                  } finally {
                    setModal(() => saving = false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Change Email ──────────────────────────────────────────────────────────

  void _showChangeEmailSheet(
      BuildContext context, bool isDark, Color borderColor) {
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool saving = false;
    bool showPassword = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => _sheet(
          ctx: ctx,
          isDark: isDark,
          title: 'Change Email',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetField(ctx, 'New Email Address', emailCtrl, isDark,
                  borderColor,
                  keyboardType: TextInputType.emailAddress,
                  hint: 'e.g., newemail@example.com'),
              const SizedBox(height: 12),
              _sheetField(
                  ctx, 'Confirm with Password', passwordCtrl, isDark,
                  borderColor,
                  obscure: !showPassword,
                  hint: 'Enter your current password',
                  suffixIcon: IconButton(
                    icon: Icon(
                        showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                        color: AppColors.mutedForeground),
                    onPressed: () =>
                        setModal(() => showPassword = !showPassword),
                  )),
              const SizedBox(height: 20),
              _sheetSaveButton(
                ctx: ctx,
                saving: saving,
                label: 'Change Email',
                onTap: () async {
                  if (emailCtrl.text.trim().isEmpty ||
                      passwordCtrl.text.isEmpty) {
                    _snack(ctx, 'Please fill in all fields');
                    return;
                  }
                  if (!emailCtrl.text.contains('@')) {
                    _snack(ctx, 'Enter a valid email address');
                    return;
                  }
                  setModal(() => saving = true);
                  try {
                    await AuthApi.changeEmail(
                      newEmail: emailCtrl.text.trim(),
                      password: passwordCtrl.text,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    _snack(context, 'Email changed successfully',
                        success: true);
                  } catch (e) {
                    _snack(ctx,
                        e.toString().replaceAll('Exception: ', ''));
                  } finally {
                    setModal(() => saving = false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Change Contact ────────────────────────────────────────────────────────

  void _showChangeContactSheet(BuildContext context, WidgetRef ref,
      bool isDark, Color borderColor) {
    final contactCtrl = TextEditingController();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => _sheet(
          ctx: ctx,
          isDark: isDark,
          title: 'Contact Information',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetField(
                  ctx, 'New Contact Number', contactCtrl, isDark, borderColor,
                  keyboardType: TextInputType.phone,
                  hint: '+63 9XX XXX XXXX'),
              const SizedBox(height: 20),
              _sheetSaveButton(
                ctx: ctx,
                saving: saving,
                label: 'Save Contact',
                onTap: () async {
                  if (contactCtrl.text.trim().isEmpty) {
                    _snack(ctx, 'Please enter a contact number');
                    return;
                  }
                  setModal(() => saving = true);
                  try {
                    await AuthApi.updateContactNumber(
                        contactCtrl.text.trim());
                    if (ctx.mounted) Navigator.pop(ctx);
                    _snack(context, 'Contact number updated',
                        success: true);
                  } catch (e) {
                    _snack(ctx,
                        e.toString().replaceAll('Exception: ', ''));
                  } finally {
                    setModal(() => saving = false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Delete Account ────────────────────────────────────────────────────────

  void _showDeleteAccountSheet(BuildContext context, WidgetRef ref,
      bool isDark, Color borderColor) {
    final passwordCtrl = TextEditingController();
    bool saving = false;
    bool showPassword = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => _sheet(
          ctx: ctx,
          isDark: isDark,
          title: 'Delete Account',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Warning banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_outlined,
                        size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This action is permanent and cannot be undone. '
                        'All your products, orders, and shop data will be deleted.',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _sheetField(
                  ctx, 'Confirm with Password', passwordCtrl, isDark,
                  borderColor,
                  obscure: !showPassword,
                  hint: 'Enter your password to confirm',
                  suffixIcon: IconButton(
                    icon: Icon(
                        showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                        color: AppColors.mutedForeground),
                    onPressed: () =>
                        setModal(() => showPassword = !showPassword),
                  )),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (passwordCtrl.text.isEmpty) {
                            _snack(ctx, 'Please enter your password');
                            return;
                          }
                          // Extra confirmation dialog
                          final confirmed = await showDialog<bool>(
                            context: ctx,
                            builder: (d) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              title: const Text('Are you absolutely sure?'),
                              content: const Text(
                                  'Your account will be permanently deleted. '
                                  'This cannot be reversed.'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(d, false),
                                    child: const Text('Cancel')),
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(d, true),
                                    style: TextButton.styleFrom(
                                        foregroundColor: Colors.red),
                                    child: const Text('Yes, Delete')),
                              ],
                            ),
                          );
                          if (confirmed != true) return;
                          setModal(() => saving = true);
                          try {
                            await AuthApi.deleteAccount(
                                password: passwordCtrl.text);
                            await ref
                                .read(authProvider.notifier)
                                .logout();
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              context.go(AppRouter.landing);
                            }
                          } catch (e) {
                            _snack(ctx,
                                e.toString().replaceAll('Exception: ', ''));
                          } finally {
                            setModal(() => saving = false);
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Delete My Account',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared sheet helpers ──────────────────────────────────────────────────

  Widget _sheet({
    required BuildContext ctx,
    required bool isDark,
    required String title,
    required Widget child,
  }) {
    final bg = isDark ? AppColors.darkCard : Colors.white;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(children: [
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.charcoal)),
              ),
              IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: Icon(Icons.close,
                    color: isDark
                        ? Colors.white70
                        : Colors.grey.shade600),
              ),
            ]),
            const SizedBox(height: 8),
            SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx).padding.bottom + 16),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetField(
    BuildContext ctx,
    String label,
    TextEditingController ctrl,
    bool isDark,
    Color borderColor, {
    TextInputType? keyboardType,
    bool obscure = false,
    String? hint,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedForeground)),
        const SizedBox(height: 5),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          obscureText: obscure,
          style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : AppColors.charcoal),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                fontSize: 13, color: AppColors.mutedForeground),
            suffixIcon: suffixIcon,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: borderColor)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: AppColors.rosewood, width: 1.5)),
            filled: true,
            fillColor:
                isDark ? AppColors.darkBackground : Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _sheetSaveButton({
    required BuildContext ctx,
    required bool saving,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: saving ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.rosewood,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15)),
      ),
    );
  }

  void _snack(BuildContext context, String msg, {bool success = false}) {
    if (!context.mounted) return;
    AlertService.showSnackBar(
      context: context,
      message: msg,
      variant: success ? AlertVariant.success : AlertVariant.error,
    );
  }
}
