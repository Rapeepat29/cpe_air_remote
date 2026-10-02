import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/provisioning.dart';

class BleProvisioningService {
  static final serviceUuid = Guid(
    '7b570001-a243-4e5b-8f13-179af81b2457',
  );
  static final configUuid = Guid(
    '7b570002-a243-4e5b-8f13-179af81b2457',
  );
  static final statusUuid = Guid(
    '7b570003-a243-4e5b-8f13-179af81b2457',
  );
  static final identityUuid = Guid(
    '7b570004-a243-4e5b-8f13-179af81b2457',
  );
  static final wifiScanUuid = Guid(
    '7b570005-a243-4e5b-8f13-179af81b2457',
  );
  static final settingsUuid = Guid(
    '7b570006-a243-4e5b-8f13-179af81b2457',
  );

  Future<List<BleDeviceCandidate>> scan({
    Duration duration = const Duration(seconds: 8),
    String namePrefix = 'RMUTT-AC-',
  }) async {
    if (!await FlutterBluePlus.isSupported) {
      throw const BleProvisioningException(
        'Bluetooth Low Energy is not supported on this computer.',
      );
    }
    await FlutterBluePlus.adapterState
        .where((state) => state == BluetoothAdapterState.on)
        .first
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw const BleProvisioningException(
            'Please turn on Bluetooth and try again.',
          ),
        );

    final found = <String, BleDeviceCandidate>{};
    final subscription = FlutterBluePlus.onScanResults.listen((results) {
      for (final result in results) {
        final name = (result.advertisementData.advName.isNotEmpty
            ? result.advertisementData.advName
            : result.device.platformName)
            .trim();
        if (!name.startsWith(namePrefix)) continue;
        found[result.device.remoteId.str] = BleDeviceCandidate(
          device: result.device,
          name: name,
          rssi: result.rssi,
        );
      }
    });
    try {
      // Scan without a service filter. On Windows, a recovered ESP32 can place
      // its name in the scan response and its service UUID in the primary
      // advertisement; some Bluetooth drivers fail to match that combination
      // when withServices is used. We still accept only the requested name
      // prefix and verify the service/identity before provisioning.
      await FlutterBluePlus.startScan(
        timeout: duration,
      );
      await FlutterBluePlus.isScanning
          .where((scanning) => !scanning)
          .first
          .timeout(duration + const Duration(seconds: 2));
    } finally {
      await FlutterBluePlus.stopScan();
      await subscription.cancel();
    }

    final results = found.values.toList()
      ..sort((left, right) => right.rssi.compareTo(left.rssi));
    return results;
  }

  Future<BleDeviceIdentity> readIdentity(BleDeviceCandidate candidate) async {
    final connection = await _connect(candidate.device);
    try {
      final value = await connection.identity.read(timeout: 12);
      final decoded = jsonDecode(utf8.decode(value));
      if (decoded is! Map<String, dynamic>) {
        throw const BleProvisioningException(
          'ESP32 returned invalid identity data.',
        );
      }
      final identityJson = Map<String, dynamic>.from(decoded);

      // Firmware 1.6+ keeps the first identity read intentionally short for
      // reliable WinRT/Windows GATT reads. Saved board settings live in an
      // optional second characteristic. Older firmware remains compatible
      // because it already returns those fields in the identity value.
      if (identityJson['configured'] == true && connection.settings != null) {
        try {
          final settingsValue = await connection.settings!.read(timeout: 8);
          final settingsDecoded = jsonDecode(utf8.decode(settingsValue));
          if (settingsDecoded is Map<String, dynamic>) {
            identityJson.addAll(settingsDecoded);
          }
        } catch (_) {
          // The core identity is enough to add/verify the board. Reconfigure
          // can continue with database values if the optional read fails.
        }
      }

      final identity = BleDeviceIdentity.fromJson(identityJson);
      final isAirIdentity = candidate.name.startsWith('RMUTT-AC-') &&
          RegExp(r'^ESP32-[0-9A-F]{12}$').hasMatch(identity.deviceId);
      final isOccupancyIdentity =
          candidate.name.startsWith('RMUTT-OCC-') &&
          RegExp(r'^OCC32-[0-9A-F]{12}$').hasMatch(identity.deviceId) &&
          identity.deviceType == 'occupancy';
      if ((!isAirIdentity && !isOccupancyIdentity) ||
          identity.bleName != candidate.name) {
        throw const BleProvisioningException(
          'Bluetooth name and ESP32 Device ID do not match.',
        );
      }
      return identity;
    } finally {
      await candidate.device.disconnect();
    }
  }

  Future<List<WifiNetworkCandidate>> scanWifiNetworks(
    BleDeviceCandidate candidate,
  ) async {
    final connection = await _connect(candidate.device);
    try {
      final wifiScan = connection.wifiScan;
      if (wifiScan == null) {
        throw const BleProvisioningException(
          'Update the ESP32 firmware before scanning nearby Wi-Fi.',
        );
      }
      final value = await wifiScan.read(timeout: 20);
      final decoded = jsonDecode(utf8.decode(value));
      if (decoded is! Map<String, dynamic> || decoded['ok'] != true) {
        throw BleProvisioningException(
          decoded is Map<String, dynamic>
              ? decoded['message'] as String? ?? 'ESP32 could not scan Wi-Fi.'
              : 'ESP32 returned invalid Wi-Fi scan data.',
        );
      }
      final rawNetworks = decoded['networks'];
      if (rawNetworks is! List) {
        throw const BleProvisioningException(
          'ESP32 returned invalid Wi-Fi scan data.',
        );
      }

      final networks = <WifiNetworkCandidate>[];
      for (final rawNetwork in rawNetworks) {
        if (rawNetwork is! List) continue;
        try {
          final network = WifiNetworkCandidate.fromCompactJson(rawNetwork);
          if (network.ssid.trim().isNotEmpty) networks.add(network);
        } on FormatException {
          // Ignore one malformed entry while keeping the other scan results.
        }
      }
      networks.sort((left, right) => right.rssi.compareTo(left.rssi));
      return networks;
    } finally {
      await candidate.device.disconnect();
    }
  }

  Future<void> provision(
    BleDeviceCandidate candidate,
    Map<String, dynamic> config,
  ) async {
    final connection = await _connect(candidate.device);
    StreamSubscription<List<int>>? statusSubscription;
    try {
      final completer = Completer<Map<String, dynamic>>();
      statusSubscription = connection.status.onValueReceived.listen((value) {
        try {
          final decoded = jsonDecode(utf8.decode(value));
          if (decoded is Map<String, dynamic> && !completer.isCompleted) {
            completer.complete(decoded);
          }
        } catch (_) {
          // Ignore malformed notifications and keep waiting for a valid ACK.
        }
      });
      candidate.device.cancelWhenDisconnected(statusSubscription);
      await connection.status.setNotifyValue(true);

      final payload = utf8.encode(jsonEncode(config));
      const dataBytesPerPacket = 150;
      final total = (payload.length / dataBytesPerPacket).ceil();
      for (var sequence = 0; sequence < total; sequence++) {
        final start = sequence * dataBytesPerPacket;
        final end = min(start + dataBytesPerPacket, payload.length);
        final packet = <int>[
          1,
          1,
          sequence >> 8,
          sequence & 0xFF,
          total >> 8,
          total & 0xFF,
          ...payload.sublist(start, end),
        ];
        await connection.config.write(
          packet,
          withoutResponse: false,
          timeout: 15,
        );
      }

      final ack = await completer.future.timeout(
        const Duration(seconds: 40),
        onTimeout: () => throw const BleProvisioningException(
          'ESP32 did not finish testing Wi-Fi or saving the configuration.',
        ),
      );
      if (ack['ok'] != true) {
        throw BleProvisioningException(
          ack['message'] as String? ?? 'ESP32 rejected the configuration.',
        );
      }
    } finally {
      await statusSubscription?.cancel();
      await candidate.device.disconnect();
    }
  }

  Future<_BleConnection> _connect(BluetoothDevice device) async {
    await FlutterBluePlus.stopScan();
    if (device.isConnected) {
      await device.disconnect();
      await Future<void>.delayed(const Duration(milliseconds: 900));
    }

    Object? connectError;
    try {
      // WinRT performs an uncached GATT query inside connect(). Wait for that
      // operation before asking for services. Calling discoverServices() while
      // autoConnect is still discovering can leave both operations waiting.
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 45),
      );
    } catch (error) {
      connectError = error;
    }

    if (!device.isConnected) {
      try {
        await device.connectionState
            .where(
              (state) => state == BluetoothConnectionState.connected,
            )
            .first
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        throw BleProvisioningException(
          'Bluetooth connection stage failed: ${_bleError(connectError)}',
        );
      }
    }

    // A connect timeout can be reported just before WinRT publishes its final
    // state. Keep the valid physical link instead of rapidly reconnecting.
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    Object? lastDiscoveryError = connectError;
    for (var attempt = 1; attempt <= 3; attempt++) {
      if (!device.isConnected) {
        throw BleProvisioningException(
          'ESP32 disconnected during Bluetooth service discovery '
          '(attempt $attempt/3).',
        );
      }

      try {
        final services = await device
            .discoverServices()
            .timeout(const Duration(seconds: 20));
        BluetoothService? target;
        for (final service in services) {
          if (service.uuid == serviceUuid) target = service;
        }
        if (target == null) {
          throw const BleProvisioningException(
            'RMUTT ESP32 service was not found after connecting.',
          );
        }

        BluetoothCharacteristic? config;
        BluetoothCharacteristic? status;
        BluetoothCharacteristic? identity;
        BluetoothCharacteristic? wifiScan;
        BluetoothCharacteristic? settings;
        for (final characteristic in target.characteristics) {
          if (characteristic.uuid == configUuid) config = characteristic;
          if (characteristic.uuid == statusUuid) status = characteristic;
          if (characteristic.uuid == identityUuid) identity = characteristic;
          if (characteristic.uuid == wifiScanUuid) wifiScan = characteristic;
          if (characteristic.uuid == settingsUuid) settings = characteristic;
        }
        if (config == null || status == null || identity == null) {
          throw const BleProvisioningException(
            'ESP32 Bluetooth characteristics are incomplete.',
          );
        }
        return _BleConnection(
          config: config,
          status: status,
          identity: identity,
          wifiScan: wifiScan,
          settings: settings,
        );
      } catch (error) {
        lastDiscoveryError = error;
        if (attempt < 3 && device.isConnected) {
          await Future<void>.delayed(Duration(milliseconds: 900 * attempt));
        }
      }
    }

    try {
      await device.disconnect();
    } catch (_) {
      // The discovery error below is more useful than a cleanup error.
    }
    throw BleProvisioningException(
      'Bluetooth service discovery failed after 3 attempts: '
      '${_bleError(lastDiscoveryError)}',
    );
  }

  String _bleError(Object? error) {
    if (error == null) return 'no error details were returned by Windows';
    final compact = '$error'.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 260) return compact;
    return '${compact.substring(0, 260)}...';
  }
}

class _BleConnection {
  const _BleConnection({
    required this.config,
    required this.status,
    required this.identity,
    required this.wifiScan,
    required this.settings,
  });

  final BluetoothCharacteristic config;
  final BluetoothCharacteristic status;
  final BluetoothCharacteristic identity;
  final BluetoothCharacteristic? wifiScan;
  final BluetoothCharacteristic? settings;
}

class BleProvisioningException implements Exception {
  const BleProvisioningException(this.message);

  final String message;

  @override
  String toString() => message;
}
