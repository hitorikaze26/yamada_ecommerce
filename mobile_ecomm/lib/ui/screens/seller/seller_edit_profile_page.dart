import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/shop_settings_api.dart';

/// Profile fields passed to and returned from [SellerEditProfilePage].
class SellerProfileFormData {
  final String givenName;
  final String surname;
  final String email;
  final String contactNumber;
  final String shopName;
  final String tagline;
  final String description;
  final String? avatarUrl;
  final String? bannerUrl;

  const SellerProfileFormData({
    this.givenName = '',
    this.surname = '',
    this.email = '',
    this.contactNumber = '',
    this.shopName = '',
    this.tagline = '',
    this.description = '',
    this.avatarUrl,
    this.bannerUrl,
  });

  factory SellerProfileFormData.fromProfileMap(Map<String, dynamic> profile) {
    return SellerProfileFormData(
      givenName: profile['givenName']?.toString() ?? '',
      surname: profile['surname']?.toString() ?? '',
      email: profile['email']?.toString() ?? '',
      contactNumber: profile['contactNumber']?.toString() ?? '',
      shopName: profile['shopName']?.toString() ?? '',
      tagline: profile['tagline']?.toString() ?? '',
      description: profile['description']?.toString() ?? '',
      avatarUrl: profile['avatarUrl']?.toString(),
      bannerUrl: profile['bannerUrl']?.toString(),
    );
  }

  SellerProfileFormData copyWith({
    String? givenName,
    String? surname,
    String? email,
    String? contactNumber,
    String? shopName,
    String? tagline,
    String? description,
    String? avatarUrl,
    String? bannerUrl,
  }) {
    return SellerProfileFormData(
      givenName: givenName ?? this.givenName,
      surname: surname ?? this.surname,
      email: email ?? this.email,
      contactNumber: contactNumber ?? this.contactNumber,
      shopName: shopName ?? this.shopName,
      tagline: tagline ?? this.tagline,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
    );
  }
}

/// Opens the shared full-screen seller profile editor (navbar + browse storefront).
Future<SellerProfileFormData?> navigateToSellerEditProfile(
  BuildContext context, {
  SellerProfileFormData? seed,
}) async {
  SellerProfileFormData initial;
  try {
    final profile = await ShopSettingsApi.getProfile();
    initial = SellerProfileFormData.fromProfileMap(profile);
    if (seed != null) {
      initial = initial.copyWith(
        shopName: seed.shopName.isNotEmpty ? seed.shopName : initial.shopName,
        tagline: seed.tagline.isNotEmpty ? seed.tagline : initial.tagline,
        description:
            seed.description.isNotEmpty ? seed.description : initial.description,
        avatarUrl: seed.avatarUrl ?? initial.avatarUrl,
        bannerUrl: seed.bannerUrl ?? initial.bannerUrl,
      );
    }
  } catch (_) {
    initial = seed ?? const SellerProfileFormData();
  }

  if (!context.mounted) return null;
  return context.push<SellerProfileFormData>(
    AppRouter.sellerEditProfile,
    extra: initial,
  );
}

/// Full-screen editor with shop banner and profile photo uploads.
class SellerEditProfilePage extends StatefulWidget {
  final SellerProfileFormData initial;

  const SellerEditProfilePage({super.key, required this.initial});

  @override
  State<SellerEditProfilePage> createState() => _SellerEditProfilePageState();
}

class _SellerEditProfilePageState extends State<SellerEditProfilePage> {
  late final TextEditingController _givenNameCtrl;
  late final TextEditingController _surnameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _contactCtrl;
  late final TextEditingController _shopNameCtrl;
  late final TextEditingController _taglineCtrl;
  late final TextEditingController _descCtrl;

  String? _avatarUrl;
  String? _bannerUrl;
  File? _pickedAvatar;
  File? _pickedBanner;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _givenNameCtrl = TextEditingController(text: i.givenName);
    _surnameCtrl = TextEditingController(text: i.surname);
    _emailCtrl = TextEditingController(text: i.email);
    _contactCtrl = TextEditingController(text: i.contactNumber);
    _shopNameCtrl = TextEditingController(text: i.shopName);
    _taglineCtrl = TextEditingController(text: i.tagline);
    _descCtrl = TextEditingController(text: i.description);
    _avatarUrl = i.avatarUrl;
    _bannerUrl = i.bannerUrl;
  }

  @override
  void dispose() {
    _givenNameCtrl.dispose();
    _surnameCtrl.dispose();
    _emailCtrl.dispose();
    _contactCtrl.dispose();
    _shopNameCtrl.dispose();
    _taglineCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  SellerProfileFormData _currentForm({
    String? avatarUrl,
    String? bannerUrl,
  }) =>
      SellerProfileFormData(
        givenName: _givenNameCtrl.text.trim(),
        surname: _surnameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        contactNumber: _contactCtrl.text.trim(),
        shopName: _shopNameCtrl.text.trim(),
        tagline: _taglineCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        avatarUrl: avatarUrl ?? _avatarUrl,
        bannerUrl: bannerUrl ?? _bannerUrl,
      );

  Future<void> _pickImage({required bool isBanner}) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: isBanner ? 1600 : 800,
      maxHeight: isBanner ? 600 : 800,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() {
      if (isBanner) {
        _pickedBanner = File(file.path);
      } else {
        _pickedAvatar = File(file.path);
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      var avatarUrl = _avatarUrl;
      var bannerUrl = _bannerUrl;

      if (_pickedAvatar != null) {
        final uploaded = await ShopSettingsApi.uploadSellerAvatar(_pickedAvatar!);
        avatarUrl = uploaded.isNotEmpty ? uploaded : avatarUrl;
      }
      if (_pickedBanner != null) {
        final uploaded = await ShopSettingsApi.uploadSellerBanner(_pickedBanner!);
        bannerUrl = uploaded.isNotEmpty ? uploaded : bannerUrl;
      }

      final form = _currentForm(avatarUrl: avatarUrl, bannerUrl: bannerUrl);
      await ShopSettingsApi.updateProfile({
        'givenName': form.givenName,
        'surname': form.surname,
        'email': form.email,
        'contactNumber': form.contactNumber,
        'shopName': form.shopName,
        'tagline': form.tagline,
        'description': form.description,
      });

      if (!mounted) return;
      Navigator.of(context).pop(form);
    } catch (e) {
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: e.toString().replaceAll('Exception: ', ''),
          variant: AlertVariant.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label, bool isDark) {
    final border = isDark ? AppColors.darkBorder : AppColors.border;
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: isDark ? AppColors.darkBackground : AppColors.offWhite,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.rosewood, width: 1.5),
      ),
      labelStyle: TextStyle(
        color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
      ),
    );
  }

  Widget _buildStorefrontImages(bool isDark) {
    final resolvedBanner = _pickedBanner != null
        ? null
        : ApiClient.resolveImageUrl(_bannerUrl);
    final resolvedAvatar = _pickedAvatar != null
        ? null
        : ApiClient.resolveImageUrl(_avatarUrl);
    final shopInitial = _shopNameCtrl.text.trim().isNotEmpty
        ? _shopNameCtrl.text.trim()[0].toUpperCase()
        : '?';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          title: 'Storefront appearance',
          icon: Icons.photo_outlined,
          isDark: isDark,
        ),
        const SizedBox(height: 10),
        Text(
          'Banner and profile photo appear on your public store page.',
          style: TextStyle(
            fontSize: 12,
            color: isDark
                ? AppColors.darkMutedForeground
                : AppColors.mutedForeground,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _saving ? null : () => _pickImage(isBanner: true),
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
              color: isDark ? AppColors.darkCard : AppColors.muted,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_pickedBanner != null)
                  Image.file(_pickedBanner!, fit: BoxFit.cover)
                else if (resolvedBanner != null)
                  CachedNetworkImage(
                    imageUrl: resolvedBanner,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (_, __, ___) => _bannerPlaceholder(isDark),
                  )
                else
                  _bannerPlaceholder(isDark),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: _imageEditChip(
                    label: _pickedBanner != null || resolvedBanner != null
                        ? 'Change banner'
                        : 'Add banner',
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: GestureDetector(
            onTap: _saving ? null : () => _pickImage(isBanner: false),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _pickedAvatar != null
                        ? Image.file(_pickedAvatar!, fit: BoxFit.cover)
                        : resolvedAvatar != null
                            ? CachedNetworkImage(
                                imageUrl: resolvedAvatar,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => ColoredBox(
                                  color: AppColors.rosewood.withValues(alpha: 0.15),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) =>
                                    _avatarFallback(shopInitial),
                              )
                            : _avatarFallback(shopInitial),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppColors.rosewood,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Shop profile photo',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.darkMutedForeground
                  : AppColors.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }

  Widget _bannerPlaceholder(bool isDark) {
    return Container(
      color: isDark
          ? AppColors.darkMuted
          : AppColors.rosewood.withValues(alpha: 0.08),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.panorama_outlined,
            size: 36,
            color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
          ),
          const SizedBox(height: 6),
          Text(
            'Tap to add a store banner',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.darkMutedForeground
                  : AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(String initial) {
    return ColoredBox(
      color: AppColors.rosewood.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: AppColors.rosewood,
          ),
        ),
      ),
    );
  }

  Widget _imageEditChip({required String label, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.edit_outlined, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.charcoal;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Edit Profile & Shop Info',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _buildStorefrontImages(isDark),
          const SizedBox(height: 28),
          _SectionTitle(
            title: 'Personal information',
            icon: Icons.person_outline,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _givenNameCtrl,
                  decoration: _decoration('First name', isDark),
                  style: TextStyle(color: textColor),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _surnameCtrl,
                  decoration: _decoration('Last name', isDark),
                  style: TextStyle(color: textColor),
                  textInputAction: TextInputAction.next,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailCtrl,
            decoration: _decoration('Email', isDark),
            style: TextStyle(color: textColor),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contactCtrl,
            decoration: _decoration('Contact number', isDark),
            style: TextStyle(color: textColor),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 24),
          _SectionTitle(
            title: 'Shop information',
            icon: Icons.store_outlined,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _shopNameCtrl,
            decoration: _decoration('Shop name', isDark),
            style: TextStyle(color: textColor),
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _taglineCtrl,
            decoration: _decoration('Tagline', isDark),
            style: TextStyle(color: textColor),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: _decoration('Shop description', isDark),
            style: TextStyle(color: textColor),
            maxLines: 4,
            textInputAction: TextInputAction.newline,
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.rosewood,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save changes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isDark;

  const _SectionTitle({
    required this.title,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.rosewood),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.charcoal,
          ),
        ),
      ],
    );
  }
}
