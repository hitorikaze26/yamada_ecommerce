import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/services/api_client.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/auth_notifier.dart';
import '../../../data/services/shop_settings_api.dart';
import 'seller_edit_profile_page.dart';

// ── Shipping model ────────────────────────────────────────────────────────────

class _ShippingSetting {
  final int id;
  String regionName;
  String provinceName;
  String cityName;
  double shippingFee;
  bool isActive;

  _ShippingSetting({
    required this.id,
    required this.regionName,
    required this.provinceName,
    required this.cityName,
    required this.shippingFee,
    required this.isActive,
  });

  factory _ShippingSetting.fromJson(Map<String, dynamic> j) =>
      _ShippingSetting(
        id: j['id'] as int,
        regionName: j['regionName']?.toString() ?? '',
        provinceName: j['provinceName']?.toString() ?? '',
        cityName: j['cityName']?.toString() ?? '',
        shippingFee: (j['shippingFee'] as num?)?.toDouble() ?? 0,
        isActive: j['isActive'] as bool? ?? true,
      );
}

// ── Main page ─────────────────────────────────────────────────────────────────

class SellerShopSettingsPage extends ConsumerStatefulWidget {
  const SellerShopSettingsPage({super.key});

  @override
  ConsumerState<SellerShopSettingsPage> createState() =>
      _SellerShopSettingsPageState();
}

class _SellerShopSettingsPageState extends ConsumerState<SellerShopSettingsPage> {
  bool _loading = true;
  String? _error;

  // ── Profile / shop info ───────────────────────────────────────────────────
  final _givenNameCtrl = TextEditingController();
  final _surnameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _shopNameCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // ── Seller address (read-only display, set during registration) ───────────
  Map<String, String> _sellerAddress = {};
  String? _avatarUrl;
  String? _bannerUrl;

  // ── Shipping ──────────────────────────────────────────────────────────────
  List<_ShippingSetting> _shipping = [];

  // ── Payment ───────────────────────────────────────────────────────────────
  bool _codEnabled = true;
  bool _originalCod = true;
  bool _savingPayment = false;

  // ── Order ─────────────────────────────────────────────────────────────────
  bool _allowCancellation = true;
  int _maxCancelHours = 24;
  bool _allowReturns = true;
  int _returnDays = 7;
  bool _savingOrder = false;

  // ── Customization ─────────────────────────────────────────────────────────
  final _announcementCtrl = TextEditingController();
  String _primaryColor = '#3b82f6';
  String _themeMode = 'light';
  bool _savingCustomization = false;

  // ── Chat ──────────────────────────────────────────────────────────────────
  bool _autoReplyEnabled = false;
  final _autoReplyMsgCtrl = TextEditingController();
  bool _savingChat = false;

  bool _resumeRefreshPending = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void deactivate() {
    _resumeRefreshPending = true;
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    if (_resumeRefreshPending && !_loading) {
      _resumeRefreshPending = false;
      ref.read(authProvider.notifier).refreshSellerProfile();
      _loadAll();
    }
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
    _announcementCtrl.dispose();
    _autoReplyMsgCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await ShopSettingsApi.getProfile();
      final storeId = (profile['storeId'] as num?)?.toInt();
      final isVerified = profile['isVerified'] == true;

      Map<String, dynamic> settings = {};
      if (storeId != null || isVerified) {
        try {
          settings = await ShopSettingsApi.getAllSettings();
        } catch (_) {
          settings = {};
        }
      }

      // Profile
      _givenNameCtrl.text = profile['givenName']?.toString() ?? '';
      _surnameCtrl.text = profile['surname']?.toString() ?? '';
      _emailCtrl.text = profile['email']?.toString() ?? '';
      _contactCtrl.text = profile['contactNumber']?.toString() ?? '';
      _shopNameCtrl.text = profile['shopName']?.toString() ?? '';
      _taglineCtrl.text = profile['tagline']?.toString() ?? '';
      _descCtrl.text = profile['description']?.toString() ?? '';
      _avatarUrl = profile['avatarUrl']?.toString();
      _bannerUrl = profile['bannerUrl']?.toString();

      // Address (from registration — display only)
      final addr = profile['address'] as Map<String, dynamic>? ?? {};
      _sellerAddress = {
        'streetAddress': addr['streetAddress']?.toString() ?? '',
        'barangayName': addr['barangayName']?.toString() ?? '',
        'municipalityName': addr['municipalityName']?.toString() ?? '',
        'provinceName': addr['provinceName']?.toString() ?? '',
        'regionName': addr['regionName']?.toString() ?? '',
        'postalCode': addr['postalCode']?.toString() ?? '',
      };

      // Shipping
      final rawShipping = settings['shipping'] as List<dynamic>? ?? [];
      _shipping = rawShipping
          .map((e) => _ShippingSetting.fromJson(e as Map<String, dynamic>))
          .toList();

      // Payment
      final payment = settings['payment'] as Map<String, dynamic>? ?? {};
      _codEnabled = payment['codEnabled'] as bool? ?? true;
      _originalCod = _codEnabled;

      // Order
      final order = settings['order'] as Map<String, dynamic>? ?? {};
      _allowCancellation = order['allowCancellation'] as bool? ?? true;
      _maxCancelHours = order['maxCancellationHours'] as int? ?? 24;
      _allowReturns = order['allowReturns'] as bool? ?? true;
      _returnDays = order['returnPeriodDays'] as int? ?? 7;

      // Customization
      final custom = settings['customization'] as Map<String, dynamic>? ?? {};
      _announcementCtrl.text = custom['announcement']?.toString() ?? '';
      _primaryColor = custom['primaryColor']?.toString() ?? '#3b82f6';
      _themeMode = custom['themeMode']?.toString() ?? 'light';

      // Chat
      final chat = settings['chat'] as Map<String, dynamic>? ?? {};
      _autoReplyEnabled = chat['autoReplyEnabled'] as bool? ?? false;
      _autoReplyMsgCtrl.text = chat['autoReplyMessage']?.toString() ??
          'Thank you for your message! We will get back to you shortly.';

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  // ── Save handlers ─────────────────────────────────────────────────────────

  Future<void> _savePayment() async {
    setState(() => _savingPayment = true);
    try {
      await ShopSettingsApi.updatePayment(codEnabled: _codEnabled);
      setState(() => _originalCod = _codEnabled);
      _showSnack('Payment settings saved', success: true);
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _savingPayment = false);
    }
  }

  Future<void> _saveOrder() async {
    setState(() => _savingOrder = true);
    try {
      await ShopSettingsApi.updateOrder({
        'allowCancellation': _allowCancellation,
        'maxCancellationHours': _maxCancelHours,
        'allowReturns': _allowReturns,
        'returnPeriodDays': _returnDays,
      });
      _showSnack('Order settings saved', success: true);
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _savingOrder = false);
    }
  }

  Future<void> _saveCustomization() async {
    setState(() => _savingCustomization = true);
    try {
      await ShopSettingsApi.updateCustomization({
        'announcement': _announcementCtrl.text.trim(),
        'primaryColor': _primaryColor,
        'themeMode': _themeMode,
      });
      _showSnack('Appearance saved', success: true);
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _savingCustomization = false);
    }
  }

  Future<void> _saveChat() async {
    setState(() => _savingChat = true);
    try {
      await ShopSettingsApi.updateChat({
        'autoReplyEnabled': _autoReplyEnabled,
        'autoReplyMessage': _autoReplyMsgCtrl.text.trim(),
      });
      _showSnack('Chat settings saved', success: true);
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _savingChat = false);
    }
  }

  Future<void> _toggleShipping(int id, bool current) async {
    try {
      await ShopSettingsApi.updateShipping(id, {'isActive': !current});
      await _loadAll();
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _deleteShipping(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Location'),
        content: const Text('Remove this shipping location? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ShopSettingsApi.deleteShipping(id);
      await _loadAll();
      _showSnack('Location deleted', success: true);
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    AlertService.showSnackBar(
      context: context,
      message: msg,
      variant: success ? AlertVariant.success : AlertVariant.error,
    );
  }

  Widget _sheetField(String label, TextEditingController ctrl, bool isDark,
      {TextInputType? keyboardType, String? hint}) {
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: AppColors.mutedForeground)),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: TextStyle(
              fontSize: 14, color: isDark ? Colors.white : AppColors.charcoal),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                fontSize: 13, color: AppColors.mutedForeground),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: borderColor)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.rosewood, width: 1.5)),
            filled: true,
            fillColor: isDark ? AppColors.darkBackground : Colors.white,
          ),
        ),
      ],
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final bg = isDark ? AppColors.darkBackground : AppColors.background;

    if (_loading) {
      return Scaffold(
        backgroundColor: bg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.mutedForeground)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.rosewood),
              ),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Shop settings'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Shipping ───────────────────────────────────────────────
              _sectionHeader('Shipping Locations', Icons.local_shipping_outlined, isDark),
              const SizedBox(height: 10),
              _buildShippingSection(isDark, cardColor, borderColor),
              const SizedBox(height: 20),

              // ── Payment ────────────────────────────────────────────────
              _sectionHeader('Payment Methods', Icons.payment_outlined, isDark),
              const SizedBox(height: 10),
              _buildPaymentSection(isDark, cardColor, borderColor),
              const SizedBox(height: 20),

              // ── Order ──────────────────────────────────────────────────
              _sectionHeader('Order Rules', Icons.receipt_long_outlined, isDark),
              const SizedBox(height: 10),
              _buildOrderSection(isDark, cardColor, borderColor),
              const SizedBox(height: 20),

              // ── Customization ──────────────────────────────────────────
              _sectionHeader('Shop Appearance', Icons.palette_outlined, isDark),
              const SizedBox(height: 10),
              _buildCustomizationSection(isDark, cardColor, borderColor),
              const SizedBox(height: 20),

              // ── Chat ───────────────────────────────────────────────────
              _sectionHeader('Auto-Reply Chat', Icons.chat_bubble_outline, isDark),
              const SizedBox(height: 10),
              _buildChatSection(isDark, cardColor, borderColor),
              const SizedBox(height: 20),

              // ── Logout ─────────────────────────────────────────────────
              _buildLogoutButton(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, bool isDark) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.rosewood.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: AppColors.rosewood),
      ),
      const SizedBox(width: 8),
      Text(title,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.charcoal)),
    ]);
  }

  Widget _buildProfileHeader(user, bool isDark, Color cardColor, Color borderColor) {
    final avatarUrl = ApiClient.resolveImageUrl(_avatarUrl);
    final shopInitial = _shopNameCtrl.text.trim().isNotEmpty
        ? _shopNameCtrl.text.trim()[0].toUpperCase()
        : 'S';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: 64,
              height: 64,
              child: avatarUrl != null
                  ? Image(
                      image: CachedNetworkImageProvider(avatarUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _profileAvatarFallback(shopInitial),
                    )
                  : _profileAvatarFallback(shopInitial),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _shopNameCtrl.text.isNotEmpty
                      ? _shopNameCtrl.text
                      : (user?.fullName ?? 'My Shop'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.charcoal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  user?.email ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: user?.isVerified == true
                        ? AppColors.deliveredBg
                        : AppColors.pendingBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        user?.isVerified == true
                            ? Icons.verified
                            : Icons.pending,
                        size: 12,
                        color: user?.isVerified == true
                            ? AppColors.delivered
                            : AppColors.pending,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        user?.isVerified == true
                            ? 'Verified'
                            : 'Pending Approval',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: user?.isVerified == true
                              ? AppColors.delivered
                              : AppColors.pending,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit profile & shop info',
            onPressed: _openEditProfilePage,
            icon: const Icon(Icons.edit_outlined, color: AppColors.rosewood),
          ),
        ],
      ),
    );
  }

  Widget _profileAvatarFallback(String initial) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.rosewood, AppColors.blush],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ── Address display (read-only, set during registration) ─────────────────

  Widget _buildAddressDisplay(bool isDark, Color borderColor) {
    // Build a human-readable address string from the parts
    final parts = <String>[
      _sellerAddress['streetAddress'] ?? '',
      _sellerAddress['barangayName'] ?? '',
      _sellerAddress['municipalityName'] ?? '',
      _sellerAddress['provinceName'] ?? '',
      _sellerAddress['regionName'] ?? '',
    ].where((p) => p.isNotEmpty).toList();

    final postalCode = _sellerAddress['postalCode'] ?? '';
    final fullAddress = parts.isNotEmpty
        ? parts.join(', ') + (postalCode.isNotEmpty ? ' $postalCode' : '')
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkBackground
            : const Color(0xFFF8F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: AppColors.rosewood.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.location_on_outlined,
                size: 16, color: AppColors.rosewood),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('Registered Address',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.mutedForeground,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.rosewood.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Read-only',
                        style: TextStyle(
                            fontSize: 9,
                            color: AppColors.rosewood,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 4),
                if (fullAddress != null)
                  Text(
                    fullAddress,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : AppColors.charcoal,
                        height: 1.4),
                  )
                else
                  const Text('No address on file',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.mutedForeground,
                          fontStyle: FontStyle.italic)),
                const SizedBox(height: 4),
                const Text(
                  'Address is set during registration and cannot be changed here.',
                  style: TextStyle(
                      fontSize: 10,
                      color: AppColors.mutedForeground,
                      height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditProfilePage() async {
    final result = await navigateToSellerEditProfile(
      context,
      seed: SellerProfileFormData(
        givenName: _givenNameCtrl.text,
        surname: _surnameCtrl.text,
        email: _emailCtrl.text,
        contactNumber: _contactCtrl.text,
        shopName: _shopNameCtrl.text,
        tagline: _taglineCtrl.text,
        description: _descCtrl.text,
        avatarUrl: _avatarUrl,
        bannerUrl: _bannerUrl,
      ),
    );
    if (result == null || !mounted) return;
    _givenNameCtrl.text = result.givenName;
    _surnameCtrl.text = result.surname;
    _emailCtrl.text = result.email;
    _contactCtrl.text = result.contactNumber;
    _shopNameCtrl.text = result.shopName;
    _taglineCtrl.text = result.tagline;
    _descCtrl.text = result.description;
    _avatarUrl = result.avatarUrl;
    _bannerUrl = result.bannerUrl;
    setState(() {});
    _showSnack('Profile saved successfully', success: true);
  }

  // ── Shipping section ──────────────────────────────────────────────────────

  Widget _buildShippingSection(bool isDark, Color cardColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              '${_shipping.length} location${_shipping.length != 1 ? 's' : ''} configured',
              style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
            ),
          ),
          GestureDetector(
            onTap: () => _showShippingSheet(isDark, borderColor, null),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.rosewood,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, size: 15, color: Colors.white),
                SizedBox(width: 4),
                Text('Add Location',
                    style: TextStyle(fontSize: 12, color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
        if (_shipping.isEmpty) ...[
          const SizedBox(height: 20),
          Center(
            child: Column(children: [
              Icon(Icons.local_shipping_outlined,
                  size: 36, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              const Text('No shipping locations yet',
                  style: TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
              const SizedBox(height: 4),
              const Text('Add your first shipping location to get started',
                  style: TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                  textAlign: TextAlign.center),
            ]),
          ),
          const SizedBox(height: 8),
        ] else ...[
          const SizedBox(height: 12),
          ..._shipping.map((s) => _buildShippingCard(s, isDark, borderColor)),
        ],

        // ── Shop registered address ────────────────────────────────────
        Divider(color: borderColor, height: 24),
        _buildAddressDisplay(isDark, borderColor),
      ]),
    );
  }

  Widget _buildShippingCard(
      _ShippingSetting s, bool isDark, Color borderColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: s.isActive
            ? (isDark ? AppColors.darkBackground : const Color(0xFFFDF6F9))
            : (isDark
                ? AppColors.darkBackground.withOpacity(0.5)
                : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: s.isActive
              ? AppColors.rosewood.withOpacity(0.3)
              : borderColor,
        ),
      ),
      child: Row(children: [
        // Icon
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: s.isActive
                ? AppColors.rosewood.withOpacity(0.12)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.location_on_outlined,
              size: 18,
              color: s.isActive ? AppColors.rosewood : Colors.grey),
        ),
        const SizedBox(width: 10),
        // Location info
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              '${s.cityName}, ${s.provinceName}',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.charcoal),
              overflow: TextOverflow.ellipsis,
            ),
            Text(s.regionName,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.mutedForeground)),
            const SizedBox(height: 3),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.rosewood.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '₱${s.shippingFee.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold,
                      color: AppColors.rosewood),
                ),
              ),
              if (!s.isActive) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Inactive',
                      style: TextStyle(
                          fontSize: 10, color: AppColors.mutedForeground)),
                ),
              ],
            ]),
          ]),
        ),
        // Actions column
        Column(mainAxisSize: MainAxisSize.min, children: [
          // Active toggle
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: s.isActive,
              onChanged: (_) => _toggleShipping(s.id, s.isActive),
              activeColor: const Color(0xFF10B981),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            // Edit
            GestureDetector(
              onTap: () => _showShippingSheet(isDark, borderColor, s),
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.edit_outlined,
                    size: 14, color: Color(0xFF3B82F6)),
              ),
            ),
            const SizedBox(width: 6),
            // Delete
            GestureDetector(
              onTap: () => _deleteShipping(s.id),
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.delete_outline,
                    size: 14, color: Colors.red),
              ),
            ),
          ]),
        ]),
      ]),
    );
  }

  // ── Add / Edit shipping bottom sheet ─────────────────────────────────────
  // Pass null for [existing] to add, or a _ShippingSetting to edit.

  void _showShippingSheet(
      bool isDark, Color borderColor, _ShippingSetting? existing) {
    final isEdit = existing != null;
    final regionCtrl =
        TextEditingController(text: existing?.regionName ?? '');
    final provinceCtrl =
        TextEditingController(text: existing?.provinceName ?? '');
    final cityCtrl =
        TextEditingController(text: existing?.cityName ?? '');
    final feeCtrl = TextEditingController(
        text: existing != null
            ? existing.shippingFee.toStringAsFixed(2)
            : '');
    bool isActive = existing?.isActive ?? true;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final bg = isDark ? AppColors.darkCard : Colors.white;
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                  // Drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 4),
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Header
                  Row(children: [
                    Expanded(
                      child: Text(
                        isEdit
                            ? 'Edit Shipping Location'
                            : 'Add Shipping Location',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : AppColors.charcoal),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(Icons.close,
                          color: isDark
                              ? Colors.white70
                              : Colors.grey.shade600),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  // Fields
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sheetField('Region', regionCtrl, isDark,
                            hint: 'e.g., Region IV-A (CALABARZON)'),
                        const SizedBox(height: 10),
                        _sheetField('Province', provinceCtrl, isDark,
                            hint: 'e.g., Laguna'),
                        const SizedBox(height: 10),
                        _sheetField('City / Municipality', cityCtrl, isDark,
                            hint: 'e.g., Santa Rosa City'),
                        const SizedBox(height: 10),
                        _sheetField('Shipping Fee (₱)', feeCtrl, isDark,
                            hint: '0.00',
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true)),
                        // Active toggle (edit mode only)
                        if (isEdit) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFF10B981).withOpacity(0.08)
                                  : Colors.grey.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isActive
                                    ? const Color(0xFF10B981).withOpacity(0.3)
                                    : borderColor,
                              ),
                            ),
                            child: Row(children: [
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Active',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? Colors.white
                                                  : AppColors.charcoal)),
                                      const Text(
                                          'Enable this location for buyers',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color:
                                                  AppColors.mutedForeground)),
                                    ]),
                              ),
                              Switch(
                                value: isActive,
                                onChanged: (v) =>
                                    setModal(() => isActive = v),
                                activeColor: const Color(0xFF10B981),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ]),
                          ),
                        ],
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                  // Save button
                  Padding(
                    padding: EdgeInsets.only(
                        bottom:
                            MediaQuery.of(ctx).padding.bottom + 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                if (regionCtrl.text.trim().isEmpty ||
                                    provinceCtrl.text.trim().isEmpty ||
                                    cityCtrl.text.trim().isEmpty ||
                                    feeCtrl.text.trim().isEmpty) {
                                  _showSnack(
                                      'Please fill in all fields');
                                  return;
                                }
                                final fee = double.tryParse(
                                    feeCtrl.text.trim());
                                if (fee == null) {
                                  _showSnack(
                                      'Enter a valid shipping fee');
                                  return;
                                }
                                setModal(() => saving = true);
                                try {
                                  if (isEdit) {
                                    await ShopSettingsApi.updateShipping(
                                        existing.id, {
                                      'regionName':
                                          regionCtrl.text.trim(),
                                      'provinceName':
                                          provinceCtrl.text.trim(),
                                      'cityName': cityCtrl.text.trim(),
                                      'shippingFee': fee,
                                      'isActive': isActive,
                                    });
                                    _showSnack(
                                        'Location updated',
                                        success: true);
                                  } else {
                                    await ShopSettingsApi.createShipping({
                                      'regionName':
                                          regionCtrl.text.trim(),
                                      'provinceName':
                                          provinceCtrl.text.trim(),
                                      'cityName': cityCtrl.text.trim(),
                                      'shippingFee': fee,
                                    });
                                    _showSnack(
                                        'Location added',
                                        success: true);
                                  }
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  await _loadAll();
                                } catch (e) {
                                  _showSnack(e
                                      .toString()
                                      .replaceAll('Exception: ', ''));
                                } finally {
                                  setModal(() => saving = false);
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.rosewood,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: saving
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : Text(
                                isEdit
                                    ? 'Save Changes'
                                    : 'Add Location',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Payment section ───────────────────────────────────────────────────────

  Widget _buildPaymentSection(bool isDark, Color cardColor, Color borderColor) {
    final changed = _codEnabled != _originalCod;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(children: [
        // COD row
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _codEnabled
                ? const Color(0xFF10B981).withOpacity(0.08)
                : (isDark ? AppColors.darkBackground : Colors.grey.shade50),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _codEnabled
                  ? const Color(0xFF10B981).withOpacity(0.4)
                  : borderColor,
            ),
          ),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: _codEnabled
                    ? const Color(0xFF10B981)
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.payments_outlined,
                  color: _codEnabled ? Colors.white : Colors.grey.shade600,
                  size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Cash on Delivery (COD)',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.charcoal)),
                const Text('Allow customers to pay on delivery',
                    style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
              ]),
            ),
            Switch(
              value: _codEnabled,
              onChanged: (v) => setState(() => _codEnabled = v),
              activeColor: const Color(0xFF10B981),
            ),
          ]),
        ),
        if (changed) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _codEnabled = _originalCod),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.mutedForeground,
                  side: BorderSide(color: borderColor),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Reset'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _savingPayment ? null : _savePayment,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _savingPayment
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Changes',
                        style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  // ── Order section ─────────────────────────────────────────────────────────

  Widget _buildOrderSection(bool isDark, Color cardColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Cancellation
        _settingToggleRow(
          label: 'Allow Order Cancellation',
          subtitle: 'Customers can cancel within a time limit',
          value: _allowCancellation,
          onChanged: (v) => setState(() => _allowCancellation = v),
          activeColor: const Color(0xFFF59E0B),
          isDark: isDark,
          borderColor: borderColor,
        ),
        if (_allowCancellation) ...[
          const SizedBox(height: 10),
          _numberInputRow(
            label: 'Max cancellation window',
            suffix: 'hours',
            value: _maxCancelHours,
            min: 1, max: 72,
            onChanged: (v) => setState(() => _maxCancelHours = v),
            isDark: isDark,
            borderColor: borderColor,
          ),
        ],
        Divider(color: borderColor, height: 24),
        // Returns
        _settingToggleRow(
          label: 'Allow Returns',
          subtitle: 'Customers can return items for refund',
          value: _allowReturns,
          onChanged: (v) => setState(() => _allowReturns = v),
          activeColor: const Color(0xFF8B5CF6),
          isDark: isDark,
          borderColor: borderColor,
        ),
        if (_allowReturns) ...[
          const SizedBox(height: 10),
          _numberInputRow(
            label: 'Return period',
            suffix: 'days after delivery',
            value: _returnDays,
            min: 1, max: 30,
            onChanged: (v) => setState(() => _returnDays = v),
            isDark: isDark,
            borderColor: borderColor,
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _savingOrder ? null : _saveOrder,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _savingOrder
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save Order Rules',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
      ]),
    );
  }

  Widget _settingToggleRow({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color activeColor,
    required bool isDark,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: value
            ? activeColor.withOpacity(0.07)
            : (isDark ? AppColors.darkBackground : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: value ? activeColor.withOpacity(0.35) : borderColor,
        ),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.charcoal)),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.mutedForeground)),
          ]),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: activeColor,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]),
    );
  }

  Widget _numberInputRow({
    required String label,
    required String suffix,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
    required bool isDark,
    required Color borderColor,
  }) {
    final ctrl = TextEditingController(text: value.toString());
    return Row(children: [
      Text(label,
          style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
      const SizedBox(width: 10),
      SizedBox(
        width: 64,
        child: TextFormField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          onChanged: (v) {
            final parsed = int.tryParse(v) ?? min;
            onChanged(parsed.clamp(min, max));
          },
          style: TextStyle(
              fontSize: 13, color: isDark ? Colors.white : AppColors.charcoal),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.rosewood, width: 1.5)),
            filled: true,
            fillColor: isDark ? AppColors.darkBackground : Colors.white,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text(suffix,
          style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
    ]);
  }

  // ── Customization section ─────────────────────────────────────────────────

  static const _colorOptions = [
    {'name': 'Blue', 'value': '#3b82f6', 'color': Color(0xFF3B82F6)},
    {'name': 'Purple', 'value': '#8b5cf6', 'color': Color(0xFF8B5CF6)},
    {'name': 'Pink', 'value': '#ec4899', 'color': Color(0xFFEC4899)},
    {'name': 'Red', 'value': '#ef4444', 'color': Color(0xFFEF4444)},
    {'name': 'Orange', 'value': '#f97316', 'color': Color(0xFFF97316)},
    {'name': 'Green', 'value': '#22c55e', 'color': Color(0xFF22C55E)},
    {'name': 'Teal', 'value': '#14b8a6', 'color': Color(0xFF14B8A6)},
    {'name': 'Rosewood', 'value': '#c97a8c', 'color': AppColors.rosewood},
  ];

  Widget _buildCustomizationSection(bool isDark, Color cardColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Announcement
        const Text('Shop Announcement',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: AppColors.mutedForeground)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _announcementCtrl,
          maxLines: 3,
          style: TextStyle(
              fontSize: 13, color: isDark ? Colors.white : AppColors.charcoal),
          decoration: InputDecoration(
            hintText: 'e.g., 🎉 Free shipping on orders over ₱1,000!',
            hintStyle: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: borderColor)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.rosewood, width: 1.5)),
            filled: true,
            fillColor: isDark ? AppColors.darkBackground : Colors.white,
          ),
        ),
        const SizedBox(height: 16),

        // Brand color
        const Text('Brand Color',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: AppColors.mutedForeground)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10, runSpacing: 10,
          children: _colorOptions.map((c) {
            final isSelected = _primaryColor == c['value'];
            return GestureDetector(
              onTap: () => setState(() => _primaryColor = c['value'] as String),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: c['color'] as Color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                  boxShadow: isSelected
                      ? [BoxShadow(
                          color: (c['color'] as Color).withOpacity(0.5),
                          blurRadius: 8, spreadRadius: 1)]
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Theme mode
        const Text('Theme Mode',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: AppColors.mutedForeground)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _themeModeChip('light', Icons.wb_sunny_outlined, 'Light', isDark, borderColor)),
          const SizedBox(width: 10),
          Expanded(child: _themeModeChip('dark', Icons.nightlight_outlined, 'Dark', isDark, borderColor)),
        ]),
        const SizedBox(height: 14),

        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _savingCustomization ? null : _saveCustomization,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEC4899),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _savingCustomization
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save Appearance',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
      ]),
    );
  }

  Widget _themeModeChip(
      String mode, IconData icon, String label, bool isDark, Color borderColor) {
    final isSelected = _themeMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _themeMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.rosewood.withOpacity(0.1)
              : (isDark ? AppColors.darkBackground : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.rosewood : borderColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(children: [
          Icon(icon,
              size: 22,
              color: isSelected ? AppColors.rosewood : AppColors.mutedForeground),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500,
                  color: isSelected ? AppColors.rosewood : AppColors.mutedForeground)),
        ]),
      ),
    );
  }

  // ── Chat section ──────────────────────────────────────────────────────────

  Widget _buildChatSection(bool isDark, Color cardColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _settingToggleRow(
          label: 'Enable Auto-Reply',
          subtitle: 'Automatically respond to new customer messages',
          value: _autoReplyEnabled,
          onChanged: (v) => setState(() => _autoReplyEnabled = v),
          activeColor: const Color(0xFF6366F1),
          isDark: isDark,
          borderColor: borderColor,
        ),
        if (_autoReplyEnabled) ...[
          const SizedBox(height: 12),
          const Text('Auto-Reply Message',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppColors.mutedForeground)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _autoReplyMsgCtrl,
            maxLines: 4,
            style: TextStyle(
                fontSize: 13, color: isDark ? Colors.white : AppColors.charcoal),
            decoration: InputDecoration(
              hintText: 'Enter your auto-reply message...',
              hintStyle: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: borderColor)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: borderColor)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: Color(0xFF6366F1), width: 1.5)),
              filled: true,
              fillColor: isDark ? AppColors.darkBackground : Colors.white,
            ),
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _savingChat ? null : _saveChat,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _savingChat
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save Chat Settings',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
      ]),
    );
  }

  // ── Logout button ─────────────────────────────────────────────────────────

  Widget _buildLogoutButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Sign Out'),
              content: const Text('Are you sure you want to sign out?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Sign Out')),
              ],
            ),
          );
          if (confirmed == true && mounted) {
            await ref.read(authProvider.notifier).logout();
            if (mounted) context.go(AppRouter.landing);
          }
        },
        icon: const Icon(Icons.logout, size: 18, color: Colors.red),
        label: const Text('Sign Out',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
