import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../data/tracking_repository.dart';
import '../models/geofence_model.dart';
import '../models/rbac_models.dart';
import '../services/rbac_repository.dart';

class GeofenceBuilderScreen extends StatefulWidget {
  const GeofenceBuilderScreen({super.key, this.adminUid});

  final String? adminUid;

  @override
  State<GeofenceBuilderScreen> createState() => _GeofenceBuilderScreenState();
}

class _GeofenceBuilderScreenState extends State<GeofenceBuilderScreen> {
  final _nameCtrl = TextEditingController();
  final _coordsCtrl = TextEditingController();
  final RbacRepository _rbac = RbacRepository.instance;
  bool _restricted = false;
  bool _saving = false;
  String _adminUid = '';
  List<ManagedClient> _clients = const [];
  List<FarmModel> _farms = const [];
  String? _selectedFarmId;
  final Set<String> _selectedClientIds = <String>{};
  final List<LatLng> _pickedPoints = <LatLng>[];

  static const LatLng _defaultCenter = LatLng(-1.2921, 36.8219);

  @override
  void initState() {
    super.initState();
    _adminUid = widget.adminUid ?? _rbac.currentUser?.uid ?? '';
    _loadClients();
    _loadFarms();
  }

  Future<void> _loadClients() async {
    if (_adminUid.isEmpty) {
      return;
    }
    final snap = await _rbac.getAdminSnapshot(_adminUid);
    if (!mounted) {
      return;
    }
    setState(() {
      _clients = snap.clients;
    });
  }

  Future<void> _loadFarms() async {
    if (_adminUid.isEmpty) {
      return;
    }
    final farms = await _rbac.watchFarms(_adminUid).first;
    if (!mounted) {
      return;
    }
    setState(() {
      _farms = farms;
      if (farms.isNotEmpty) {
        _selectedFarmId ??= farms.first.id;
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _coordsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final selectedFarm = _farms.where((f) => f.id == _selectedFarmId).toList();
    final vertices = _pickedPoints
        .map((p) => GeoPoint(p.latitude, p.longitude))
        .toList();
    if (name.isEmpty || vertices.length < 3 || selectedFarm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Select a farm, enter fence name, and pick at least 3 points.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    await TrackingRepository.instance.addGeofence(
      GeofenceModel(
        id: null,
        name: name,
        vertices: vertices,
        isRestricted: _restricted,
        createdAt: DateTime.now(),
      ),
    );
    if (_adminUid.isNotEmpty) {
      await _rbac.createBoundary(
        adminUid: _adminUid,
        farmId: selectedFarm.first.id,
        farmName: selectedFarm.first.name,
        fence: GeofenceModel(
          id: null,
          name: name,
          vertices: vertices,
          isRestricted: _restricted,
          createdAt: DateTime.now(),
        ),
        assignedClientIds: _selectedClientIds.toList(),
      );
    }
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    Navigator.pop(context, true);
  }

  void _addPoint(LatLng point) {
    setState(() {
      _pickedPoints.add(point);
      _coordsCtrl.text = _pickedPoints
          .map(
            (p) =>
                '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}',
          )
          .join(';');
    });
  }

  void _removeLastPoint() {
    if (_pickedPoints.isEmpty) {
      return;
    }
    setState(() {
      _pickedPoints.removeLast();
      _coordsCtrl.text = _pickedPoints
          .map(
            (p) =>
                '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}',
          )
          .join(';');
    });
  }

  void _clearPoints() {
    setState(() {
      _pickedPoints.clear();
      _coordsCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Virtual Fence')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Fence Name'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedFarmId,
              decoration: const InputDecoration(labelText: 'Attach to Farm'),
              items: _farms
                  .map(
                    (farm) => DropdownMenuItem<String>(
                      value: farm.id,
                      child: Text(farm.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedFarmId = value;
                });
              },
            ),
            const SizedBox(height: 10),
            Container(
              height: 280,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12),
              ),
              clipBehavior: Clip.antiAlias,
              child: GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: _defaultCenter,
                  zoom: 14,
                ),
                onTap: _addPoint,
                markers: {
                  for (var i = 0; i < _pickedPoints.length; i++)
                    Marker(
                      markerId: MarkerId('point_$i'),
                      position: _pickedPoints[i],
                      infoWindow: InfoWindow(title: 'Point ${i + 1}'),
                    ),
                },
                polygons: {
                  if (_pickedPoints.length >= 3)
                    Polygon(
                      polygonId: const PolygonId('fence_preview'),
                      points: _pickedPoints,
                      strokeWidth: 3,
                      strokeColor: _restricted ? Colors.red : Colors.green,
                      fillColor: (_restricted ? Colors.red : Colors.green)
                          .withValues(alpha: 0.18),
                    ),
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickedPoints.isEmpty ? null : _removeLastPoint,
                    icon: const Icon(Icons.undo),
                    label: const Text('Undo Last Point'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickedPoints.isEmpty ? null : _clearPoints,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Clear Points'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _coordsCtrl,
              maxLines: 2,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Picked Coordinates',
                hintText: 'Tap map to add boundary points',
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Assign to Clients',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            if (_clients.isEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('No clients available. Create clients first.'),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _clients.map((client) {
                  final selected = _selectedClientIds.contains(client.uid);
                  return FilterChip(
                    selected: selected,
                    label: Text(client.label),
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _selectedClientIds.add(client.uid);
                        } else {
                          _selectedClientIds.remove(client.uid);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            const SizedBox(height: 10),
            SwitchListTile(
              value: _restricted,
              onChanged: (v) => setState(() => _restricted = v),
              title: const Text('Restricted Zone'),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving...' : 'Save Fence'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
