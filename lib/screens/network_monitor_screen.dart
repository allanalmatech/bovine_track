import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../data/tracking_repository.dart';

class NetworkMonitorScreen extends StatefulWidget {
  const NetworkMonitorScreen({super.key});

  @override
  State<NetworkMonitorScreen> createState() => _NetworkMonitorScreenState();
}

class _NetworkMonitorScreenState extends State<NetworkMonitorScreen> {
  final _history = <String>[];
  String _state = 'Unknown';

  @override
  void initState() {
    super.initState();
    Connectivity().onConnectivityChanged.listen((result) {
      final state = _describe(result);
      final stamp = DateTime.now().toIso8601String().substring(11, 19);
      if (!mounted) {
        return;
      }
      setState(() {
        _state = state;
        _history.insert(0, '[$stamp] $state');
      });
    });
  }

  String _describe(List<ConnectivityResult> result) {
    if (result.contains(ConnectivityResult.mobile)) {
      return 'Connected (Mobile Data)';
    }
    if (result.contains(ConnectivityResult.wifi)) {
      return 'Connected (Wi-Fi)';
    }
    return 'Idle / Not Connected';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connectivity Manager')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current State: $_state',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () async {
                await TrackingRepository.instance.syncPending();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Triggered offline->online sync attempt.'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.sync),
              label: const Text('Sync Pending Data'),
            ),
            const SizedBox(height: 12),
            const Text('Network State History'),
            const SizedBox(height: 6),
            Expanded(
              child: ListView.builder(
                itemCount: _history.length,
                itemBuilder: (context, index) =>
                    ListTile(dense: true, title: Text(_history[index])),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
