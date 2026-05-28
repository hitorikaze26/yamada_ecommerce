import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:location/location.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/env_config.dart';

final riderLocationServiceProvider = Provider<RiderLocationService>((ref) {
  return RiderLocationService();
});

class RiderLocationService {
  io.Socket? _socket;
  StreamSubscription<LocationData>? _locationSub;
  Timer? _emitTimer;
  LocationData? _lastLocation;
  bool _isTracking = false;
  String? _token;
  List<int> _activeOrderIds = [];

  LocationData? get lastLocation => _lastLocation;
  bool get isTracking => _isTracking;

  static String socketBaseUrl() {
    final apiBase = EnvConfig.apiBaseUrl;
    final uri = Uri.parse(apiBase);
    if (uri.hasPort) {
      return '${uri.scheme}://${uri.host}:${uri.port}';
    }
    return '${uri.scheme}://${uri.host}';
  }

  void connect({required String token}) {
    if (_socket?.connected == true && _token == token) return;
    disconnect();
    _token = token;

    final url = socketBaseUrl();
    developer.log('RiderLocationSocket connecting to $url', name: 'RiderLocation');

    _socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .disableReconnection()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {
      developer.log('RiderLocationSocket connected', name: 'RiderLocation');
    });

    _socket!.onDisconnect((_) {
      developer.log('RiderLocationSocket disconnected', name: 'RiderLocation');
    });

    _socket!.onConnectError((data) {
      developer.log('RiderLocationSocket connect error: $data', name: 'RiderLocation');
    });
  }

  Future<void> startTracking({required List<int> orderIds}) async {
    if (_token == null) {
      developer.log('Cannot start tracking: no token', name: 'RiderLocation');
      return;
    }

    _activeOrderIds = orderIds;
    if (_isTracking) return;
    _isTracking = true;

    final location = Location();
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        _isTracking = false;
        return;
      }
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        _isTracking = false;
        return;
      }
    }

    _locationSub = location.onLocationChanged.listen((loc) {
      _lastLocation = loc;
    });

    _emitTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _emitLocation();
    });

    developer.log('Rider location tracking started', name: 'RiderLocation');
  }

  void _emitLocation() {
    final loc = _lastLocation;
    if (loc == null) return;
    if (_socket?.connected != true) return;

    for (final orderId in _activeOrderIds) {
      _socket!.emit('rider:location', {
        'orderId': orderId,
        'latitude': loc.latitude,
        'longitude': loc.longitude,
      });
    }

    developer.log(
      'Emitted rider:location for ${_activeOrderIds.length} orders',
      name: 'RiderLocation',
    );
  }

  void updateOrderIds(List<int> orderIds) {
    _activeOrderIds = orderIds;
  }

  void stopTracking() {
    _isTracking = false;
    _locationSub?.cancel();
    _locationSub = null;
    _emitTimer?.cancel();
    _emitTimer = null;
    _activeOrderIds = [];
    developer.log('Rider location tracking stopped', name: 'RiderLocation');
  }

  void disconnect() {
    stopTracking();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _token = null;
  }

  void dispose() {
    disconnect();
  }
}
