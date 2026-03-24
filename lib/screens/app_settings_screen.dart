import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/rbac_repository.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = RbacRepository.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('App Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Signed in account'),
            subtitle: Text(user?.email ?? 'Unknown'),
          ),
          ListTile(
            leading: const Icon(Icons.badge),
            title: const Text('UID'),
            subtitle: Text(user?.uid ?? '--'),
          ),
          ListTile(
            leading: const Icon(Icons.lock_open),
            title: const Text('Open App Permissions'),
            onTap: openAppSettings,
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            onTap: () async {
              await RbacRepository.instance.signOut();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }
}
