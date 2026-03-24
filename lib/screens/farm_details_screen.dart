import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/rbac_models.dart';
import '../services/rbac_repository.dart';

class FarmDetailsScreen extends StatelessWidget {
  const FarmDetailsScreen({
    super.key,
    required this.adminUid,
    required this.farm,
  });

  final String adminUid;
  final FarmModel farm;

  @override
  Widget build(BuildContext context) {
    final rbac = RbacRepository.instance;

    return Scaffold(
      appBar: AppBar(title: Text('${farm.name} Details')),
      body: StreamBuilder<List<ManagedBoundary>>(
        stream: rbac.watchBoundaries(adminUid),
        builder: (context, boundariesSnap) {
          final allBoundaries =
              boundariesSnap.data ?? const <ManagedBoundary>[];
          final farmBoundaries = allBoundaries
              .where((b) => b.farmId == farm.id)
              .toList();

          final assignedClientIds = <String>{};
          for (final boundary in farmBoundaries) {
            assignedClientIds.addAll(boundary.assignedClients);
          }

          return StreamBuilder<List<ManagedClient>>(
            stream: rbac.watchAdminClients(adminUid),
            builder: (context, clientsSnap) {
              final clients = (clientsSnap.data ?? const <ManagedClient>[])
                  .where((c) => assignedClientIds.contains(c.uid))
                  .toList();

              return StreamBuilder<List<TrackedDevice>>(
                stream: rbac.watchAdminDevices(adminUid),
                builder: (context, devicesSnap) {
                  final devices = (devicesSnap.data ?? const <TrackedDevice>[])
                      .where((d) => assignedClientIds.contains(d.clientUid))
                      .toList();

                  return StreamBuilder<Map<String, Map<String, dynamic>>>(
                    stream: rbac.watchLatestLocationsByClient(adminUid),
                    builder: (context, latestSnap) {
                      final latest =
                          latestSnap.data ??
                          const <String, Map<String, dynamic>>{};

                      final polygons = <Polygon>{};
                      for (final boundary in farmBoundaries) {
                        if (boundary.vertices.length < 3) {
                          continue;
                        }
                        polygons.add(
                          Polygon(
                            polygonId: PolygonId(boundary.id),
                            points: boundary.vertices
                                .map((p) => LatLng(p.lat, p.lng))
                                .toList(),
                            strokeWidth: 3,
                            strokeColor: boundary.isRestricted
                                ? Colors.red
                                : Colors.green,
                            fillColor:
                                (boundary.isRestricted
                                        ? Colors.red
                                        : Colors.green)
                                    .withValues(alpha: 0.16),
                          ),
                        );
                      }

                      final markers = <Marker>{};
                      for (final device in devices) {
                        final row = latest[device.clientUid];
                        final lat = (row?['lat'] as num?)?.toDouble();
                        final lng = (row?['lng'] as num?)?.toDouble();
                        if (lat == null || lng == null) {
                          continue;
                        }
                        markers.add(
                          Marker(
                            markerId: MarkerId(device.deviceId),
                            position: LatLng(lat, lng),
                            infoWindow: InfoWindow(
                              title: device.label,
                              snippet: device.clientUid,
                            ),
                          ),
                        );
                      }

                      LatLng center = LatLng(farm.centerLat, farm.centerLng);
                      if (markers.isNotEmpty) {
                        center = markers.first.position;
                      } else if (polygons.isNotEmpty &&
                          polygons.first.points.isNotEmpty) {
                        center = polygons.first.points.first;
                      }

                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    farm.name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    farm.locationHint.isEmpty
                                        ? 'No location hint'
                                        : farm.locationHint,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Text(
                                'Boundaries: ${farmBoundaries.length} | Assigned clients: ${clients.length} | Devices: ${devices.length}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 260,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: center,
                                zoom: 13,
                              ),
                              markers: markers,
                              polygons: polygons,
                              zoomControlsEnabled: true,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Farm Boundaries',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          if (farmBoundaries.isEmpty)
                            const Text(
                              'No boundaries attached to this farm yet.',
                            )
                          else
                            ...farmBoundaries.map(
                              (b) => Card(
                                child: ListTile(
                                  leading: Icon(
                                    b.isRestricted
                                        ? Icons.warning_amber
                                        : Icons.check_circle_outline,
                                    color: b.isRestricted
                                        ? Colors.red
                                        : Colors.green,
                                  ),
                                  title: Text(b.name),
                                  subtitle: Text(
                                    '${b.assignedClients.length} assigned client(s) | ${b.vertices.length} point(s)',
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          const Text(
                            'Assigned Clients / Devices',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          if (clients.isEmpty)
                            const Text('No assigned clients for this farm yet.')
                          else
                            ...clients.map((client) {
                              final linked = devices
                                  .where((d) => d.clientUid == client.uid)
                                  .toList();
                              return Card(
                                child: ListTile(
                                  leading: const Icon(Icons.person_pin_circle),
                                  title: Text(client.label),
                                  subtitle: Text('UID: ${client.uid}'),
                                  trailing: Text(
                                    linked.isEmpty
                                        ? 'No device'
                                        : linked.first.deviceId,
                                    style: const TextStyle(fontSize: 12),
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
