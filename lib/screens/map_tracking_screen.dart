import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/rbac_models.dart';
import '../services/rbac_repository.dart';

class MapTrackingScreen extends StatefulWidget {
  const MapTrackingScreen({super.key});

  @override
  State<MapTrackingScreen> createState() => _MapTrackingScreenState();
}

class _MapTrackingScreenState extends State<MapTrackingScreen> {
  final RbacRepository _rbac = RbacRepository.instance;
  String _adminUid = '';

  @override
  void initState() {
    super.initState();
    _adminUid = _rbac.currentUser?.uid ?? '';
  }

  @override
  Widget build(BuildContext context) {
    if (_adminUid.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Admin session required to view map.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Interactive Map Module')),
      body: StreamBuilder<List<TrackedDevice>>(
        stream: _rbac.watchAdminDevices(_adminUid),
        builder: (context, devicesSnap) {
          final devices = devicesSnap.data ?? const <TrackedDevice>[];
          return StreamBuilder<Map<String, Map<String, dynamic>>>(
            stream: _rbac.watchLatestLocationsByClient(_adminUid),
            builder: (context, latestSnap) {
              final latestByClient =
                  latestSnap.data ?? const <String, Map<String, dynamic>>{};
              return StreamBuilder<List<ManagedBoundary>>(
                stream: _rbac.watchBoundaries(_adminUid),
                builder: (context, boundarySnap) {
                  final boundaries =
                      boundarySnap.data ?? const <ManagedBoundary>[];

                  final markers = <Marker>{};
                  for (final device in devices) {
                    final latest = latestByClient[device.clientUid];
                    final lat = (latest?['lat'] as num?)?.toDouble();
                    final lng = (latest?['lng'] as num?)?.toDouble();
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

                  final polygons = <Polygon>{};
                  for (final boundary in boundaries) {
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
                            : Colors.green.shade700,
                        fillColor: boundary.isRestricted
                            ? Colors.red.withValues(alpha: 0.15)
                            : Colors.green.withValues(alpha: 0.15),
                      ),
                    );
                  }

                  const fallback = LatLng(-0.6072, 30.6545);
                  final center = markers.isNotEmpty
                      ? markers.first.position
                      : fallback;

                  return Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: center,
                          zoom: 13,
                        ),
                        markers: markers,
                        polygons: polygons,
                        myLocationEnabled: false,
                        zoomControlsEnabled: true,
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        top: 12,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'Live markers: ${markers.length} | Boundaries: ${polygons.length}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
      ),
    );
  }
}
