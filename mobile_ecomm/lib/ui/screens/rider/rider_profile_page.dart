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
import '../../widgets/custom_cards.dart';
import '../../widgets/rider_delivery_widgets.dart';

class RiderProfilePage extends ConsumerStatefulWidget {
  const RiderProfilePage({super.key});

  @override
  ConsumerState<RiderProfilePage> createState() => _RiderProfilePageState();
}

class _RiderProfilePageState extends ConsumerState<RiderProfilePage> {
  bool _isEditing = false;
  bool _isLoading = true;
  String? _error;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vehicleTypeController = TextEditingController();
  final _licenseNumberController = TextEditingController();

  Map<String, dynamic>? _address;
  Map<String, dynamic>? _documents;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _vehicleTypeController.dispose();
    _licenseNumberController.dispose();
    super.dispose();
  }

  void _populateFromAuthUser() {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    _firstNameController.text = user.givenName ?? '';
    _lastNameController.text = user.surname ?? '';
    _emailController.text = user.email;
    _phoneController.text = user.contactNumber ?? '';
    _avatarUrl = ApiClient.resolveImageUrl(user.avatarUrl);
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profile = await AuthApi.getRiderProfile();
      if (!mounted) return;

      setState(() {
        _address = profile['address'] != null
            ? Map<String, dynamic>.from(profile['address'])
            : null;
        _documents = profile['documents'] != null
            ? Map<String, dynamic>.from(profile['documents'])
            : null;
        _avatarUrl = ApiClient.resolveImageUrl(profile['avatarUrl']?.toString());

        _firstNameController.text = profile['givenName'] ?? '';
        _lastNameController.text = profile['surname'] ?? '';
        _emailController.text = profile['email'] ?? '';
        _phoneController.text = profile['contactNumber'] ?? '';
        _vehicleTypeController.text = profile['vehicleType'] ?? '';
        _licenseNumberController.text = profile['licenseNumber'] ?? '';

        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      _populateFromAuthUser();
      setState(() {
        _error = ref.read(authProvider).user == null
            ? 'Failed to load rider profile. Please try again.'
            : null;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!ref.read(authProvider).isVerified) {
      AlertService.showSnackBar(
        context: context,
        message: 'Account not verified. Cannot save changes.',
        variant: AlertVariant.warning,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthApi.updateRiderProfile(
        givenName: _firstNameController.text.trim(),
        surname: _lastNameController.text.trim(),
        contactNumber: _phoneController.text.trim(),
        vehicleType: _vehicleTypeController.text.trim(),
        licenseNumber: _licenseNumberController.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _isLoading = false;
      });

      AlertService.showSnackBar(
        context: context,
        message: 'Profile changes saved.',
        variant: AlertVariant.success,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AlertService.showSnackBar(
        context: context,
        message: 'Failed to save profile changes.',
        variant: AlertVariant.error,
      );
    }
  }

  Future<void> _uploadAvatar() async {
    if (!ref.read(authProvider).isVerified) {
      AlertService.showSnackBar(
        context: context,
        message: 'Account not verified. Cannot upload avatar.',
        variant: AlertVariant.warning,
      );
      return;
    }

    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _isLoading = true);
    try {
      final avatarUrl = await AuthApi.uploadRiderAvatar(File(picked.path));
      if (!mounted) return;
      setState(() {
        _avatarUrl = ApiClient.resolveImageUrl(avatarUrl);
        _isLoading = false;
      });
      AlertService.showSnackBar(
        context: context,
        message: 'Profile photo updated.',
        variant: AlertVariant.success,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AlertService.showSnackBar(
        context: context,
        message: 'Failed to upload profile photo.',
        variant: AlertVariant.error,
      );
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) context.go(AppRouter.landing);
    }
  }

  Future<void> _editAddress(bool isVerified) async {
    if (!isVerified) {
      AlertService.showSnackBar(
        context: context,
        message: 'Account not verified. Cannot edit address.',
        variant: AlertVariant.warning,
      );
      return;
    }

    AddressData? draft = _address != null ? AddressData.fromJson(_address!) : null;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Edit address',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 12),
                  AddressSelector(
                    value: draft,
                    onChange: (a) => setModal(() => draft = a),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      if (draft == null || !draft!.isComplete) {
                        AlertService.showSnackBar(
                          context: ctx,
                          message: 'Please complete your address',
                          variant: AlertVariant.warning,
                        );
                        return;
                      }
                      Navigator.pop(ctx, true);
                    },
                    child: const Text('Save address'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (saved != true || draft == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await AuthApi.updateRiderProfile(address: draft!.toJson());
      await _loadProfile();
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: 'Address updated.',
          variant: AlertVariant.success,
        );
      }
    } catch (_) {
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: 'Failed to update address.',
          variant: AlertVariant.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reuploadDocument(String field) async {
    if (!ref.read(authProvider).isVerified) {
      AlertService.showSnackBar(
        context: context,
        message: 'Account not verified. Cannot upload documents.',
        variant: AlertVariant.warning,
      );
      return;
    }

    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _isLoading = true);
    try {
      final file = File(picked.path);
      await AuthApi.uploadRiderDocuments(
        license: field == 'license' ? file : null,
        orCr: field == 'orCr' ? file : null,
      );
      await _loadProfile();
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: 'Document updated.',
          variant: AlertVariant.success,
        );
      }
    } catch (_) {
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: 'Failed to upload document.',
          variant: AlertVariant.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _viewDocument(String? path, String title) {
    final url = ApiClient.resolveImageUrl(path);
    if (url == null) {
      AlertService.showSnackBar(
        context: context,
        message: 'Document not available.',
        variant: AlertVariant.warning,
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                height: 360,
                width: double.infinity,
                errorWidget: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Icon(Icons.broken_image_outlined, size: 48),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isVerified = ref.watch(authProvider).isVerified;
    final bg = isDark ? AppColors.darkBackground : AppColors.background;

    if (_isLoading && _firstNameController.text.isEmpty && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ColoredBox(
      color: bg,
      child: RefreshIndicator(
        onRefresh: _loadProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manage your rider account information.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              if (!isVerified) ...[
                const RiderVerificationNotice(),
                const SizedBox(height: 16),
              ],
              if (_error != null) ...[
                _buildErrorBanner(_error!),
                const SizedBox(height: 16),
              ],
              _buildProfileHeader(theme, isVerified),
              const SizedBox(height: 16),
              _buildPersonalInfoSection(theme, isVerified),
              const SizedBox(height: 16),
              _buildVehicleSection(theme, isVerified),
              if (_address != null && _hasAddressData) ...[
                const SizedBox(height: 16),
                _buildAddressSection(theme, isVerified),
              ],
              if (_documents != null) ...[
                const SizedBox(height: 16),
                _buildDocumentsSection(theme, isVerified),
              ],
              const SizedBox(height: 24),
              _buildLogoutButton(),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasAddressData {
    if (_address == null) return false;
    return _address!.values.any(
      (v) => v != null && v.toString().trim().isNotEmpty && v != 'None',
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme, bool isVerified) {
    final resolvedAvatar = _avatarUrl;

    return YamadaCard(
      hasShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: resolvedAvatar == null
                      ? const LinearGradient(
                          colors: [AppColors.rosewood, AppColors.blush],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: resolvedAvatar != null
                      ? theme.colorScheme.surfaceContainerHighest
                      : null,
                ),
                child: ClipOval(
                  child: resolvedAvatar != null
                      ? CachedNetworkImage(
                          imageUrl: resolvedAvatar,
                          fit: BoxFit.cover,
                          width: 96,
                          height: 96,
                          errorWidget: (_, __, ___) => Icon(
                            Icons.person,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      : Icon(
                          Icons.two_wheeler_rounded,
                          size: 44,
                          color: theme.colorScheme.onPrimary,
                        ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: isVerified ? _uploadAvatar : null,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.surface,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.camera_alt_outlined,
                      size: 16,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${_firstNameController.text} ${_lastNameController.text}'.trim(),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            _emailController.text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          RiderDeliveryStatusBadge(
            status: isVerified ? 'delivered' : 'pending',
            label: isVerified ? 'Verified rider' : 'Pending verification',
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection(ThemeData theme, bool isVerified) {
    return YamadaCard(
      hasShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _sectionTitle(theme, 'Personal Information', Icons.person_outline),
              ),
              if (!_isEditing)
                TextButton.icon(
                  onPressed: isVerified ? () => setState(() => _isEditing = true) : null,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextField('First Name', _firstNameController, enabled: _isEditing && isVerified),
          const SizedBox(height: 12),
          _buildTextField('Last Name', _lastNameController, enabled: _isEditing && isVerified),
          const SizedBox(height: 12),
          _buildTextField('Email', _emailController, enabled: false),
          const SizedBox(height: 12),
          _buildTextField(
            'Phone',
            _phoneController,
            enabled: _isEditing && isVerified,
            keyboardType: TextInputType.phone,
          ),
          if (_isEditing) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _isEditing = false);
                      _loadProfile();
                    },
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVehicleSection(ThemeData theme, bool isVerified) {
    return YamadaCard(
      hasShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(theme, 'Vehicle Information', Icons.two_wheeler_outlined),
          const SizedBox(height: 12),
          _buildTextField(
            'Vehicle Type',
            _vehicleTypeController,
            enabled: _isEditing && isVerified,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            'License Number',
            _licenseNumberController,
            enabled: _isEditing && isVerified,
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection(ThemeData theme, bool isVerified) {
    return YamadaCard(
      hasShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _sectionTitle(
                  theme,
                  'Address Information',
                  Icons.location_on_outlined,
                ),
              ),
              if (isVerified)
                TextButton(
                  onPressed: () => _editAddress(isVerified),
                  child: const Text('Edit'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_address!['regionName']?.toString().isNotEmpty == true)
            _buildInfoRow('Region', _address!['regionName']),
          if (_address!['provinceName']?.toString().isNotEmpty == true)
            _buildInfoRow('Province', _address!['provinceName']),
          if (_address!['municipalityName']?.toString().isNotEmpty == true)
            _buildInfoRow('City / Municipality', _address!['municipalityName']),
          if (_address!['barangayName']?.toString().isNotEmpty == true)
            _buildInfoRow('Barangay', _address!['barangayName']),
          if (_address!['streetAddress']?.toString().isNotEmpty == true)
            _buildInfoRow('Street', _address!['streetAddress']),
          if (_address!['postalCode']?.toString().isNotEmpty == true)
            _buildInfoRow('Postal Code', _address!['postalCode']),
        ],
      ),
    );
  }

  Widget _buildDocumentsSection(ThemeData theme, bool isVerified) {
    return YamadaCard(
      hasShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(theme, 'Documents', Icons.folder_outlined),
          const SizedBox(height: 8),
          _buildDocumentTile(
            theme,
            icon: Icons.badge_outlined,
            title: "Driver's License",
            subtitle: 'Uploaded during registration',
            path: _documents!['license'] ?? _documents!['licensePath'],
            onReupload: isVerified ? () => _reuploadDocument('license') : null,
          ),
          const Divider(height: 20),
          _buildDocumentTile(
            theme,
            icon: Icons.description_outlined,
            title: 'OR/CR',
            subtitle: 'Vehicle registration document',
            path: _documents!['orCr'] ?? _documents!['orCrPath'],
            onReupload: isVerified ? () => _reuploadDocument('orCr') : null,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool enabled = true,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: enabled
            ? null
            : Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentTile(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    String? path,
    VoidCallback? onReupload,
  }) {
    final hasFile = path != null && path.trim().isNotEmpty;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (onReupload != null)
          TextButton(
            onPressed: onReupload,
            child: const Text('Re-upload'),
          ),
        if (hasFile)
          TextButton(
            onPressed: () => _viewDocument(path, title),
            child: const Text('View'),
          )
        else if (onReupload == null)
          Text(
            'No file',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _handleLogout,
        icon: const Icon(Icons.logout, size: 18, color: Colors.red),
        label: const Text(
          'Sign Out',
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
