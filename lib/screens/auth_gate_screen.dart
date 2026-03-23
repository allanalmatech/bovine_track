import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/rbac_repository.dart';
import 'client_tracking_screen.dart';
import 'login_screen.dart';
import 'server_dashboard_screen.dart';

class AuthGateScreen extends StatelessWidget {
  const AuthGateScreen({super.key});

  Future<bool> _ensureRequiredPermissions() async {
    final statuses = await [
      Permission.location,
      Permission.notification,
      Permission.sms,
    ].request();

    final locationOk = statuses[Permission.location]?.isGranted ?? false;
    final notificationOk =
        statuses[Permission.notification]?.isGranted ?? false;
    final smsOk = statuses[Permission.sms]?.isGranted ?? false;

    return locationOk && notificationOk && smsOk;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _ensureRequiredPermissions(),
      builder: (context, permissionSnap) {
        if (permissionSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (permissionSnap.data != true) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'BovineTrack requires Location, Notifications, and SMS permissions to operate.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        (context as Element).markNeedsBuild();
                      },
                      child: const Text('Grant Permissions'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: openAppSettings,
                      child: const Text('Open App Settings'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return StreamBuilder<User?>(
          stream: RbacRepository.instance.authStateChanges(),
          builder: (context, authSnap) {
            if (authSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final user = authSnap.data;
            if (user == null) {
              return const LoginScreen();
            }

            return FutureBuilder<String?>(
              future: RbacRepository.instance
                  .getRole(user.uid)
                  .timeout(const Duration(seconds: 10)),
              builder: (context, roleSnap) {
                if (roleSnap.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (roleSnap.hasError) {
                  return Scaffold(
                    body: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Failed loading role: ${roleSnap.error}'),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: () => FirebaseAuth.instance.signOut(),
                              child: const Text('Sign Out'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                final role = roleSnap.data;
                if (role == 'admin') {
                  return const ServerDashboardScreen();
                }
                if (role == 'client') {
                  return const ClientTrackingScreen();
                }

                return Scaffold(
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Account has no RBAC role assigned in /users/{uid}/role.',
                          ),
                          const SizedBox(height: 8),
                          Text('UID: ${user.uid}', textAlign: TextAlign.center),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: () async {
                                  await RbacRepository.instance.setOwnRole(
                                    'admin',
                                  );
                                },
                                child: const Text('Set as Admin'),
                              ),
                              OutlinedButton(
                                onPressed: () async {
                                  await RbacRepository.instance.setOwnRole(
                                    'client',
                                  );
                                },
                                child: const Text('Set as Client'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () => FirebaseAuth.instance.signOut(),
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
