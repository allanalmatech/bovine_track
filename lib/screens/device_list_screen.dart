import 'package:flutter/material.dart';

import '../models/rbac_models.dart';
import '../services/rbac_repository.dart';
import '../theme/app_theme.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  final RbacRepository _rbac = RbacRepository.instance;
  String _adminUid = '';

  int? _extractLastSeen(Map<String, dynamic>? row) {
    if (row == null) {
      return null;
    }
    return (row['lastSeen'] as num?)?.toInt() ??
        (row['timestamp'] as num?)?.toInt() ??
        (row['clientTimestamp'] as num?)?.toInt();
  }

  @override
  void initState() {
    super.initState();
    _adminUid = _rbac.currentUser?.uid ?? '';
  }

  Future<void> _showAddDeviceDialog() async {
    final deviceIdCtrl = TextEditingController();
    final clientUidCtrl = TextEditingController();
    final labelCtrl = TextEditingController();

    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Add Tracked Device'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: deviceIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Device ID (e.g. cow-sim-01)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: clientUidCtrl,
                  decoration: const InputDecoration(labelText: 'Client UID'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(labelText: 'Display Label'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final deviceId = deviceIdCtrl.text.trim();
                  final clientUid = clientUidCtrl.text.trim();
                  final label = labelCtrl.text.trim();
                  if (deviceId.isEmpty ||
                      clientUid.isEmpty ||
                      _adminUid.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Device ID and Client UID are required.'),
                      ),
                    );
                    return;
                  }
                  try {
                    await _rbac.addTrackedDevice(
                      adminUid: _adminUid,
                      deviceId: deviceId,
                      clientUid: clientUid,
                      label: label,
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to add device: $e')),
                      );
                    }
                  }
                },
                child: const Text('Save Device'),
              ),
            ],
          );
        },
      );
    } finally {
      deviceIdCtrl.dispose();
      clientUidCtrl.dispose();
      labelCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_adminUid.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Admin session required to manage devices.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tracked Devices')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDeviceDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Device'),
      ),
      body: StreamBuilder<List<TrackedDevice>>(
        stream: _rbac.watchAdminDevices(_adminUid),
        builder: (context, devicesSnap) {
          if (devicesSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final mappedDevices = devicesSnap.data ?? const <TrackedDevice>[];
          return StreamBuilder<List<ManagedClient>>(
            stream: _rbac.watchAdminClients(_adminUid),
            builder: (context, clientsSnap) {
              final clients = clientsSnap.data ?? const <ManagedClient>[];
              final byClient = <String, TrackedDevice>{
                for (final d in mappedDevices) d.clientUid: d,
              };
              final mergedDevices = <TrackedDevice>[...mappedDevices];
              for (final c in clients) {
                if (!byClient.containsKey(c.uid)) {
                  mergedDevices.add(
                    TrackedDevice(
                      deviceId: 'unmapped-${c.uid.substring(0, 6)}',
                      clientUid: c.uid,
                      label: c.label,
                      active: c.active,
                      createdAt: DateTime.now(),
                    ),
                  );
                }
              }

              return StreamBuilder<Map<String, Map<String, dynamic>>>(
                stream: _rbac.watchLatestLocationsByClient(_adminUid),
                builder: (context, latestSnap) {
                  final latestByClient =
                      latestSnap.data ?? const <String, Map<String, dynamic>>{};
                  return StreamBuilder<Map<String, Map<String, dynamic>>>(
                    stream: _rbac.watchClientStatusByClient(_adminUid),
                    builder: (context, statusSnap) {
                      final statusByClient =
                          statusSnap.data ??
                          const <String, Map<String, dynamic>>{};
                      if (mergedDevices.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No devices yet. Add devices to start tracking client telemetry.',
                            ),
                          ),
                        );
                      }

                      final onlineCount = mergedDevices.where((d) {
                        final row =
                            statusByClient[d.clientUid] ??
                            latestByClient[d.clientUid];
                        final ts = _extractLastSeen(row);
                        if (ts == null) {
                          return false;
                        }
                        return DateTime.now()
                                .difference(
                                  DateTime.fromMillisecondsSinceEpoch(ts),
                                )
                                .inMinutes <=
                            2;
                      }).length;

                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'Total devices: ${mergedDevices.length} | Online now: $onlineCount',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...mergedDevices.map((device) {
                            final status = statusByClient[device.clientUid];
                            final latest = latestByClient[device.clientUid];
                            final ts =
                                _extractLastSeen(status) ??
                                _extractLastSeen(latest);
                            final lat =
                                (status?['lat'] as num?)?.toDouble() ??
                                (latest?['lat'] as num?)?.toDouble();
                            final lng =
                                (status?['lng'] as num?)?.toDouble() ??
                                (latest?['lng'] as num?)?.toDouble();
                            final speed =
                                (status?['speed'] as num?)?.toDouble() ??
                                (latest?['speed'] as num?)?.toDouble();

                            final lastSeen = ts == null
                                ? null
                                : DateTime.now().difference(
                                    DateTime.fromMillisecondsSinceEpoch(ts),
                                  );
                            final online =
                                (status?['online'] == true) ||
                                (lastSeen != null && lastSeen.inMinutes <= 2);

                            return Card(
                              color: AppColors.surfaceContainerLow,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.sensors,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            device.label,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: online
                                                ? AppColors.primaryFixed
                                                : AppColors.errorContainer,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            online ? 'ONLINE' : 'OFFLINE',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: online
                                                  ? AppColors.primary
                                                  : AppColors.onErrorContainer,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text('Device ID: ${device.deviceId}'),
                                    Text('Client UID: ${device.clientUid}'),
                                    if (device.deviceId.startsWith('unmapped-'))
                                      const Text(
                                        'Device mapping not created yet (showing client fallback).',
                                        style: TextStyle(
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    Text(
                                      lat == null || lng == null
                                          ? 'No telemetry yet'
                                          : 'Last position: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                                    ),
                                    Text(
                                      speed == null
                                          ? 'Speed: --'
                                          : 'Speed: ${speed.toStringAsFixed(2)} m/s',
                                    ),
                                    Text(
                                      lastSeen == null
                                          ? 'Last seen: never'
                                          : 'Last seen: ${lastSeen.inMinutes} min ago',
                                      style: const TextStyle(
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
