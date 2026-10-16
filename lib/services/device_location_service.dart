import 'dart:async';

import 'package:geolocator/geolocator.dart';

class DevicePosition {
  const DevicePosition({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
}

abstract interface class DeviceLocationClient {
  Future<DevicePosition> currentPosition();

  Future<bool> openAppSettings();

  Future<bool> openLocationSettings();
}

class GeolocatorDeviceLocationClient implements DeviceLocationClient {
  @override
  Future<DevicePosition> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const DeviceLocationException(
        DeviceLocationFailure.serviceDisabled,
        'Ative a localizacao do aparelho para buscar profissionais proximos.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const DeviceLocationException(
        DeviceLocationFailure.permissionDenied,
        'A permissao de localizacao foi negada.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const DeviceLocationException(
        DeviceLocationFailure.permissionDeniedForever,
        'Libere a localizacao nas configuracoes do aplicativo.',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return DevicePosition(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );
    } on TimeoutException {
      throw const DeviceLocationException(
        DeviceLocationFailure.unavailable,
        'Nao foi possivel obter sua localizacao a tempo. Tente novamente.',
      );
    } catch (_) {
      throw const DeviceLocationException(
        DeviceLocationFailure.unavailable,
        'Nao foi possivel obter sua localizacao. Tente novamente.',
      );
    }
  }

  @override
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }
}

enum DeviceLocationFailure {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

class DeviceLocationException implements Exception {
  const DeviceLocationException(this.failure, this.message);

  final DeviceLocationFailure failure;
  final String message;
}
