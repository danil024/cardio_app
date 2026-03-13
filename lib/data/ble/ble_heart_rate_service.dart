import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/constants.dart';
import '../../domain/models/hr_reading.dart';

/// Статус подключения BLE
enum BleConnectionStatus {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}

/// Сервис для работы с BLE пульсометром (GEOID HS500)
class BleHeartRateService {
  BleHeartRateService() {
    _init();
  }

  BluetoothDevice? _device;
  BluetoothCharacteristic? _hrCharacteristic;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _characteristicSubscription;
  StreamSubscription<BluetoothConnectionState>? _deviceConnectionSub;
  Timer? _mockTimer;
  Duration _mockInterval = AppConstants.mockHrInterval;

  final _statusController = StreamController<BleConnectionStatus>.broadcast();
  final _hrController = StreamController<HrReading>.broadcast();

  Stream<BleConnectionStatus> get statusStream => _statusController.stream;
  Stream<HrReading> get heartRateStream => _hrController.stream;

  BleConnectionStatus _status = BleConnectionStatus.disconnected;
  BleConnectionStatus get status => _status;
  bool _isMockMode = false;
  bool get isMockMode => _isMockMode;

  void setMockInterval(Duration interval) {
    _mockInterval = interval;
    if (AppConstants.enableMockHeartRate && _status == BleConnectionStatus.connected) {
      _startMock();
    }
  }

  void _init() {
    FlutterBluePlus.adapterState.listen((state) {
      if (state != BluetoothAdapterState.on) {
        _setStatus(BleConnectionStatus.disconnected);
      }
    });
  }

  void _setStatus(BleConnectionStatus s) {
    _status = s;
    _statusController.add(s);
  }

  /// Сканирование и подключение к пульсометру с Heart Rate Service
  Future<void> connect() async {
    if (_status == BleConnectionStatus.connected) return;
    _isMockMode = false;

    _setStatus(BleConnectionStatus.scanning);

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      _setStatus(BleConnectionStatus.error);
      throw Exception('Bluetooth выключен');
    }

    // Сканируем все BLE устройства (некоторые пульсометры не рекламируют HR service)
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 20),
    );

    BluetoothDevice? foundDevice;
    List<ScanResult> lastResults = [];
    final triedIds = <String>{};

    _scanSubscription = FlutterBluePlus.scanResults.listen(
      (results) async {
        lastResults = results;
        for (final r in results) {
          final hasHrService = r.advertisementData.serviceUuids.any((u) {
            final s = u.toString().toLowerCase();
            return s.contains('180d');
          });
          final name = r.device.platformName.toLowerCase();
          final isHrMonitor = _isLikelyHrMonitor(name: name, hasHrService: hasHrService);
          final deviceId = r.device.remoteId.toString();

          if (hasHrService || isHrMonitor) {
            if (triedIds.contains(deviceId)) continue;
            triedIds.add(deviceId);
            await FlutterBluePlus.stopScan();
            final ok = await _tryConnectToDevice(r.device);
            if (ok) return;
            await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
            continue;
          }
          if (foundDevice == null &&
              (r.advertisementData.serviceUuids.isNotEmpty || name.isNotEmpty)) {
            foundDevice = r.device;
          }
        }
      },
      onError: (e) {
        _setStatus(BleConnectionStatus.error);
      },
    );

    await Future.delayed(const Duration(seconds: 16));

    if (_status == BleConnectionStatus.connected) return;

    if (foundDevice != null) {
      await FlutterBluePlus.stopScan();
      final ok = await _tryConnectToDevice(foundDevice!);
      if (ok) return;
    }

    final fallbackCandidates = <ScanResult>[
      ...lastResults.where((r) => r.advertisementData.serviceUuids.any((u) {
            final s = u.toString().toLowerCase();
            return s.contains('180d');
          })),
      ...lastResults.where((r) {
        final name = r.device.platformName.toLowerCase();
        return _isLikelyHrMonitor(name: name, hasHrService: false);
      }),
      ...lastResults.where((r) => r.device.platformName.isNotEmpty),
    ];
    for (final r in fallbackCandidates) {
      final deviceId = r.device.remoteId.toString();
      if (triedIds.contains(deviceId)) continue;
      triedIds.add(deviceId);
      await FlutterBluePlus.stopScan();
      final ok = await _tryConnectToDevice(r.device);
      if (ok) {
        return;
      }
    }

    await FlutterBluePlus.stopScan();
    _setStatus(BleConnectionStatus.error);
    throw Exception('Пульсометр не найден. Убедитесь, что датчик включён и надет.');
  }

  bool _isLikelyHrMonitor({
    required String name,
    required bool hasHrService,
  }) {
    return hasHrService ||
        name.contains('geoid') ||
        name.contains('hs500') ||
        name.contains('heart') ||
        name.contains('hr') ||
        name.contains('polar') ||
        name.contains('garmin') ||
        name.contains('h10') ||
        name.contains('wahoo');
  }

  Future<bool> _tryConnectToDevice(BluetoothDevice device) async {
    try {
      await _connectToDevice(device);
      return _status == BleConnectionStatus.connected;
    } catch (_) {
      try {
        await device.disconnect();
      } catch (_) {}
      _hrCharacteristic = null;
      _device = null;
      _setStatus(BleConnectionStatus.scanning);
      return false;
    }
  }

  Future<bool> reconnectLastKnownDevice({bool force = false}) async {
    final device = _device;
    if (device == null) {
      return false;
    }
    if (!force && _status == BleConnectionStatus.connected) {
      return true;
    }
    try {
      await _characteristicSubscription?.cancel();
      _characteristicSubscription = null;
      await _deviceConnectionSub?.cancel();
      _deviceConnectionSub = null;
      try {
        await _hrCharacteristic?.setNotifyValue(false);
      } catch (_) {}
      _hrCharacteristic = null;
      try {
        await device.disconnect();
      } catch (_) {}
      await _connectToDevice(
        device,
        connectionTimeout: const Duration(seconds: 4),
      );
      return _status == BleConnectionStatus.connected;
    } catch (_) {
      _setStatus(BleConnectionStatus.disconnected);
      return false;
    }
  }

  Future<void> startMockMode() async {
    _isMockMode = true;
    _startMock();
  }

  Future<void> _connectToDevice(
    BluetoothDevice device, {
    Duration connectionTimeout = const Duration(seconds: 15),
  }) async {
    _device = device;
    _setStatus(BleConnectionStatus.connecting);
    await _characteristicSubscription?.cancel();
    _characteristicSubscription = null;
    await _deviceConnectionSub?.cancel();
    _deviceConnectionSub = null;

    await device.connect(timeout: connectionTimeout);
    _deviceConnectionSub = device.connectionState.listen((connectionState) {
      if (connectionState == BluetoothConnectionState.disconnected &&
          _status != BleConnectionStatus.disconnected) {
        _setStatus(BleConnectionStatus.disconnected);
      }
    });

    final services = await device.discoverServices();
    for (final service in services) {
      if (service.uuid.toString().toLowerCase().contains('180d')) {
        for (final char in service.characteristics) {
          if (char.uuid.toString().toLowerCase().contains('2a37')) {
            _hrCharacteristic = char;
            break;
          }
        }
        break;
      }
    }

    if (_hrCharacteristic == null) {
      await device.disconnect();
      _setStatus(BleConnectionStatus.error);
      throw Exception('Сервис пульса не найден');
    }

    await _hrCharacteristic!.setNotifyValue(true);

    _characteristicSubscription = _hrCharacteristic!.lastValueStream.listen(
      (value) => _parseHeartRate(value),
    );

    _setStatus(BleConnectionStatus.connected);
  }

  void _parseHeartRate(List<int> value) {
    if (value.isEmpty) return;

    // BLE Heart Rate format: flags (1 byte) + heart rate (1 or 2 bytes)
    final flags = value[0];
    final hr16Bit = (flags & 0x01) != 0;

    int bpm;
    if (hr16Bit && value.length >= 3) {
      bpm = value[1] | (value[2] << 8);
    } else if (value.length >= 2) {
      bpm = value[1];
    } else {
      return;
    }

    if (bpm > 0 && bpm < 250) {
      _hrController.add(HrReading(
        timestamp: DateTime.now(),
        heartRate: bpm,
      ));
    }
  }

  void _startMock() {
    _setStatus(BleConnectionStatus.connected);
    _mockTimer?.cancel();

    int t = 0;
    const mid = (AppConstants.mockHrMin + AppConstants.mockHrMax) / 2;
    const amp = (AppConstants.mockHrMax - AppConstants.mockHrMin) / 2;

    _mockTimer = Timer.periodic(_mockInterval, (_) {
      final value = mid + amp * math.sin(t / 10);
      t++;
      final bpm = value.clamp(
        AppConstants.mockHrMin.toDouble(),
        AppConstants.mockHrMax.toDouble(),
      ).round();
      _hrController.add(
        HrReading(
          timestamp: DateTime.now(),
          heartRate: bpm,
        ),
      );
    });
  }

  /// Отключение
  Future<void> disconnect() async {
    _mockTimer?.cancel();
    _mockTimer = null;
    _isMockMode = false;
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await _characteristicSubscription?.cancel();
    _characteristicSubscription = null;
    await _deviceConnectionSub?.cancel();
    _deviceConnectionSub = null;
    await _hrCharacteristic?.setNotifyValue(false);
    _hrCharacteristic = null;
    await _device?.disconnect();
    _device = null;
    _setStatus(BleConnectionStatus.disconnected);
  }

  void dispose() {
    disconnect();
    _statusController.close();
    _hrController.close();
  }
}
