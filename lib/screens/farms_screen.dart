import 'package:flutter/material.dart';

import '../models/rbac_models.dart';
import '../services/rbac_repository.dart';

class FarmsScreen extends StatefulWidget {
  const FarmsScreen({super.key});

  @override
  State<FarmsScreen> createState() => _FarmsScreenState();
}

class _FarmsScreenState extends State<FarmsScreen> {
  final RbacRepository _rbac = RbacRepository.instance;
  String _adminUid = '';

  @override
  void initState() {
    super.initState();
    _adminUid = _rbac.currentUser?.uid ?? '';
  }

  Future<void> _showAddFarmDialog() async {
    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Add Farm'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Farm Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: locationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Location Hint (optional)',
                  ),
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
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty || _adminUid.isEmpty) {
                    return;
                  }
                  await _rbac.addFarm(
                    adminUid: _adminUid,
                    name: name,
                    locationHint: locationCtrl.text.trim(),
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
    } finally {
      nameCtrl.dispose();
      locationCtrl.dispose();
    }
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
                    farm.locationHint.isEmpty
                        ? 'No location hint'
                        : farm.locationHint,
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: farm.active
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      farm.active ? 'ACTIVE' : 'INACTIVE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: farm.active
                            ? Colors.green.shade800
                            : Colors.red.shade800,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
