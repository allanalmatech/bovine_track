import 'package:flutter/material.dart';

import '../models/alert_model.dart';
import '../services/rbac_repository.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool _showResolved = false;

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
      appBar: AppBar(
        title: const Text('All Alerts'),
        actions: [
          TextButton(
            onPressed: () async {
              await rbac.resolveAllAlerts(adminUid);
            },
            child: const Text('Resolve All'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                FilterChip(
                  selected: !_showResolved,
                  label: const Text('Active'),
                  onSelected: (_) => setState(() => _showResolved = false),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  selected: _showResolved,
                  label: const Text('Resolved + Active'),
                  onSelected: (_) => setState(() => _showResolved = true),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<AlertModel>>(
              stream: rbac.watchAdminAlerts(
                adminUid,
                includeResolved: _showResolved,
              ),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final alerts = snap.data ?? const <AlertModel>[];
                if (alerts.isEmpty) {
                  return const Center(child: Text('No alerts at the moment.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: alerts.length,
                  itemBuilder: (context, index) {
                    final a = alerts[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          a.resolved
                              ? Icons.check_circle
                              : (a.type.contains('RESTRICTED')
                                    ? Icons.warning
                                    : Icons.notification_important),
                          color: a.resolved
                              ? Colors.green
                              : (a.type.contains('RESTRICTED')
                                    ? Colors.red
                                    : Colors.orange),
                        ),
                        title: Text(a.type),
                        subtitle: Text(
                          '${a.message}\n${a.createdAt.toLocal()}',
                        ),
                        isThreeLine: true,
                        trailing: a.remoteKey == null
                            ? null
                            : IconButton(
                                icon: Icon(
                                  a.resolved
                                      ? Icons.undo
                                      : Icons.check_circle_outline,
                                ),
                                tooltip: a.resolved
                                    ? 'Mark unresolved'
                                    : 'Mark resolved',
                                onPressed: () async {
                                  await rbac.setAlertResolved(
                                    adminUid: adminUid,
                                    alertKey: a.remoteKey!,
                                    resolved: !a.resolved,
                                  );
                                },
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
