import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/geofence_model.dart';
import '../models/rbac_models.dart';
import '../services/geofence_service.dart';
import '../services/rbac_repository.dart';

class ClientProfileScreen extends StatefulWidget {
  const ClientProfileScreen({
    super.key,
    required this.adminUid,
    required this.client,
  });

  final String adminUid;
  final ManagedClient client;

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  final RbacRepository _rbac = RbacRepository.instance;
  final Set<String> _saving = <String>{};
  GoogleMapController? _historyMapController;
  DateTime? _positionQueryTime;
  Map<String, dynamic>? _positionAtTime;

  @override
  void dispose() {
    _historyMapController?.dispose();
    super.dispose();
  }

  String _formatTimestamp(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  String _onlineDurationText(bool online, int? startedAt) {
    if (!online || startedAt == null) {
      return '--';
    }
    final d = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(startedAt),
    );
    if (d.isNegative) {
      return '--';
    }
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return '${h}h ${m}m ${s}s';
  }

  Future<void> _pickAndFindPositionAtTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
      initialDate: _positionQueryTime ?? DateTime.now(),
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_positionQueryTime ?? DateTime.now()),
    );
    if (time == null || !mounted) {
      return;
    }
    final target = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final row = await _rbac.getClientPositionAtOrBefore(
      adminUid: widget.adminUid,
      clientUid: widget.client.uid,
      targetTimestamp: target.millisecondsSinceEpoch,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _positionQueryTime = target;
      _positionAtTime = row;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.client.label} Profile')),
      body: StreamBuilder<Map<String, Map<String, dynamic>>>(
        stream: _rbac.watchClientStatusByClient(widget.adminUid),
        builder: (context, statusSnap) {
          return StreamBuilder<Map<String, Map<String, dynamic>>>(
            stream: _rbac.watchLatestLocationsByClient(widget.adminUid),
            builder: (context, latestSnap) {
              final status = statusSnap.data?[widget.client.uid];
              final latest = latestSnap.data?[widget.client.uid];
              final lat =
                  (status?['lat'] as num?)?.toDouble() ??
                  (latest?['lat'] as num?)?.toDouble();
              final lng =
                  (status?['lng'] as num?)?.toDouble() ??
                  (latest?['lng'] as num?)?.toDouble();
              final speed =
                  (status?['speed'] as num?)?.toDouble() ??
                  (latest?['speed'] as num?)?.toDouble();
              final accuracy =
                  (status?['accuracy'] as num?)?.toDouble() ??
                  (latest?['accuracy'] as num?)?.toDouble();
              final battery =
                  (status?['battery'] as num?)?.toInt() ??
                  (latest?['battery'] as num?)?.toInt();
              final network =
                  (status?['network'] as String?) ??
                  (latest?['network'] as String?) ??
                  'unknown';
              final ts =
                  (status?['lastSeen'] as num?)?.toInt() ??
                  (latest?['timestamp'] as num?)?.toInt();
              final onlineByFlag = status?['online'] == true;
              final onlineBySeen =
                  ts != null &&
                  DateTime.now()
                          .difference(DateTime.fromMillisecondsSinceEpoch(ts))
                          .inMinutes <=
                      2;
              final online = onlineByFlag || onlineBySeen;
              final sessionStartedAt = (status?['sessionStartedAt'] as num?)
                  ?.toInt();

              return StreamBuilder<List<TrackedDevice>>(
                stream: _rbac.watchAdminDevices(widget.adminUid),
                builder: (context, deviceSnap) {
                  final devices = (deviceSnap.data ?? const <TrackedDevice>[])
                      .where((d) => d.clientUid == widget.client.uid)
                      .toList();

                  return StreamBuilder<List<ManagedBoundary>>(
                    stream: _rbac.watchBoundaries(widget.adminUid),
                    builder: (context, boundariesSnap) {
                      final allBoundaries =
                          boundariesSnap.data ?? const <ManagedBoundary>[];
                      final assignedBoundaries = allBoundaries
                          .where(
                            (b) =>
                                b.assignedClients.contains(widget.client.uid),
                          )
                          .toList();

                      String boundaryStatus = 'Unknown';
                      Color boundaryStatusColor = Colors.orange;
                      if (lat != null &&
                          lng != null &&
                          assignedBoundaries.isNotEmpty) {
                        final point = GeoPoint(lat, lng);
                        bool hasSafe = false;
                        bool insideSafe = false;
                        bool insideRestricted = false;
                        for (final b in assignedBoundaries) {
                          final inside = GeofenceService.isInside(
                            point,
                            b.toGeofenceModel(),
                          );
                          if (!b.isRestricted) {
                            hasSafe = true;
                            if (inside) {
                              insideSafe = true;
                            }
                          }
                          if (b.isRestricted && inside) {
                            insideRestricted = true;
                          }
                        }

                        if (insideRestricted) {
                          boundaryStatus = 'Inside Restricted Zone';
                          boundaryStatusColor = Colors.red;
                        } else if (hasSafe && insideSafe) {
                          boundaryStatus = 'Inside Safe Zone';
                          boundaryStatusColor = Colors.green;
                        } else if (hasSafe && !insideSafe) {
                          boundaryStatus = 'Outside Safe Zone';
                          boundaryStatusColor = Colors.orange;
                        } else {
                          boundaryStatus = 'No Safe Boundary Assigned';
                          boundaryStatusColor = Colors.blueGrey;
                        }
                      }

                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.person_pin_circle),
                              title: Text(widget.client.label),
                              subtitle: Text('UID: ${widget.client.uid}'),
                              trailing: Text(
                                widget.client.active ? 'ACTIVE' : 'INACTIVE',
                              ),
                            ),
                          ),
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.sensors),
                              title: Text(
                                devices.isEmpty
                                    ? 'No linked device'
                                    : devices.first.deviceId,
                              ),
                              subtitle: Text(
                                devices.isEmpty
                                    ? 'Create a tracked device mapping.'
                                    : devices.first.label,
                              ),
                            ),
                          ),
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.my_location),
                              title: Text(
                                lat == null || lng == null
                                    ? 'No telemetry yet'
                                    : '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                              ),
                              subtitle: Text(
                                ts == null
                                    ? 'No last seen'
                                    : 'Speed: ${(speed ?? 0).toStringAsFixed(2)} m/s | Last seen: ${DateTime.fromMillisecondsSinceEpoch(ts)}',
                              ),
                            ),
                          ),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Real-time Client Stats',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 14,
                                    runSpacing: 8,
                                    children: [
                                      Text(
                                        online
                                            ? 'Status: ONLINE'
                                            : 'Status: OFFLINE',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: online
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                      ),
                                      Text(
                                        'Online duration: ${_onlineDurationText(online, sessionStartedAt)}',
                                      ),
                                      Text(
                                        'Battery: ${battery == null || battery < 0 ? '--' : '$battery%'}',
                                      ),
                                      Text('Network: ${network.toUpperCase()}'),
                                      Text(
                                        'GPS accuracy: ${accuracy == null ? '--' : '${accuracy.toStringAsFixed(1)} m'}',
                                      ),
                                      Text(
                                        'Last seen: ${ts == null ? '--' : _formatTimestamp(ts)}',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Client Movement History (last 24h)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: _pickAndFindPositionAtTime,
                                        icon: const Icon(Icons.schedule),
                                        label: const Text('Find at time'),
                                      ),
                                    ],
                                  ),
                                  if (_positionQueryTime != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        _positionAtTime == null
                                            ? 'No point found at ${_formatTimestamp(_positionQueryTime!.millisecondsSinceEpoch)}'
                                            : 'Point at ${_formatTimestamp(_positionQueryTime!.millisecondsSinceEpoch)} -> '
                                                  '${((_positionAtTime!['lat'] as num?)?.toDouble() ?? 0).toStringAsFixed(6)}, '
                                                  '${((_positionAtTime!['lng'] as num?)?.toDouble() ?? 0).toStringAsFixed(6)}',
                                      ),
                                    ),
                                  const SizedBox(height: 10),
                                  StreamBuilder<List<Map<String, dynamic>>>(
                                    stream: _rbac.watchClientLocationHistory(
                                      adminUid: widget.adminUid,
                                      clientUid: widget.client.uid,
                                      sinceTimestamp: DateTime.now()
                                          .subtract(const Duration(hours: 24))
                                          .millisecondsSinceEpoch,
                                      limit: 1200,
                                    ),
                                    builder: (context, historySnap) {
                                      final rows =
                                          historySnap.data ??
                                          const <Map<String, dynamic>>[];
                                      final points = rows
                                          .map((row) {
                                            final hLat = (row['lat'] as num?)
                                                ?.toDouble();
                                            final hLng = (row['lng'] as num?)
                                                ?.toDouble();
                                            if (hLat == null || hLng == null) {
                                              return null;
                                            }
                                            return LatLng(hLat, hLng);
                                          })
                                          .whereType<LatLng>()
                                          .toList();

                                      final markers = <Marker>{};
                                      if (lat != null && lng != null) {
                                        markers.add(
                                          Marker(
                                            markerId: const MarkerId(
                                              'current_position',
                                            ),
                                            position: LatLng(lat, lng),
                                            infoWindow: const InfoWindow(
                                              title: 'Current position',
                                            ),
                                          ),
                                        );
                                      }
                                      final qLat =
                                          (_positionAtTime?['lat'] as num?)
                                              ?.toDouble();
                                      final qLng =
                                          (_positionAtTime?['lng'] as num?)
                                              ?.toDouble();
                                      if (qLat != null && qLng != null) {
                                        markers.add(
                                          Marker(
                                            markerId: const MarkerId(
                                              'queried_position',
                                            ),
                                            position: LatLng(qLat, qLng),
                                            icon:
                                                BitmapDescriptor.defaultMarkerWithHue(
                                                  BitmapDescriptor.hueAzure,
                                                ),
                                            infoWindow: const InfoWindow(
                                              title:
                                                  'Position at selected time',
                                            ),
                                          ),
                                        );
                                      }

                                      final center = markers.isNotEmpty
                                          ? markers.first.position
                                          : const LatLng(-0.6072, 30.6545);

                                      return Column(
                                        children: [
                                          SizedBox(
                                            height: 230,
                                            child: GoogleMap(
                                              initialCameraPosition:
                                                  CameraPosition(
                                                    target: center,
                                                    zoom: 14,
                                                  ),
                                              onMapCreated: (controller) {
                                                _historyMapController =
                                                    controller;
                                              },
                                              markers: markers,
                                              polylines: {
                                                if (points.length >= 2)
                                                  Polyline(
                                                    polylineId:
                                                        const PolylineId(
                                                          'history_route',
                                                        ),
                                                    points: points,
                                                    width: 4,
                                                    color: Colors.blue,
                                                  ),
                                              },
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              'History points: ${rows.length}',
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          SizedBox(
                                            height: 180,
                                            child: ListView.separated(
                                              itemCount: rows.length,
                                              separatorBuilder: (_, index) =>
                                                  const Divider(height: 1),
                                              itemBuilder: (context, index) {
                                                final row =
                                                    rows[rows.length -
                                                        1 -
                                                        index];
                                                final hTs =
                                                    (row['timestamp'] as num?)
                                                        ?.toInt();
                                                final hLat =
                                                    (row['lat'] as num?)
                                                        ?.toDouble();
                                                final hLng =
                                                    (row['lng'] as num?)
                                                        ?.toDouble();
                                                final hSpeed =
                                                    (row['speed'] as num?)
                                                        ?.toDouble();
                                                return ListTile(
                                                  dense: true,
                                                  title: Text(
                                                    hTs == null
                                                        ? 'Unknown time'
                                                        : _formatTimestamp(hTs),
                                                  ),
                                                  subtitle: Text(
                                                    '${hLat?.toStringAsFixed(6) ?? '--'}, ${hLng?.toStringAsFixed(6) ?? '--'} '
                                                    '| speed ${(hSpeed ?? 0).toStringAsFixed(2)} m/s',
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Card(
                            child: ListTile(
                              leading: Icon(
                                Icons.shield,
                                color: boundaryStatusColor,
                              ),
                              title: const Text('Boundary Status'),
                              subtitle: Text(boundaryStatus),
                            ),
                          ),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Assign Boundaries',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (allBoundaries.isEmpty)
                                    const Text('No boundaries created yet.')
                                  else
                                    ...allBoundaries.map((b) {
                                      final assigned = b.assignedClients
                                          .contains(widget.client.uid);
                                      final busy = _saving.contains(b.id);
                                      return CheckboxListTile(
                                        value: assigned,
                                        onChanged: busy
                                            ? null
                                            : (value) async {
                                                final assign = value == true;
                                                setState(
                                                  () => _saving.add(b.id),
                                                );
                                                try {
                                                  await _rbac
                                                      .setBoundaryAssignment(
                                                        adminUid:
                                                            widget.adminUid,
                                                        boundaryId: b.id,
                                                        clientUid:
                                                            widget.client.uid,
                                                        assigned: assign,
                                                      );
                                                } finally {
                                                  if (mounted) {
                                                    setState(
                                                      () =>
                                                          _saving.remove(b.id),
                                                    );
                                                  }
                                                }
                                              },
                                        title: Text(b.name),
                                        subtitle: Text(
                                          '${b.farmName}${busy ? ' (saving...)' : ''}',
                                        ),
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                        contentPadding: EdgeInsets.zero,
                                      );
                                    }),
                                ],
                              ),
                            ),
                          ),
                          if (assignedBoundaries.isNotEmpty)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Assigned Boundaries Summary',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    ...assignedBoundaries.map(
                                      (b) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        child: Text(
                                          '- ${b.name} (${b.farmName})',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
