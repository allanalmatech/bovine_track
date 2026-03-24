import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/rbac_models.dart';
import '../services/rbac_repository.dart';
import 'farm_details_screen.dart';

class FarmsScreen extends StatefulWidget {
  const FarmsScreen({super.key});

  @override
  State<FarmsScreen> createState() => _FarmsScreenState();
}

class _FarmsScreenState extends State<FarmsScreen> {
  final RbacRepository _rbac = RbacRepository.instance;
  String _adminUid = '';
  static const LatLng _mbararaCenter = LatLng(-0.6072, 30.6545);

  @override
  void initState() {
    super.initState();
    _adminUid = _rbac.currentUser?.uid ?? '';
  }

  Future<void> _showAddFarmDialog() async {
    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    LatLng selected = _mbararaCenter;
    GoogleMapController? mapController;
    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Add Farm'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Farm Name',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: locationCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Location Hint (optional)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 220,
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: selected,
                            zoom: 13,
                          ),
                          onMapCreated: (controller) {
                            mapController = controller;
                          },
                          onTap: (point) {
                            setDialogState(() {
                              selected = point;
                            });
                          },
                          markers: {
                            Marker(
                              markerId: const MarkerId('farm_center'),
                              position: selected,
                              infoWindow: const InfoWindow(
                                title: 'Farm center',
                              ),
                            ),
                          },
                          zoomControlsEnabled: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final enabled =
                                    await Geolocator.isLocationServiceEnabled();
                                if (!enabled) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Enable location services first.',
                                        ),
                                      ),
                                    );
                                  }
                                  return;
                                }
                                var permission =
                                    await Geolocator.checkPermission();
                                if (permission == LocationPermission.denied) {
                                  permission =
                                      await Geolocator.requestPermission();
                                }
                                if (permission == LocationPermission.denied ||
                                    permission ==
                                        LocationPermission.deniedForever) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Location permission is required.',
                                        ),
                                      ),
                                    );
                                  }
                                  return;
                                }
                                try {
                                  final current =
                                      await Geolocator.getCurrentPosition(
                                        locationSettings:
                                            const LocationSettings(
                                              accuracy: LocationAccuracy.high,
                                            ),
                                      );
                                  final target = LatLng(
                                    current.latitude,
                                    current.longitude,
                                  );
                                  setDialogState(() {
                                    selected = target;
                                  });
                                  await mapController?.animateCamera(
                                    CameraUpdate.newCameraPosition(
                                      CameraPosition(target: target, zoom: 16),
                                    ),
                                  );
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Unable to fetch current location.',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.my_location),
                              label: const Text('Use Current Location'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Selected: ${selected.latitude.toStringAsFixed(6)}, ${selected.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty || _adminUid.isEmpty) {
                        return;
                      }
                      await _rbac.addFarm(
                        adminUid: _adminUid,
                        name: name,
                        locationHint: locationCtrl.text.trim(),
                        centerLat: selected.latitude,
                        centerLng: selected.longitude,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Save Farm'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameCtrl.dispose();
      locationCtrl.dispose();
    }
  }

  Future<void> _showEditFarmDialog(FarmModel farm) async {
    final nameCtrl = TextEditingController(text: farm.name);
    final locationCtrl = TextEditingController(text: farm.locationHint);
    LatLng selected = LatLng(farm.centerLat, farm.centerLng);
    bool active = farm.active;
    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Edit Farm'),
            content: StatefulBuilder(
              builder: (context, setDialogState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Farm Name',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: locationCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Location Hint (optional)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 220,
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: selected,
                            zoom: 13,
                          ),
                          onTap: (point) {
                            setDialogState(() {
                              selected = point;
                            });
                          },
                          markers: {
                            Marker(
                              markerId: const MarkerId('farm_center_edit'),
                              position: selected,
                              infoWindow: const InfoWindow(
                                title: 'Farm center',
                              ),
                            ),
                          },
                          zoomControlsEnabled: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Selected: ${selected.latitude.toStringAsFixed(6)}, ${selected.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      SwitchListTile(
                        value: active,
                        onChanged: (v) {
                          setDialogState(() {
                            active = v;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active Farm'),
                      ),
                    ],
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty || _adminUid.isEmpty) {
                    return;
                  }
                  await _rbac.updateFarm(
                    adminUid: _adminUid,
                    farmId: farm.id,
                    name: name,
                    locationHint: locationCtrl.text.trim(),
                    centerLat: selected.latitude,
                    centerLng: selected.longitude,
                    active: active,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      );
    } finally {
      nameCtrl.dispose();
      locationCtrl.dispose();
    }
  }

  Future<void> _deleteFarm(FarmModel farm) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Delete Farm?'),
              content: Text(
                'Delete "${farm.name}"? Boundaries linked to this farm remain until removed manually.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!ok) {
      return;
    }
    await _rbac.deleteFarm(adminUid: _adminUid, farmId: farm.id);
  }

  @override
  Widget build(BuildContext context) {
    if (_adminUid.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Admin session required to manage farms.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Farms')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddFarmDialog,
        icon: const Icon(Icons.add_business),
        label: const Text('Add Farm'),
      ),
      body: StreamBuilder<List<FarmModel>>(
        stream: _rbac.watchFarms(_adminUid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final farms = snapshot.data ?? const <FarmModel>[];
          if (farms.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No farms yet. Add a farm, then attach boundaries to it.',
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: farms.length,
            itemBuilder: (context, index) {
              final farm = farms[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.agriculture),
                  title: Text(farm.name),
                  subtitle: Text(
                    '${farm.locationHint.isEmpty ? 'No location hint' : farm.locationHint}\n${farm.centerLat.toStringAsFixed(5)}, ${farm.centerLng.toStringAsFixed(5)}\nStatus: ${farm.active ? 'ACTIVE' : 'INACTIVE'}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _showEditFarmDialog(farm);
                      } else if (value == 'delete') {
                        await _deleteFarm(farm);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit Farm')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete Farm'),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            FarmDetailsScreen(adminUid: _adminUid, farm: farm),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
