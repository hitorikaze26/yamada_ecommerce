import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/rider_location_service.dart';
import '../../../core/services/secure_storage.dart';
import '../../../core/utils/address_utils.dart';
import '../../../data/models/rider_delivery_model.dart';
import '../../../data/providers/rider_notifier.dart';

class RiderLiveTrackingPage extends ConsumerStatefulWidget {
  final int? orderId;

  const RiderLiveTrackingPage({super.key, this.orderId});

  @override
  ConsumerState<RiderLiveTrackingPage> createState() =>
      _RiderLiveTrackingPageState();
}

class _RiderLiveTrackingPageState
    extends ConsumerState<RiderLiveTrackingPage> {
  final MapController _mapController = MapController();
  bool _isBroadcasting = false;

  RiderDeliveryModel? get _targetDelivery {
    final deliveries = ref.read(riderProvider).deliveries;
    if (widget.orderId != null) {
      return deliveries.where((d) => d.id == widget.orderId).firstOrNull;
    }
    final active = ref.read(riderProvider.notifier).activeDeliveries;
    return active.isNotEmpty ? active.first : null;
  }

  List<RiderDeliveryModel> get _activeDeliveries {
    return ref.read(riderProvider.notifier).activeDeliveries;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initTracking());
  }

  Future<void> _initTracking() async {
    final token = await SecureStorage.getToken();
    if (token == null) return;

    final locService = ref.read(riderLocationServiceProvider);
    locService.connect(token: token);

    final orderIds = _activeDeliveries
        .map((d) => d.orderId ?? d.id)
        .where((id) => id > 0)
        .toList();

    if (orderIds.isNotEmpty) {
      await locService.startTracking(orderIds: orderIds);
      if (mounted) {
        setState(() => _isBroadcasting = locService.isTracking);
      }
    }
  }

  void _toggleBroadcast() {
    final locService = ref.read(riderLocationServiceProvider);
    if (_isBroadcasting) {
      locService.stopTracking();
      setState(() => _isBroadcasting = false);
    } else {
      final orderIds = _activeDeliveries
          .map((d) => d.orderId ?? d.id)
          .where((id) => id > 0)
          .toList();
      if (orderIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active deliveries to broadcast')),
        );
        return;
      }
      SecureStorage.getToken().then((token) {
        if (token != null) {
          locService.connect(token: token);
          locService.startTracking(orderIds: orderIds).then((_) {
            if (mounted) {
              setState(() => _isBroadcasting = locService.isTracking);
            }
          });
        }
      });
    }
  }

  Future<void> _navigateToDropoff(RiderDeliveryModel delivery) async {
    final address = AddressUtils.formatShippingAddress(
      shippingAddress: delivery.shippingAddress,
      municipalityName: delivery.municipalityName,
    );
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locService = ref.watch(riderLocationServiceProvider);
    final lastLoc = locService.lastLocation;
    final colorScheme = Theme.of(context).colorScheme;

    final riderPos = lastLoc != null
        ? LatLng(lastLoc.latitude!, lastLoc.longitude!)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tracking'),
        actions: [
          IconButton(
            icon: Icon(
              _isBroadcasting ? Icons.location_on : Icons.location_off,
              color: _isBroadcasting ? Colors.green : Colors.grey,
            ),
            tooltip:
                _isBroadcasting ? 'Stop broadcasting' : 'Start broadcasting',
            onPressed: _toggleBroadcast,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: riderPos ?? const LatLng(14.5995, 120.9842),
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.yamada.app',
              ),
              if (riderPos != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: riderPos,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 36,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _buildDeliveryCard(colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard(ColorScheme colorScheme) {
    final delivery = _targetDelivery;
    if (delivery == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Text('No active deliveries'),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping, size: 18),
              const SizedBox(width: 8),
              Text(
                delivery.displayLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (_isBroadcasting)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Live',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            delivery.storeName ?? 'Store',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            AddressUtils.formatShippingAddress(
              shippingAddress: delivery.shippingAddress,
              municipalityName: delivery.municipalityName,
            ),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (delivery.status == 'pickup' || delivery.status == 'transit') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _navigateToDropoff(delivery),
                icon: const Icon(Icons.navigation, size: 18),
                label: const Text('Navigate'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
