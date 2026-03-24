import 'package:flutter/material.dart';

import '../models/geofence_model.dart';
import '../models/rbac_models.dart';
import '../services/rbac_repository.dart';

class FencesScreen extends StatelessWidget {
  const FencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rbac = RbacRepository.instance;
    final adminUid = rbac.currentUser?.uid ?? '';
    if (adminUid.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Admin session required.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Fences / Boundaries')),
      body: StreamBuilder<List<ManagedBoundary>>(
        stream: rbac.watchBoundaries(adminUid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final boundaries = snap.data ?? const <ManagedBoundary>[];
          if (boundaries.isEmpty) {
            return const Center(child: Text('No boundaries available.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: boundaries.length,
            itemBuilder: (context, index) {
              final b = boundaries[index];
              return Card(
                child: ListTile(
                  leading: Icon(
                    b.isRestricted
                        ? Icons.warning_amber
                        : Icons.check_circle_outline,
                    color: b.isRestricted ? Colors.red : Colors.green,
                  ),
                  title: Text(b.name),
                  subtitle: Text(
                    '${b.farmName} | ${b.vertices.length} points | ${b.assignedClients.length} clients',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _showEditDialog(context, adminUid, b);
                      } else if (value == 'delete') {
                        final ok =
                            await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete boundary?'),
                                content: Text(
                                  'Delete "${b.name}" and remove all its assignments?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            ) ??
                            false;
                        if (ok) {
                          await rbac.deleteBoundary(
                            adminUid: adminUid,
                            boundaryId: b.id,
                            assignedClientIds: b.assignedClients,
                          );
                        }
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    String adminUid,
    ManagedBoundary boundary,
  ) async {
    final rbac = RbacRepository.instance;
    final farms = await rbac.watchFarms(adminUid).first;
    if (!context.mounted) {
      return;
    }
    final nameCtrl = TextEditingController(text: boundary.name);
    final verticesCtrl = TextEditingController(
      text: boundary.vertices.map((p) => '${p.lat},${p.lng}').join(';'),
    );
    var restricted = boundary.isRestricted;
    var selectedFarmId = boundary.farmId.isEmpty && farms.isNotEmpty
        ? farms.first.id
        : boundary.farmId;

    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Edit Boundary'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Boundary Name',
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedFarmId,
                        decoration: const InputDecoration(labelText: 'Farm'),
                        items: farms
                            .map(
                              (f) => DropdownMenuItem<String>(
                                value: f.id,
                                child: Text(f.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(
                          () => selectedFarmId = v ?? selectedFarmId,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: verticesCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Vertices (lat,lng;lat,lng;...)',
                        ),
                      ),
                      SwitchListTile(
                        value: restricted,
                        title: const Text('Restricted Zone'),
                        onChanged: (v) => setState(() => restricted = v),
                        contentPadding: EdgeInsets.zero,
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
                      final farm = farms
                          .where((f) => f.id == selectedFarmId)
                          .toList();
                      if (farm.isEmpty ||
                          GeofenceModel.parseVertices(
                                verticesCtrl.text,
                              ).length <
                              3) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Select farm and provide at least 3 vertices.',
                            ),
                          ),
                        );
                        return;
                      }
                      await rbac.updateBoundary(
                        adminUid: adminUid,
                        boundaryId: boundary.id,
                        name: nameCtrl.text.trim(),
                        farmId: farm.first.id,
                        farmName: farm.first.name,
                        verticesText: verticesCtrl.text.trim(),
                        isRestricted: restricted,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameCtrl.dispose();
      verticesCtrl.dispose();
    }
  }
}
