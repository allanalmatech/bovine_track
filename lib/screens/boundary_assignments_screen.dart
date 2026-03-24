import 'package:flutter/material.dart';

import '../models/rbac_models.dart';
import '../services/rbac_repository.dart';
import 'client_profile_screen.dart';

class BoundaryAssignmentsScreen extends StatelessWidget {
  const BoundaryAssignmentsScreen({super.key});

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
      appBar: AppBar(title: const Text('Boundary Assignments')),
      body: StreamBuilder<List<ManagedClient>>(
        stream: rbac.watchAdminClients(adminUid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final clients = snap.data ?? const <ManagedClient>[];
          if (clients.isEmpty) {
            return const Center(child: Text('No clients available.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: clients.length,
            itemBuilder: (context, index) {
              final client = clients[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.person_pin_circle),
                  title: Text(client.label),
                  subtitle: Text(client.uid),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClientProfileScreen(
                          adminUid: adminUid,
                          client: client,
                        ),
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
