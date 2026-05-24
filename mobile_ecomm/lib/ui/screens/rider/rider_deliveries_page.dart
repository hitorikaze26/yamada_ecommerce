import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/address_utils.dart';
import '../../../core/utils/format_utils.dart';
import '../../../data/models/rider_delivery_model.dart';
import '../../../data/providers/auth_notifier.dart';
import '../../../data/providers/rider_notifier.dart';
import '../../../data/services/auth_api.dart';
import '../../widgets/custom_cards.dart';
import '../../widgets/chat/chat_navigation.dart';
import '../../widgets/rider_delivery_widgets.dart';
import '../../../core/report/report_navigation.dart';

class RiderDeliveriesPage extends ConsumerStatefulWidget {
  const RiderDeliveriesPage({super.key});

  @override
  ConsumerState<RiderDeliveriesPage> createState() =>
      _RiderDeliveriesPageState();
}

class _RiderDeliveriesPageState extends ConsumerState<RiderDeliveriesPage> {
  final List<String> _tabs = ['active', 'completed', 'all'];
  int _activeTabIndex = 0;
  String? _selectedMunicipality;
  String? _riderMunicipality;
  RiderDeliveryModel? _selectedDelivery;
  RiderDeliveryModel? _deliveryToMarkDelivered;
  final TextEditingController _proofNoteController = TextEditingController();
  File? _proofPhoto;
  bool _isSubmittingProof = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(riderProvider.notifier).load();
      _loadProfileMunicipality();
    });
  }

  @override
  void dispose() {
    _proofNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileMunicipality() async {
    try {
      final profile = await AuthApi.getRiderProfile();
      final address = profile['address'];
      if (address is Map) {
        final municipality = address['municipalityName'] as String?;
        if (municipality != null && mounted) {
          setState(() {
            _riderMunicipality = municipality;
            _selectedMunicipality = municipality;
          });
        }
      }
    } catch (_) {}
  }

  List<String> get _municipalities {
    final names = <String>{};
    for (final d in ref.read(riderProvider).deliveries) {
      if (d.municipalityName != null) names.add(d.municipalityName!);
    }
    if (_riderMunicipality != null) names.add(_riderMunicipality!);
    return names.toList()..sort();
  }

  List<RiderDeliveryModel> _filtered(List<RiderDeliveryModel> all) {
    return all.where((d) {
      if (_activeTabIndex == 0) {
        if (!['pickup', 'transit', 'pending'].contains(d.status)) return false;
      } else if (_activeTabIndex == 1) {
        if (d.status != 'delivered') return false;
      }
      if (_selectedMunicipality != null && _selectedMunicipality != 'all') {
        if (d.municipalityName != _selectedMunicipality) return false;
      }
      return true;
    }).toList();
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pickup':
        return 'Ready for Pickup';
      case 'transit':
        return 'In Transit';
      case 'pending':
        return 'Shipped';
      case 'delivered':
        return 'Delivered';
      default:
        return status;
    }
  }

  String _formatAddress(RiderDeliveryModel delivery) {
    return AddressUtils.formatShippingAddress(
      shippingAddress: delivery.shippingAddress,
      municipalityName: delivery.municipalityName,
    );
  }

  Future<void> _pickProofPhoto(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (picked != null) setState(() => _proofPhoto = File(picked.path));
    } catch (e) {
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: 'Failed to pick image: $e',
          variant: AlertVariant.error,
        );
      }
    }
  }

  Future<void> _submitProofOfDelivery() async {
    final delivery = _deliveryToMarkDelivered;
    if (delivery == null) return;
    if (_proofPhoto == null) {
      AlertService.showSnackBar(
        context: context,
        message: 'Please attach a delivery photo as proof',
        variant: AlertVariant.warning,
      );
      return;
    }

    setState(() => _isSubmittingProof = true);
    try {
      await ref.read(riderProvider.notifier).uploadProof(
            delivery,
            note: _proofNoteController.text,
            photo: _proofPhoto,
          );
      if (!mounted) return;
      setState(() {
        _deliveryToMarkDelivered = null;
        _proofNoteController.clear();
        _proofPhoto = null;
      });
      AlertService.showSnackBar(
        context: context,
        message: 'Delivery completed successfully',
        variant: AlertVariant.success,
      );
    } catch (e) {
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: e.toString().replaceFirst('Exception: ', ''),
          variant: AlertVariant.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingProof = false);
    }
  }

  Widget _buildDeliveryCard(RiderDeliveryModel delivery) {
    final theme = Theme.of(context);
    final buyer = delivery.buyer;
    final buyerMeta = buyer == null
        ? null
        : '${buyer['name'] ?? buyer['email'] ?? 'Unknown'}${buyer['contact'] != null ? ' · ${buyer['contact']}' : ''}';

    return YamadaCard(
      margin: const EdgeInsets.only(bottom: 12),
      hasShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Text(
                          delivery.displayLabel,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        RiderDeliveryStatusBadge(
                          status: delivery.status,
                          label: _getStatusLabel(delivery.status),
                        ),
                      ],
                    ),
                    if (delivery.isAutoMatched)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: RiderDeliveryNewBadge(),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    FormatUtils.peso(delivery.fee),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    delivery.distanceKm != null
                        ? '${delivery.distanceKm!.toStringAsFixed(1)} km'
                        : 'Delivery fee',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          RiderDeliveryRoute(
            pickup: RiderDeliveryLocationBlock(
              type: DeliveryLocationType.pickup,
              subtitle: delivery.storeName ??
                  delivery.pickupAddress ??
                  _riderMunicipality ??
                  'Your area',
            ),
            dropoff: RiderDeliveryLocationBlock(
              type: DeliveryLocationType.dropoff,
              subtitle: _formatAddress(delivery),
              meta: buyerMeta,
              isDeliveryComplete: delivery.status == 'delivered',
            ),
          ),
          const SizedBox(height: 16),
          _buildDeliveryActions(delivery),
        ],
      ),
    );
  }

  Widget _buildDeliveryActions(RiderDeliveryModel delivery) {
    final notifier = ref.read(riderProvider.notifier);

    Widget? primaryAction;
    if (delivery.isAutoMatched) {
      primaryAction = FilledButton.icon(
        onPressed: () async {
          try {
            await notifier.acceptDelivery(delivery);
            if (mounted) {
              AlertService.showSnackBar(
                context: context,
                message: 'Delivery accepted.',
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
          }
        },
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFD97706),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(44),
        ),
        icon: const Icon(Icons.check_circle_outline, size: 18),
        label: const Text('Accept delivery'),
      );
    } else if (delivery.status == 'pending') {
      primaryAction = FilledButton.icon(
        onPressed: () => notifier.updateStatus(delivery, 'pickup'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
        icon: const Icon(Icons.store_outlined, size: 18),
        label: const Text('Start pickup'),
      );
    } else if (delivery.status == 'pickup') {
      primaryAction = FilledButton.icon(
        onPressed: () => notifier.updateStatus(delivery, 'transit'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.processing,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(44),
        ),
        icon: const Icon(Icons.local_shipping_outlined, size: 18),
        label: const Text('On the way'),
      );
    } else if (delivery.status == 'transit') {
      primaryAction = FilledButton.icon(
        onPressed: () => setState(() => _deliveryToMarkDelivered = delivery),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.processing,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(44),
        ),
        icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
        label: const Text('Upload proof of delivery'),
      );
    }

    if (primaryAction == null) {
      return Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () => setState(() => _selectedDelivery = delivery),
          child: const Text('View details'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: primaryAction),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => setState(() => _selectedDelivery = delivery),
              child: const Text('Details'),
            ),
          ],
        ),
        if (delivery.storeId != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => openRiderSellerChat(
              context,
              ref,
              storeId: delivery.storeId!,
              orderId: delivery.orderId,
            ),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: const Text('Message seller'),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final riderState = ref.watch(riderProvider);
    final isVerified = ref.watch(authProvider).isVerified;
    final filtered = _filtered(riderState.deliveries);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deliveries'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Manage your delivery assignments. New deliveries in your area will appear here automatically.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ),
              if (riderState.notVerified || !isVerified) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: RiderVerificationNotice(),
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: RiderDeliveryFilterBar(
                    tabs: _tabs,
                    activeTabIndex: _activeTabIndex,
                    onTabChanged: (i) => setState(() => _activeTabIndex = i),
                    selectedMunicipality: _selectedMunicipality,
                    municipalities: _municipalities,
                    onMunicipalityChanged: (val) => setState(
                      () => _selectedMunicipality = val == 'all' ? null : val,
                    ),
                  ),
                ),
                if (riderState.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: MaterialBanner(
                      content: Text(riderState.error!),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              ref.read(riderProvider.notifier).refresh(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: riderState.isLoading && filtered.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : filtered.isEmpty
                          ? RiderDeliveriesEmptyState(
                              tabLabel: _tabs[_activeTabIndex],
                            )
                          : RefreshIndicator(
                              onRefresh: () =>
                                  ref.read(riderProvider.notifier).refresh(),
                              child: ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                itemCount: filtered.length,
                                itemBuilder: (_, i) =>
                                    _buildDeliveryCard(filtered[i]),
                              ),
                            ),
                ),
              ],
            ],
          ),
          if (_selectedDelivery != null) _buildDetailsModal(),
          if (_deliveryToMarkDelivered != null) _buildProofModal(),
        ],
      ),
    );
  }

  Widget _buildDetailsModal() {
    final delivery = _selectedDelivery!;
    final buyer = delivery.buyer;
    final items = delivery.items ?? [];
    final theme = Theme.of(context);
    final notes = delivery.deliveryNotes?.trim();

    return RiderDeliveryModal(
      subtitle: 'Delivery Details',
      title: delivery.displayLabel,
      onClose: () => setState(() => _selectedDelivery = null),
      actions: [
        if (delivery.storeId != null && delivery.orderId != null)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                openReportSubmit(
                  context,
                  targetRole: 'seller',
                  storeId: delivery.storeId,
                  orderId: delivery.orderId,
                  label: delivery.storeName,
                );
              },
              icon: const Icon(Icons.storefront_outlined, size: 18),
              label: const Text('Report seller'),
            ),
          ),
        if (delivery.buyer?['id'] != null && delivery.orderId != null) ...[
          if (delivery.storeId != null) const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                final buyerId = delivery.buyer!['id'];
                openReportSubmit(
                  context,
                  targetRole: 'buyer',
                  orderId: delivery.orderId,
                  targetUserId: buyerId is int
                      ? buyerId
                      : int.tryParse(buyerId.toString()),
                  label: delivery.buyer!['name']?.toString(),
                );
              },
              icon: const Icon(Icons.person_off_outlined, size: 18),
              label: const Text('Report buyer'),
            ),
          ),
        ],
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => setState(() => _selectedDelivery = null),
            child: const Text('Close'),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order #${delivery.orderId ?? '—'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (buyer != null) ...[
            Text('Buyer information',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(buyer['name'] ?? buyer['email'] ?? 'Unknown'),
            if (buyer['contact'] != null)
              Text('Contact: ${buyer['contact']}'),
            const SizedBox(height: 16),
          ],
          Text('Items',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text('No item details available.')
          else
            ...items.map(
              (item) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(item['name'] ?? 'Item')),
                  Text('x${item['quantity']}'),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Text('Delivery instructions',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            notes != null && notes.isNotEmpty
                ? notes
                : 'No special instructions from the buyer.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProofModal() {
    final theme = Theme.of(context);

    return RiderDeliveryModal(
      subtitle: 'Proof of Delivery',
      title: 'Proof of delivery',
      onClose: () {
        setState(() {
          _deliveryToMarkDelivered = null;
          _proofPhoto = null;
          _proofNoteController.clear();
        });
      },
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _deliveryToMarkDelivered = null;
                    _proofPhoto = null;
                    _proofNoteController.clear();
                  });
                },
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _isSubmittingProof ? null : _submitProofOfDelivery,
                child: _isSubmittingProof
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit & complete'),
              ),
            ),
          ],
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attach a clear photo as proof. The delivery will be marked complete when you submit.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          if (_proofPhoto != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _proofPhoto!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickProofPhoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickProofPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _proofNoteController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
            ),
          ),
        ],
      ),
    );
  }
}
