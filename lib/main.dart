import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'screens/auth_gate_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/server_dashboard_screen.dart';
import 'screens/device_list_screen.dart';
import 'screens/client_tracking_screen.dart';
import 'screens/geofence_builder_screen.dart';
import 'screens/hardware_diagnostic_screen.dart';
import 'screens/network_monitor_screen.dart';
import 'screens/map_tracking_screen.dart';
import 'screens/farms_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/app_settings_screen.dart';
import 'screens/boundary_assignments_screen.dart';
import 'screens/fences_screen.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await FirebaseMessaging.instance.requestPermission();
  } catch (_) {
    // App remains usable offline/local even if Firebase config is not finalized yet.
  }

  runApp(const BovineTrackApp());
}

class BovineTrackApp extends StatelessWidget {
  const BovineTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BovineTrack',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
      routes: {
        '/auth': (context) => const AuthGateScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/dashboard': (context) => const ServerDashboardScreen(),
        '/devices': (context) => const DeviceListScreen(),
        '/client': (context) => const ClientTrackingScreen(),
        '/geofence-builder': (context) => const GeofenceBuilderScreen(),
        '/hardware': (context) => const HardwareDiagnosticScreen(),
        '/network': (context) => const NetworkMonitorScreen(),
        '/map-tracking': (context) => const MapTrackingScreen(),
        '/farms': (context) => const FarmsScreen(),
        '/alerts': (context) => const AlertsScreen(),
        '/settings': (context) => const AppSettingsScreen(),
        '/boundary-assignments': (context) => const BoundaryAssignmentsScreen(),
        '/fences': (context) => const FencesScreen(),
      },
    );
  }
}
