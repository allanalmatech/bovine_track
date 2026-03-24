import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/alert_model.dart';
import 'local_notification_service.dart';
import 'rbac_repository.dart';

class AdminAlertNotificationService {
  AdminAlertNotificationService._();
  static final AdminAlertNotificationService instance =
      AdminAlertNotificationService._();

  StreamSubscription<List<AlertModel>>? _sub;
  String? _activeAdminUid;
  final Set<String> _sessionNotifiedKeys = <String>{};
  int _lastNotifiedTs = 0;

  Future<void> start(String adminUid) async {
    if (_activeAdminUid == adminUid && _sub != null) {
      return;
    }
    await stop();

    _activeAdminUid = adminUid;
    final prefs = await SharedPreferences.getInstance();
    _lastNotifiedTs =
        prefs.getInt('admin_last_notified_alert_ts_$adminUid') ?? 0;

    await LocalNotificationService.instance.initialize();
    _sub = RbacRepository.instance
        .watchAdminAlerts(adminUid, includeResolved: true)
        .listen((alerts) async {
          var maxTs = _lastNotifiedTs;
          for (final alert in alerts) {
            if (alert.resolved) {
              continue;
            }
            final ts = alert.createdAt.millisecondsSinceEpoch;
            final key = alert.remoteKey ?? '${alert.deviceId}_$ts';
            final shouldNotify =
                ts > _lastNotifiedTs && !_sessionNotifiedKeys.contains(key);
            if (shouldNotify) {
              await LocalNotificationService.instance.showImmediateAlert(
                title: 'BovineTrack Alert: ${alert.type}',
                body: '${alert.deviceId}: ${alert.message}',
              );
              _sessionNotifiedKeys.add(key);
            }
            if (ts > maxTs) {
              maxTs = ts;
            }
          }

          if (maxTs > _lastNotifiedTs && _activeAdminUid != null) {
            _lastNotifiedTs = maxTs;
            final currentPrefs = await SharedPreferences.getInstance();
            await currentPrefs.setInt(
              'admin_last_notified_alert_ts_${_activeAdminUid!}',
              _lastNotifiedTs,
            );
          }
        });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _activeAdminUid = null;
    _sessionNotifiedKeys.clear();
  }
}
