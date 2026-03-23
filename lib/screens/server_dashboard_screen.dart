import 'dart:async';

import 'package:flutter/material.dart';

import '../models/alert_model.dart';
import '../models/rbac_models.dart';
import '../services/rbac_repository.dart';
import '../theme/app_theme.dart';
import 'device_list_screen.dart';
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
  int _fenceCount = 0;
  String _adminUid = '';
  bool _loading = true;
  StreamSubscription<List<ManagedClient>>? _clientsSub;
  StreamSubscription<List<AlertModel>>? _alertsSub;
  StreamSubscription<List<ManagedBoundary>>? _boundariesSub;

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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: AppColors.primary),
          onPressed: () {},
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
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primaryContainer,
              child: const Icon(
                Icons.person,
                color: AppColors.onPrimaryContainer,
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
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DeviceListScreen()),
                  );
                },
                icon: const Icon(Icons.sensors),
                label: const Text('Open Devices Manager'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FarmsScreen()),
                  );
                },
                icon: const Icon(Icons.agriculture),
                label: const Text('Manage Farms'),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/hardware'),
                    icon: const Icon(Icons.memory),
                    label: const Text('Hardware'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/network'),
                    icon: const Icon(Icons.network_check),
                    label: const Text('Network'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/map-tracking'),
                    icon: const Icon(Icons.map),
                    label: const Text('Map'),
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
          value: '${_clients.where((c) => c.active).length}',
          subLabel: 'Connected Devices',
          color: AppColors.surfaceContainerLow,
          iconColor: AppColors.primary,
          iconBg: AppColors.primaryFixed,
        ),
        _buildStatCard(
          icon: Icons.notifications_active,
          label: 'Urgent',
          value: '${_alerts.length}',
          subLabel: 'Active Alerts',
          color: AppColors.errorContainer,
          iconColor: AppColors.errorContainer,
          iconBg: AppColors.onErrorContainer,
          textColor: AppColors.onErrorContainer,
        ),
        _buildStatCard(
          icon: Icons.polyline,
          label: 'Mapping',
          value: '$_fenceCount',
          subLabel: 'Zones Created',
          color: AppColors.secondaryContainer,
          iconColor: AppColors.secondaryContainer,
          iconBg: AppColors.onSecondaryContainer,
          textColor: AppColors.onSecondaryContainer,
        ),
        _buildStatCard(
          icon: Icons.bolt,
          label: 'Optimal',
          value: '98%',
          subLabel: 'System Uptime',
          color: AppColors.primaryContainer,
          iconColor: AppColors.primary,
          iconBg: AppColors.primaryFixed,
          textColor: AppColors.primaryFixed,
          isDark: true,
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
        return Chip(
          backgroundColor: client.active
              ? AppColors.primaryFixed
              : AppColors.errorContainer,
          label: Text(client.label),
          avatar: Icon(
            client.active ? Icons.sensors : Icons.sensors_off,
            size: 16,
          ),
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
  }) {
    return Container(
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
    );
  }

  Widget _buildMapPreview() {
    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(32),
        image: const DecorationImage(
          image: NetworkImage(
            'https://placeholder.com/map',
          ), // Placeholder for map
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live Herd Positions',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    'North Pasture Sector 4',
                    style: TextStyle(
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
                _buildMapChip('12 Cattle Active', AppColors.primaryFixed),
                const SizedBox(width: 8),
                _buildMapChip('2 Maintenance', AppColors.tertiaryFixed),
              ],
            ),
          ),
        ],
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
              onPressed: () {},
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Alerts are visible on this dashboard in real time.',
                ),
              ),
            );
          }),
          _buildNavItem(Icons.settings, 'Settings', false, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FarmsScreen()),
            );
          }),
        ],
      ),
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
