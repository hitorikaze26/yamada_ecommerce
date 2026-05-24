import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/address_model.dart';
import '../../../data/providers/auth_notifier.dart';
import '../../../data/services/auth_api.dart';
import '../../widgets/address_selector.dart';

class BuyerSettingsPage extends ConsumerStatefulWidget {
  const BuyerSettingsPage({super.key});

  @override
  ConsumerState<BuyerSettingsPage> createState() => _BuyerSettingsPageState();
}

class _BuyerSettingsPageState extends ConsumerState<BuyerSettingsPage> {
  final _givenNameCtrl = TextEditingController();
  final _surnameCtrl = TextEditingController();
  bool _savingProfile = false;
  bool _uploadingAvatar = false;
  bool _savingAddress = false;
  AddressData? _homeAddress;

  @override
  void initState() {
    super.initState();
    _syncFromUser();
  }

  void _syncFromUser() {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    _givenNameCtrl.text = user.givenName ?? '';
    _surnameCtrl.text = user.surname ?? '';
    _homeAddress = user.fullAddress;
  }

  Future<void> _saveHomeAddress() async {
    final addr = _homeAddress;
    if (addr == null ||
        addr.regionName.isEmpty ||
        addr.municipalityName.isEmpty) {
      AlertService.showSnackBar(
        context: context,
        message: 'Please complete your home address',
        variant: AlertVariant.warning,
      );
      return;
    }
    setState(() => _savingAddress = true);
    try {
      await AuthApi.updateBuyerProfile(address: addr.toJson());
      await ref.read(authProvider.notifier).refreshBuyerProfile();
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: 'Home address updated',
          variant: AlertVariant.success,
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
      if (mounted) setState(() => _savingAddress = false);
    }
  }

  @override
  void dispose() {
    _givenNameCtrl.dispose();
    _surnameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() => _uploadingAvatar = true);
    try {
      await AuthApi.uploadBuyerAvatar(File(file.path));
      await ref.read(authProvider.notifier).refreshBuyerProfile();
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: 'Profile photo updated',
          variant: AlertVariant.success,
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
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_givenNameCtrl.text.trim().isEmpty || _surnameCtrl.text.trim().isEmpty) {
      AlertService.showSnackBar(
        context: context,
        message: 'Please enter your first and last name',
        variant: AlertVariant.warning,
      );
      return;
    }
    setState(() => _savingProfile = true);
    try {
      await AuthApi.updateBuyerProfile(
        givenName: _givenNameCtrl.text.trim(),
        surname: _surnameCtrl.text.trim(),
      );
      await ref.read(authProvider.notifier).refreshBuyerProfile();
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: 'Profile updated',
          variant: AlertVariant.success,
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
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final bg = isDark ? AppColors.darkBackground : AppColors.background;
    final user = ref.watch(authProvider).user;
    final avatarUrl = ApiClient.resolveImageUrl(
      user?.avatarUrl ?? user?.avatar,
    );

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
            _sectionLabel('Profile', isDark),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _uploadingAvatar ? null : _pickAvatar,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.15),
                          backgroundImage: avatarUrl != null
                              ? CachedNetworkImageProvider(avatarUrl)
                              : null,
                          child: avatarUrl == null
                              ? Icon(Icons.person,
                                  size: 44,
                                  color: AppColors.primary.withValues(alpha: 0.7))
                              : null,
                        ),
                        if (_uploadingAvatar)
                          const Positioned.fill(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _givenNameCtrl,
                    decoration: const InputDecoration(labelText: 'First name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _surnameCtrl,
                    decoration: const InputDecoration(labelText: 'Last name'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _savingProfile ? null : _saveProfile,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _savingProfile
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save profile'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionLabel('Delivery address', isDark),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AddressSelector(
                    value: _homeAddress,
                    onChange: (a) => setState(() => _homeAddress = a),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => context.push(AppRouter.addresses),
                    child: const Text('Manage multiple saved addresses'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _savingAddress ? null : _saveHomeAddress,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: _savingAddress
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save home address'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push(AppRouter.help),
              icon: const Icon(Icons.help_outline),
              label: const Text('Help center'),
            ),
            const SizedBox(height: 24),
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
                onTap: () => _showChangeContactSheet(context, isDark, borderColor),
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
                onTap: () => _showDeleteAccountSheet(context, isDark, borderColor),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, bool isDark) => Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white70 : AppColors.mutedForeground,
        ),
      );

  Widget _settingsCard(
      bool isDark, Color cardColor, Color borderColor, List<Widget> children) {
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
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
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
                            (isDark ? Colors.white : AppColors.charcoal),
                      )),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.mutedForeground)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _divider(Color borderColor) =>
      Divider(height: 1, color: borderColor, indent: 68);

  void _showChangePasswordSheet(
      BuildContext context, bool isDark, Color borderColor) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool saving = false;

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
            children: [
              _sheetField(ctx, 'Current Password', currentCtrl, isDark, borderColor,
                  obscure: true),
              const SizedBox(height: 12),
              _sheetField(ctx, 'New Password', newCtrl, isDark, borderColor,
                  obscure: true),
              const SizedBox(height: 12),
              _sheetField(ctx, 'Confirm Password', confirmCtrl, isDark, borderColor,
                  obscure: true),
              const SizedBox(height: 20),
              _sheetSaveButton(
                ctx: ctx,
                saving: saving,
                label: 'Change Password',
                onTap: () async {
                  if (newCtrl.text != confirmCtrl.text) {
                    _snack(ctx, 'Passwords do not match');
                    return;
                  }
                  setModal(() => saving = true);
                  try {
                    await AuthApi.changePassword(
                      currentPassword: currentCtrl.text,
                      newPassword: newCtrl.text,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    _snack(context, 'Password changed', success: true);
                  } catch (e) {
                    _snack(ctx, e.toString().replaceFirst('Exception: ', ''));
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

  void _showChangeEmailSheet(
      BuildContext context, bool isDark, Color borderColor) {
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool saving = false;

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
            children: [
              _sheetField(ctx, 'New Email', emailCtrl, isDark, borderColor),
              const SizedBox(height: 12),
              _sheetField(ctx, 'Password', passwordCtrl, isDark, borderColor,
                  obscure: true),
              const SizedBox(height: 20),
              _sheetSaveButton(
                ctx: ctx,
                saving: saving,
                label: 'Change Email',
                onTap: () async {
                  setModal(() => saving = true);
                  try {
                    await AuthApi.changeEmail(
                      newEmail: emailCtrl.text.trim(),
                      password: passwordCtrl.text,
                    );
                    await ref.read(authProvider.notifier).refreshBuyerProfile();
                    if (ctx.mounted) Navigator.pop(ctx);
                    _snack(context, 'Email updated', success: true);
                  } catch (e) {
                    _snack(ctx, e.toString().replaceFirst('Exception: ', ''));
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

  void _showChangeContactSheet(
      BuildContext context, bool isDark, Color borderColor) {
    final contactCtrl = TextEditingController(
      text: ref.read(authProvider).user?.contactNumber ?? '',
    );
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
            children: [
              _sheetField(ctx, 'Contact Number', contactCtrl, isDark, borderColor),
              const SizedBox(height: 20),
              _sheetSaveButton(
                ctx: ctx,
                saving: saving,
                label: 'Save Contact',
                onTap: () async {
                  setModal(() => saving = true);
                  try {
                    await AuthApi.updateBuyerProfile(
                      contactNumber: contactCtrl.text.trim(),
                    );
                    await ref.read(authProvider.notifier).refreshBuyerProfile();
                    if (ctx.mounted) Navigator.pop(ctx);
                    _snack(context, 'Contact updated', success: true);
                  } catch (e) {
                    _snack(ctx, e.toString().replaceFirst('Exception: ', ''));
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

  void _showDeleteAccountSheet(
      BuildContext context, bool isDark, Color borderColor) {
    final passwordCtrl = TextEditingController();
    bool saving = false;

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
            children: [
              _sheetField(ctx, 'Password', passwordCtrl, isDark, borderColor,
                  obscure: true),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setModal(() => saving = true);
                          try {
                            await AuthApi.deleteAccount(
                                password: passwordCtrl.text);
                            await ref.read(authProvider.notifier).logout();
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              context.go(AppRouter.landing);
                            }
                          } catch (e) {
                            _snack(ctx, e.toString().replaceFirst('Exception: ', ''));
                          } finally {
                            setModal(() => saving = false);
                          }
                        },
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Delete My Account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheet({
    required BuildContext ctx,
    required bool isDark,
    required String title,
    required Widget child,
  }) {
    final bg = isDark ? AppColors.darkCard : Colors.white;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.charcoal)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _sheetField(BuildContext ctx, String label,
      TextEditingController ctrl, bool isDark, Color borderColor,
      {bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
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
        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
        child: saving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label),
      ),
    );
  }

  void _snack(BuildContext context, String msg, {bool success = false}) {
    AlertService.showSnackBar(
      context: context,
      message: msg,
      variant: success ? AlertVariant.success : AlertVariant.error,
    );
  }
}
