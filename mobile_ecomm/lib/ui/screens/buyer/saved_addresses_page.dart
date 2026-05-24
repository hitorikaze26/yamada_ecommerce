import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/alert_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/address_model.dart';
import '../../../data/services/addresses_api.dart';
import '../../widgets/address_selector.dart';

class SavedAddressesPage extends StatefulWidget {
  const SavedAddressesPage({super.key});

  @override
  State<SavedAddressesPage> createState() => _SavedAddressesPageState();
}

class _SavedAddressesPageState extends State<SavedAddressesPage> {
  List<SavedAddress> _addresses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await AddressesApi.loadAddresses();
      if (mounted) {
        setState(() {
          _addresses = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _openForm({SavedAddress? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddressFormSheet(existing: existing),
    );
    if (saved == true) await _load();
  }

  Future<void> _setDefault(SavedAddress address) async {
    final ok = await AddressesApi.setDefaultAddress(address.id);
    if (mounted) {
      if (ok) {
        AlertService.showSnackBar(
          context: context,
          message: 'Default address updated',
          variant: AlertVariant.success,
        );
        await _load();
      } else {
        AlertService.showSnackBar(
          context: context,
          message: 'Could not update default',
          variant: AlertVariant.error,
        );
      }
    }
  }

  Future<void> _delete(SavedAddress address) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text('Remove "${address.label}" from saved addresses?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await AddressesApi.deleteAddress(address.id);
    if (mounted) {
      if (ok) await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.background;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? AppColors.darkForeground : AppColors.charcoal,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Saved Addresses',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkForeground : AppColors.charcoal,
              ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_location_alt_outlined, color: Colors.white),
        label: const Text('Add address', style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Center(child: CircularProgressIndicator(color: AppColors.primary)),
                ],
              )
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(onPressed: _load, child: const Text('Retry')),
                      ),
                    ],
                  )
            : _addresses.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 80),
                      Icon(Icons.location_off_outlined,
                          size: 64,
                          color: isDark
                              ? AppColors.darkMutedForeground
                              : AppColors.mutedForeground),
                      const SizedBox(height: 16),
                      Text(
                        'No saved addresses yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkForeground
                              : AppColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add a delivery address for faster checkout.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark
                              ? AppColors.darkMutedForeground
                              : AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    itemCount: _addresses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final addr = _addresses[index];
                      return _AddressCard(
                        address: addr,
                        isDark: isDark,
                        onEdit: () => _openForm(existing: addr),
                        onDelete: () => _delete(addr),
                        onSetDefault: () => _setDefault(addr),
                      )
                          .animate()
                          .fadeIn(duration: 350.ms, delay: (35 * index).ms);
                    },
                  ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final SavedAddress address;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  const _AddressCard({
    required this.address,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.darkCard : AppColors.card;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final data = address.addressData;

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: address.isDefault ? AppColors.primary : borderColor,
            width: address.isDefault ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _labelChip(address.label, isDark),
                if (address.isDefault) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Default',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onEdit,
                  color: isDark ? AppColors.darkMutedForeground : null,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: onDelete,
                  color: Colors.red.shade400,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              data.formattedAddress,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark
                    ? AppColors.darkMutedForeground
                    : AppColors.mutedForeground,
              ),
            ),
            if (!address.isDefault) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: onSetDefault,
                child: const Text('Set as default'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _labelChip(String label, bool isDark) {
    final isHome = label.toLowerCase() == 'home';
    final isWork = label.toLowerCase() == 'work';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isHome
            ? AppColors.primary.withValues(alpha: 0.15)
            : isWork
                ? AppColors.lilac.withValues(alpha: 0.35)
                : (isDark ? AppColors.darkMuted : AppColors.muted),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: isDark ? AppColors.darkForeground : AppColors.charcoal,
        ),
      ),
    );
  }
}

class _AddressFormSheet extends StatefulWidget {
  final SavedAddress? existing;

  const _AddressFormSheet({this.existing});

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  static const _labels = ['Home', 'Work', 'Other'];
  String _label = 'Home';
  bool _isDefault = false;
  bool _saving = false;
  AddressData? _addressData;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _label = widget.existing!.label;
      _isDefault = widget.existing!.isDefault;
      _addressData = widget.existing!.addressData;
    }
  }

  Future<void> _save() async {
    final data = _addressData;
    if (data == null || !data.isComplete) {
      AlertService.showSnackBar(
        context: context,
        message: 'Please complete region, city/municipality, and barangay',
        variant: AlertVariant.warning,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (widget.existing != null) {
        await AddressesApi.updateAddress(
          id: widget.existing!.id,
          label: _label,
          addressData: data,
          isDefault: _isDefault ? true : null,
        );
      } else {
        await AddressesApi.addAddress(
          label: _label,
          addressData: data,
          isDefault: _isDefault,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: 'Failed to save address',
          variant: AlertVariant.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkCard : Colors.white;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.existing == null ? 'Add address' : 'Edit address',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 16),
              Text('Address type', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _labels.map((l) {
                  final selected = _label == l;
                  return ChoiceChip(
                    label: Text(l),
                    selected: selected,
                    onSelected: (_) => setState(() => _label = l),
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Set as default delivery address'),
                value: _isDefault,
                activeThumbColor: AppColors.primary,
                onChanged: (v) => setState(() => _isDefault = v),
              ),
              const SizedBox(height: 8),
              AddressSelector(
                value: _addressData,
                onChange: (d) => setState(() => _addressData = d),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(widget.existing == null ? 'Save address' : 'Update address'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
