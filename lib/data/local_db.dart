import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) {
      return _db!;
    }
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'bovinetrack.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE geofences (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            vertices TEXT NOT NULL,
            is_restricted INTEGER NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');

        await database.execute('''
          CREATE TABLE locations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id TEXT NOT NULL,
            lat REAL NOT NULL,
            lng REAL NOT NULL,
            speed REAL NOT NULL,
            recorded_at INTEGER NOT NULL,
            synced INTEGER NOT NULL
          )
        ''');

        await database.execute('''
          CREATE TABLE alerts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id TEXT NOT NULL,
            type TEXT NOT NULL,
            message TEXT NOT NULL,
            lat REAL NOT NULL,
            lng REAL NOT NULL,
            created_at INTEGER NOT NULL,
            synced INTEGER NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }
}
