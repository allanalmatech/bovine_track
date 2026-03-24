import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class HardwareDiagnosticScreen extends StatefulWidget {
  const HardwareDiagnosticScreen({super.key});

  @override
  State<HardwareDiagnosticScreen> createState() =>
      _HardwareDiagnosticScreenState();
}

class _HardwareDiagnosticScreenState extends State<HardwareDiagnosticScreen> {
  final _deviceInfo = DeviceInfoPlugin();
  final List<StreamSubscription<dynamic>> _sensorSubs = [];

  String _brand = '--';
  String _model = '--';
  String _androidVersion = '--';
  String _cpuArch = '--';
  String _cpuCores = '--';
  String _ram = '--';

  bool _accelerometerAvailable = false;
  bool _gyroscopeAvailable = false;

  String _accelLive = '--';
  String _gyroLive = '--';

  @override
  void initState() {
    super.initState();
    _loadHardware();
    _listenSensors();
  }

  @override
  void dispose() {
    for (final sub in _sensorSubs) {
      sub.cancel();
    }
    super.dispose();
  }

  Future<void> _loadHardware() async {
    try {
      final android = await _deviceInfo.androidInfo;
      final memInfo = await _readMemInfo();
      if (!mounted) {
        return;
      }
      setState(() {
        _brand = android.brand;
        _model = android.model;
        _androidVersion = android.version.release;
        _cpuArch = android.supportedAbis.isNotEmpty
            ? android.supportedAbis.join(', ')
            : '--';
        _cpuCores = Platform.numberOfProcessors.toString();
        _ram = memInfo;
      });
    } catch (_) {}
  }

  Future<String> _readMemInfo() async {
    try {
      final file = File('/proc/meminfo');
      if (!await file.exists()) {
        return '--';
      }
      final content = await file.readAsLines();
      final line = content.firstWhere(
        (l) => l.startsWith('MemTotal:'),
        orElse: () => '',
      );
      if (line.isEmpty) {
        return '--';
      }
      final kb = int.tryParse(line.replaceAll(RegExp(r'[^0-9]'), ''));
      if (kb == null) {
        return '--';
      }
      final gb = kb / 1024 / 1024;
      return '${gb.toStringAsFixed(2)} GB';
    } catch (_) {
      return '--';
    }
  }

  void _listenSensors() {
    _sensorSubs.add(
      accelerometerEventStream().listen((event) {
        if (!mounted) {
          return;
        }
        setState(() {
          _accelerometerAvailable = true;
          _accelLive =
              'x:${event.x.toStringAsFixed(2)} y:${event.y.toStringAsFixed(2)} z:${event.z.toStringAsFixed(2)}';
        });
      }),
    );

    _sensorSubs.add(
      gyroscopeEventStream().listen((event) {
        if (!mounted) {
          return;
        }
        setState(() {
          _gyroscopeAvailable = true;
          _gyroLive =
              'x:${event.x.toStringAsFixed(2)} y:${event.y.toStringAsFixed(2)} z:${event.z.toStringAsFixed(2)}';
        });
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hardware Diagnostic Utility')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _tile('Brand', _brand),
          _tile('Model', _model),
          _tile('Android Version', _androidVersion),
          _tile('CPU Architecture', _cpuArch),
          _tile('CPU Cores', _cpuCores),
          _tile('RAM (MemTotal)', _ram),
          const SizedBox(height: 12),
          _tile(
            'Accelerometer Available',
            _accelerometerAvailable ? 'YES' : 'NO',
          ),
          _tile('Accelerometer Live', _accelLive),
          _tile('Gyroscope Available', _gyroscopeAvailable ? 'YES' : 'NO'),
          _tile('Gyroscope Live', _gyroLive),
        ],
      ),
    );
  }

  Widget _tile(String title, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(title: Text(title), subtitle: Text(value)),
    );
  }
}
