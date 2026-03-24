import 'package:flutter/material.dart';

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
              final ts =
                  (status?['lastSeen'] as num?)?.toInt() ??
                  (latest?['timestamp'] as num?)?.toInt();

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
