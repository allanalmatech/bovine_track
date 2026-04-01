import 'dart:async';

import 'package:flutter/material.dart';

import '../models/alert_model.dart';
import '../models/rbac_models.dart';
import '../services/rbac_repository.dart';
import '../theme/app_theme.dart';
import 'alerts_screen.dart';
import 'app_settings_screen.dart';
import 'boundary_assignments_screen.dart';
import 'client_profile_screen.dart';
import 'device_list_screen.dart';
import 'fences_screen.dart';
import 'farms_screen.dart';
import 'geofence_builder_screen.dart';

class ServerDashboardScreen extends StatefulWidget {
  const ServerDashboardScreen({super.key});

  @override
  State<ServerDashboardScreen> createState() => _ServerDashboardScreenState();
}

class _ServerDashboardScreenState extends State<ServerDashboardScreen> {
  final RbacRepository _rbac = RbacRepository.instance;
  List<AlertModel> _alerts = const [];
  List<ManagedClient> _clients = const [];
  List<TrackedDevice> _devices = const [];
  int _fenceCount = 0;
  String _adminUid = '';
  bool _loading = true;
  StreamSubscription<List<ManagedClient>>? _clientsSub;
  StreamSubscription<List<AlertModel>>? _alertsSub;
  StreamSubscription<List<ManagedBoundary>>? _boundariesSub;
  StreamSubscription<List<TrackedDevice>>? _devicesSub;
  StreamSubscription<Map<String, Map<String, dynamic>>>? _latestLocSub;
  StreamSubscription<Map<String, Map<String, dynamic>>>? _statusSub;
  Map<String, Map<String, dynamic>> _latestByClient = const {};
  Map<String, Map<String, dynamic>> _statusByClient = const {};

  int? _extractLastSeen(Map<String, dynamic>? row) {
    if (row == null) {
      return null;
    }
    return (row['lastSeen'] as num?)?.toInt() ??
        (row['timestamp'] as num?)?.toInt() ??
        (row['clientTimestamp'] as num?)?.toInt();
  }

  bool _isOnline(Map<String, dynamic>? status, Map<String, dynamic>? latest) {
    if (status?['online'] == true) {
      return true;
    }
    final ts = _extractLastSeen(status) ?? _extractLastSeen(latest);
    if (ts == null) {
      return false;
    }
    return DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(ts))
            .inMinutes <=
        2;
  }

  @override
  void initState() {
    super.initState();
    _adminUid = _rbac.currentUser?.uid ?? '';
    _refreshData();
    _bindRealtimeStreams();
  }

  @override
  void dispose() {
    _clientsSub?.cancel();
    _alertsSub?.cancel();
    _boundariesSub?.cancel();
    _devicesSub?.cancel();
    _latestLocSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  void _bindRealtimeStreams() {
    if (_adminUid.isEmpty) {
      return;
    }

    _clientsSub = _rbac.watchAdminClients(_adminUid).listen((clients) {
      if (!mounted) {
        return;
      }
      setState(() {
        _clients = clients;
        _loading = false;
      });
    });

    _alertsSub = _rbac.watchAdminAlerts(_adminUid).listen((alerts) {
      if (!mounted) {
        return;
      }
      setState(() {
        _alerts = alerts.take(6).toList();
        _loading = false;
      });
    });

    _boundariesSub = _rbac.watchBoundaries(_adminUid).listen((zones) {
      if (!mounted) {
        return;
      }
      setState(() {
        _fenceCount = zones.length;
        _loading = false;
      });
    });

    _devicesSub = _rbac.watchAdminDevices(_adminUid).listen((devices) {
      if (!mounted) {
        return;
      }
      setState(() {
        _devices = devices;
      });
    });

    _latestLocSub = _rbac.watchLatestLocationsByClient(_adminUid).listen((
      rows,
    ) {
      if (!mounted) {
        return;
      }
      setState(() {
        _latestByClient = rows;
      });
    });

    _statusSub = _rbac.watchClientStatusByClient(_adminUid).listen((rows) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusByClient = rows;
      });
    });
  }

  Future<void> _refreshData() async {
    if (_adminUid.isEmpty) {
      return;
    }
    final snapshot = await _rbac.getAdminSnapshot(_adminUid);
    if (!mounted) {
      return;
    }
    setState(() {
      _alerts = snapshot.alerts.take(6).toList();
      _fenceCount = snapshot.boundaryCount;
      _clients = snapshot.clients;
      _loading = false;
    });
  }

  Future<void> _showCreateClientDialog() async {
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Create Client Account'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(labelText: 'Client Label'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Client Email'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Temp Password'),
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
                  try {
                    await _rbac.createClientAccount(
                      email: emailCtrl.text.trim(),
                      password: passwordCtrl.text,
                      label: labelCtrl.text.trim(),
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                    await _refreshData();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Client creation failed: $e')),
                      );
                    }
                  }
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      );
    } finally {
      emailCtrl.dispose();
      passwordCtrl.dispose();
      labelCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _rbac.currentUser;
    return Scaffold(
      drawer: _buildMenuDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu, color: AppColors.primary),
              onPressed: () => Scaffold.of(context).openDrawer(),
            );
          },
        ),
        title: const Text(
          'BovineTrack',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w900,
            fontSize: 24,
            color: AppColors.primary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.primary),
            onPressed: () async {
              await _rbac.signOut();
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => _showProfileMenu(context),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primaryContainer,
                child: const Icon(
                  Icons.person,
                  color: AppColors.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loading) const LinearProgressIndicator(),
            const Text(
              'System Overview',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'North Pasture Status',
              style: Theme.of(
                context,
              ).textTheme.displayLarge?.copyWith(fontSize: 48),
            ),
            const SizedBox(height: 8),
            Text(
              user?.email ?? 'admin',
              style: const TextStyle(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _adminUid.isEmpty
                        ? null
                        : () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    GeofenceBuilderScreen(adminUid: _adminUid),
                              ),
                            );
                            await _refreshData();
                          },
                    icon: const Icon(Icons.polyline),
                    label: const Text('Create Fence'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showCreateClientDialog,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Create Client'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildClientStrip(),
            const SizedBox(height: 24),
            _buildStatsGrid(),
            const SizedBox(height: 32),
            _buildMapPreview(),
            const SizedBox(height: 32),
            _buildActiveAlerts(),
            const SizedBox(height: 100), // Space for FAB
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _refreshData,
        backgroundColor: AppColors.primaryFixed,
        foregroundColor: AppColors.onPrimaryFixed,
        icon: const Icon(Icons.sync),
        label: const Text('Sync Dashboard'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9999),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildStatsGrid() {
    final liveFleet = _clients.where((c) => c.active).length;
    final urgent = _alerts.length;
    final mapping = _fenceCount;
    final onlineNow = _clients.where((c) {
      return _isOnline(_statusByClient[c.uid], _latestByClient[c.uid]);
    }).length;
    final optimal = _clients.isEmpty
        ? 100
        : ((onlineNow / _clients.length) * 100).round();

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _buildStatCard(
          icon: Icons.memory,
          label: 'Live Fleet',
          value: '$liveFleet',
          subLabel: 'Connected Devices',
          color: AppColors.surfaceContainerLow,
          iconColor: AppColors.primary,
          iconBg: AppColors.primaryFixed,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DeviceListScreen()),
            );
          },
        ),
        _buildStatCard(
          icon: Icons.notifications_active,
          label: 'Urgent',
          value: '$urgent',
          subLabel: 'Active Alerts',
          color: AppColors.errorContainer,
          iconColor: AppColors.errorContainer,
          iconBg: AppColors.onErrorContainer,
          textColor: AppColors.onErrorContainer,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AlertsScreen()),
            );
          },
        ),
        _buildStatCard(
          icon: Icons.polyline,
          label: 'Mapping',
          value: '$mapping',
          subLabel: 'Zones Created',
          color: AppColors.secondaryContainer,
          iconColor: AppColors.secondaryContainer,
          iconBg: AppColors.onSecondaryContainer,
          textColor: AppColors.onSecondaryContainer,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FarmsScreen()),
            );
          },
        ),
        _buildStatCard(
          icon: Icons.bolt,
          label: 'Optimal',
          value: '$optimal%',
          subLabel: 'System Uptime',
          color: AppColors.primaryContainer,
          iconColor: AppColors.primary,
          iconBg: AppColors.primaryFixed,
          textColor: AppColors.primaryFixed,
          isDark: true,
          onTap: () {
            showDialog<void>(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: const Text('System Health'),
                  content: Text(
                    'Online clients: $onlineNow / ${_clients.length}\nScore: $optimal%',
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildClientStrip() {
    if (_clients.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'No clients registered yet. Create client accounts from this dashboard.',
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _clients.take(8).map((client) {
        return ActionChip(
          backgroundColor: client.active
              ? AppColors.primaryFixed
              : AppColors.errorContainer,
          label: Text(client.label),
          avatar: Icon(
            client.active ? Icons.sensors : Icons.sensors_off,
            size: 16,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ClientProfileScreen(adminUid: _adminUid, client: client),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String subLabel,
    required Color color,
    required Color iconColor,
    required Color iconBg,
    Color? textColor,
    bool isDark = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: textColor ?? AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w900,
                    fontSize: 32,
                    color: textColor ?? AppColors.primary,
                  ),
                ),
                Text(
                  subLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color:
                        textColor?.withValues(alpha: 0.8) ??
                        AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapPreview() {
    final trackedClientIds = _devices.map((d) => d.clientUid).toSet();
    final liveMarkers = trackedClientIds.where((id) {
      final latest = _latestByClient[id];
      return latest != null;
    }).length;
    final activeNow = trackedClientIds.where((clientUid) {
      return _isOnline(_statusByClient[clientUid], _latestByClient[clientUid]);
    }).length;
    final maintenance = (trackedClientIds.length - activeNow).clamp(0, 999);

    return InkWell(
      borderRadius: BorderRadius.circular(32),
      onTap: () => Navigator.pushNamed(context, '/map-tracking'),
      child: Container(
        height: 300,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.surfaceContainer, AppColors.surfaceContainerLow],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 20,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live Herd Positions',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      '$liveMarkers latest telemetry points',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              child: Row(
                children: [
                  _buildMapChip('$activeNow Active', AppColors.primaryFixed),
                  const SizedBox(width: 8),
                  _buildMapChip(
                    '$maintenance Maintenance',
                    AppColors.tertiaryFixed,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapChip(String label, Color dotColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveAlerts() {
    if (_alerts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'No alerts yet. Client boundary crossings will appear here.',
        ),
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Active Alerts',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w800,
                fontSize: 24,
                color: AppColors.primary,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AlertsScreen()),
                );
              },
              child: const Text(
                'View All',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < _alerts.length; i++) ...[
          _buildAlertItem(
            title: _alerts[i].type,
            subtitle: _alerts[i].message,
            time: _alerts[i].createdAt.toLocal().toString().substring(0, 19),
            icon: _alerts[i].type.contains('RESTRICTED')
                ? Icons.warning
                : Icons.logout,
            color: AppColors.error,
          ),
          if (i != _alerts.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildAlertItem({
    required String title,
    required String subtitle,
    required String time,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.grid_view_rounded, 'Dashboard', true, () {}),
          _buildNavItem(Icons.memory, 'Devices', false, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DeviceListScreen()),
            );
          }),
          _buildNavItem(Icons.map, 'Map', false, () {
            Navigator.pushNamed(context, '/map-tracking');
          }),
          _buildNavItem(Icons.notifications, 'Alerts', false, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AlertsScreen()),
            );
          }),
          _buildNavItem(Icons.settings, 'Settings', false, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AppSettingsScreen()),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMenuDrawer() {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BovineTrack Menu',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 8),
                  Text('Open modules from here to keep dashboard clean.'),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.agriculture),
              title: const Text('Farms'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FarmsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.sensors),
              title: const Text('Devices Manager'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DeviceListScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Interactive Map'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/map-tracking');
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment_turned_in),
              title: const Text('Boundary Assignments'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BoundaryAssignmentsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.polyline),
              title: const Text('Fences / Boundaries'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FencesScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.memory),
              title: const Text('Hardware Diagnostic'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/hardware');
              },
            ),
            ListTile(
              leading: const Icon(Icons.network_check),
              title: const Text('Connectivity Manager'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/network');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('App Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AppSettingsScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileMenu(BuildContext context) {
    final user = _rbac.currentUser;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(user?.email ?? 'Unknown user'),
                const SizedBox(height: 2),
                Text(
                  'UID: ${user?.uid ?? '--'}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _rbac.signOut();
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign Out'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primaryFixed : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: isActive ? AppColors.primary : AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isActive ? AppColors.primary : AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
