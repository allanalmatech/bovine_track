package com.bovinetrack.app.data.local.dao;

import android.database.Cursor;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.lifecycle.LiveData;
import androidx.room.EntityInsertionAdapter;
import androidx.room.RoomDatabase;
import androidx.room.RoomSQLiteQuery;
import androidx.room.SharedSQLiteStatement;
import androidx.room.util.CursorUtil;
import androidx.room.util.DBUtil;
import androidx.sqlite.db.SupportSQLiteStatement;
import com.bovinetrack.app.data.local.entity.LocationEntity;
import java.lang.Class;
import java.lang.Exception;
import java.lang.Override;
import java.lang.String;
import java.lang.SuppressWarnings;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.Callable;
import javax.annotation.processing.Generated;

@Generated("androidx.room.RoomProcessor")
@SuppressWarnings({"unchecked", "deprecation"})
public final class LocationDao_Impl implements LocationDao {
  private final RoomDatabase __db;

  private final EntityInsertionAdapter<LocationEntity> __insertionAdapterOfLocationEntity;

  private final SharedSQLiteStatement __preparedStmtOfMarkSynced;

  public LocationDao_Impl(@NonNull final RoomDatabase __db) {
    this.__db = __db;
    this.__insertionAdapterOfLocationEntity = new EntityInsertionAdapter<LocationEntity>(__db) {
      @Override
      @NonNull
      protected String createQuery() {
        return "INSERT OR ABORT INTO `locations` (`id`,`deviceId`,`latitude`,`longitude`,`speed`,`timestamp`,`battery`,`simulated`,`synced`) VALUES (nullif(?, 0),?,?,?,?,?,?,?,?)";
      }

      @Override
      protected void bind(@NonNull final SupportSQLiteStatement statement,
          final LocationEntity entity) {
        statement.bindLong(1, entity.id);
        if (entity.deviceId == null) {
          statement.bindNull(2);
        } else {
          statement.bindString(2, entity.deviceId);
        }
        statement.bindDouble(3, entity.latitude);
        statement.bindDouble(4, entity.longitude);
        statement.bindDouble(5, entity.speed);
        statement.bindLong(6, entity.timestamp);
        statement.bindLong(7, entity.battery);
        final int _tmp = entity.simulated ? 1 : 0;
        statement.bindLong(8, _tmp);
        final int _tmp_1 = entity.synced ? 1 : 0;
        statement.bindLong(9, _tmp_1);
      }
    };
    this.__preparedStmtOfMarkSynced = new SharedSQLiteStatement(__db) {
      @Override
      @NonNull
      public String createQuery() {
        final String _query = "UPDATE locations SET synced = 1 WHERE id = ?";
        return _query;
      }
    };
  }

  @Override
  public long insert(final LocationEntity location) {
    __db.assertNotSuspendingTransaction();
    __db.beginTransaction();
    try {
      final long _result = __insertionAdapterOfLocationEntity.insertAndReturnId(location);
      __db.setTransactionSuccessful();
      return _result;
    } finally {
      __db.endTransaction();
    }
  }

  @Override
  public void markSynced(final long id) {
    __db.assertNotSuspendingTransaction();
    final SupportSQLiteStatement _stmt = __preparedStmtOfMarkSynced.acquire();
    int _argIndex = 1;
    _stmt.bindLong(_argIndex, id);
    try {
      __db.beginTransaction();
      try {
        _stmt.executeUpdateDelete();
        __db.setTransactionSuccessful();
      } finally {
        __db.endTransaction();
      }
    } finally {
      __preparedStmtOfMarkSynced.release(_stmt);
    }
  }

  @Override
  public LiveData<LocationEntity> observeLatest(final String deviceId) {
    final String _sql = "SELECT * FROM locations WHERE deviceId = ? ORDER BY timestamp DESC LIMIT 1";
    final RoomSQLiteQuery _statement = RoomSQLiteQuery.acquire(_sql, 1);
    int _argIndex = 1;
    if (deviceId == null) {
      _statement.bindNull(_argIndex);
    } else {
      _statement.bindString(_argIndex, deviceId);
    }
    return __db.getInvalidationTracker().createLiveData(new String[] {"locations"}, false, new Callable<LocationEntity>() {
      @Override
      @Nullable
      public LocationEntity call() throws Exception {
        final Cursor _cursor = DBUtil.query(__db, _statement, false, null);
        try {
          final int _cursorIndexOfId = CursorUtil.getColumnIndexOrThrow(_cursor, "id");
          final int _cursorIndexOfDeviceId = CursorUtil.getColumnIndexOrThrow(_cursor, "deviceId");
          final int _cursorIndexOfLatitude = CursorUtil.getColumnIndexOrThrow(_cursor, "latitude");
          final int _cursorIndexOfLongitude = CursorUtil.getColumnIndexOrThrow(_cursor, "longitude");
          final int _cursorIndexOfSpeed = CursorUtil.getColumnIndexOrThrow(_cursor, "speed");
          final int _cursorIndexOfTimestamp = CursorUtil.getColumnIndexOrThrow(_cursor, "timestamp");
          final int _cursorIndexOfBattery = CursorUtil.getColumnIndexOrThrow(_cursor, "battery");
          final int _cursorIndexOfSimulated = CursorUtil.getColumnIndexOrThrow(_cursor, "simulated");
          final int _cursorIndexOfSynced = CursorUtil.getColumnIndexOrThrow(_cursor, "synced");
          final LocationEntity _result;
          if (_cursor.moveToFirst()) {
            _result = new LocationEntity();
            _result.id = _cursor.getLong(_cursorIndexOfId);
            if (_cursor.isNull(_cursorIndexOfDeviceId)) {
              _result.deviceId = null;
            } else {
              _result.deviceId = _cursor.getString(_cursorIndexOfDeviceId);
            }
            _result.latitude = _cursor.getDouble(_cursorIndexOfLatitude);
            _result.longitude = _cursor.getDouble(_cursorIndexOfLongitude);
            _result.speed = _cursor.getFloat(_cursorIndexOfSpeed);
            _result.timestamp = _cursor.getLong(_cursorIndexOfTimestamp);
            _result.battery = _cursor.getInt(_cursorIndexOfBattery);
            final int _tmp;
            _tmp = _cursor.getInt(_cursorIndexOfSimulated);
            _result.simulated = _tmp != 0;
            final int _tmp_1;
            _tmp_1 = _cursor.getInt(_cursorIndexOfSynced);
            _result.synced = _tmp_1 != 0;
          } else {
            _result = null;
          }
          return _result;
        } finally {
          _cursor.close();
        }
      }

      @Override
      protected void finalize() {
        _statement.release();
      }
    });
  }

  @Override
  public LiveData<List<LocationEntity>> observeRecent(final String deviceId) {
    final String _sql = "SELECT * FROM locations WHERE deviceId = ? ORDER BY timestamp DESC LIMIT 150";
    final RoomSQLiteQuery _statement = RoomSQLiteQuery.acquire(_sql, 1);
    int _argIndex = 1;
    if (deviceId == null) {
      _statement.bindNull(_argIndex);
    } else {
      _statement.bindString(_argIndex, deviceId);
    }
    return __db.getInvalidationTracker().createLiveData(new String[] {"locations"}, false, new Callable<List<LocationEntity>>() {
      @Override
      @Nullable
      public List<LocationEntity> call() throws Exception {
        final Cursor _cursor = DBUtil.query(__db, _statement, false, null);
        try {
          final int _cursorIndexOfId = CursorUtil.getColumnIndexOrThrow(_cursor, "id");
          final int _cursorIndexOfDeviceId = CursorUtil.getColumnIndexOrThrow(_cursor, "deviceId");
          final int _cursorIndexOfLatitude = CursorUtil.getColumnIndexOrThrow(_cursor, "latitude");
          final int _cursorIndexOfLongitude = CursorUtil.getColumnIndexOrThrow(_cursor, "longitude");
          final int _cursorIndexOfSpeed = CursorUtil.getColumnIndexOrThrow(_cursor, "speed");
          final int _cursorIndexOfTimestamp = CursorUtil.getColumnIndexOrThrow(_cursor, "timestamp");
          final int _cursorIndexOfBattery = CursorUtil.getColumnIndexOrThrow(_cursor, "battery");
          final int _cursorIndexOfSimulated = CursorUtil.getColumnIndexOrThrow(_cursor, "simulated");
          final int _cursorIndexOfSynced = CursorUtil.getColumnIndexOrThrow(_cursor, "synced");
          final List<LocationEntity> _result = new ArrayList<LocationEntity>(_cursor.getCount());
          while (_cursor.moveToNext()) {
            final LocationEntity _item;
            _item = new LocationEntity();
            _item.id = _cursor.getLong(_cursorIndexOfId);
            if (_cursor.isNull(_cursorIndexOfDeviceId)) {
              _item.deviceId = null;
            } else {
              _item.deviceId = _cursor.getString(_cursorIndexOfDeviceId);
            }
            _item.latitude = _cursor.getDouble(_cursorIndexOfLatitude);
            _item.longitude = _cursor.getDouble(_cursorIndexOfLongitude);
            _item.speed = _cursor.getFloat(_cursorIndexOfSpeed);
            _item.timestamp = _cursor.getLong(_cursorIndexOfTimestamp);
            _item.battery = _cursor.getInt(_cursorIndexOfBattery);
            final int _tmp;
            _tmp = _cursor.getInt(_cursorIndexOfSimulated);
            _item.simulated = _tmp != 0;
            final int _tmp_1;
            _tmp_1 = _cursor.getInt(_cursorIndexOfSynced);
            _item.synced = _tmp_1 != 0;
            _result.add(_item);
          }
          return _result;
        } finally {
          _cursor.close();
        }
      }

      @Override
      protected void finalize() {
        _statement.release();
      }
    });
  }

  @Override
  public List<LocationEntity> pendingSync() {
    final String _sql = "SELECT * FROM locations WHERE synced = 0 ORDER BY timestamp ASC LIMIT 100";
    final RoomSQLiteQuery _statement = RoomSQLiteQuery.acquire(_sql, 0);
    __db.assertNotSuspendingTransaction();
    final Cursor _cursor = DBUtil.query(__db, _statement, false, null);
    try {
      final int _cursorIndexOfId = CursorUtil.getColumnIndexOrThrow(_cursor, "id");
      final int _cursorIndexOfDeviceId = CursorUtil.getColumnIndexOrThrow(_cursor, "deviceId");
      final int _cursorIndexOfLatitude = CursorUtil.getColumnIndexOrThrow(_cursor, "latitude");
      final int _cursorIndexOfLongitude = CursorUtil.getColumnIndexOrThrow(_cursor, "longitude");
      final int _cursorIndexOfSpeed = CursorUtil.getColumnIndexOrThrow(_cursor, "speed");
      final int _cursorIndexOfTimestamp = CursorUtil.getColumnIndexOrThrow(_cursor, "timestamp");
      final int _cursorIndexOfBattery = CursorUtil.getColumnIndexOrThrow(_cursor, "battery");
      final int _cursorIndexOfSimulated = CursorUtil.getColumnIndexOrThrow(_cursor, "simulated");
      final int _cursorIndexOfSynced = CursorUtil.getColumnIndexOrThrow(_cursor, "synced");
      final List<LocationEntity> _result = new ArrayList<LocationEntity>(_cursor.getCount());
      while (_cursor.moveToNext()) {
        final LocationEntity _item;
        _item = new LocationEntity();
        _item.id = _cursor.getLong(_cursorIndexOfId);
        if (_cursor.isNull(_cursorIndexOfDeviceId)) {
          _item.deviceId = null;
        } else {
          _item.deviceId = _cursor.getString(_cursorIndexOfDeviceId);
        }
        _item.latitude = _cursor.getDouble(_cursorIndexOfLatitude);
        _item.longitude = _cursor.getDouble(_cursorIndexOfLongitude);
        _item.speed = _cursor.getFloat(_cursorIndexOfSpeed);
        _item.timestamp = _cursor.getLong(_cursorIndexOfTimestamp);
        _item.battery = _cursor.getInt(_cursorIndexOfBattery);
        final int _tmp;
        _tmp = _cursor.getInt(_cursorIndexOfSimulated);
        _item.simulated = _tmp != 0;
        final int _tmp_1;
        _tmp_1 = _cursor.getInt(_cursorIndexOfSynced);
        _item.synced = _tmp_1 != 0;
        _result.add(_item);
      }
      return _result;
    } finally {
      _cursor.close();
      _statement.release();
    }
  }

  @Override
  public LiveData<List<LocationEntity>> observeLatestAll(final long since) {
    final String _sql = "SELECT * FROM locations WHERE timestamp > ? ORDER BY timestamp DESC";
    final RoomSQLiteQuery _statement = RoomSQLiteQuery.acquire(_sql, 1);
    int _argIndex = 1;
    _statement.bindLong(_argIndex, since);
    return __db.getInvalidationTracker().createLiveData(new String[] {"locations"}, false, new Callable<List<LocationEntity>>() {
      @Override
      @Nullable
      public List<LocationEntity> call() throws Exception {
        final Cursor _cursor = DBUtil.query(__db, _statement, false, null);
        try {
          final int _cursorIndexOfId = CursorUtil.getColumnIndexOrThrow(_cursor, "id");
          final int _cursorIndexOfDeviceId = CursorUtil.getColumnIndexOrThrow(_cursor, "deviceId");
          final int _cursorIndexOfLatitude = CursorUtil.getColumnIndexOrThrow(_cursor, "latitude");
          final int _cursorIndexOfLongitude = CursorUtil.getColumnIndexOrThrow(_cursor, "longitude");
          final int _cursorIndexOfSpeed = CursorUtil.getColumnIndexOrThrow(_cursor, "speed");
          final int _cursorIndexOfTimestamp = CursorUtil.getColumnIndexOrThrow(_cursor, "timestamp");
          final int _cursorIndexOfBattery = CursorUtil.getColumnIndexOrThrow(_cursor, "battery");
          final int _cursorIndexOfSimulated = CursorUtil.getColumnIndexOrThrow(_cursor, "simulated");
          final int _cursorIndexOfSynced = CursorUtil.getColumnIndexOrThrow(_cursor, "synced");
          final List<LocationEntity> _result = new ArrayList<LocationEntity>(_cursor.getCount());
          while (_cursor.moveToNext()) {
            final LocationEntity _item;
            _item = new LocationEntity();
            _item.id = _cursor.getLong(_cursorIndexOfId);
            if (_cursor.isNull(_cursorIndexOfDeviceId)) {
              _item.deviceId = null;
            } else {
              _item.deviceId = _cursor.getString(_cursorIndexOfDeviceId);
            }
            _item.latitude = _cursor.getDouble(_cursorIndexOfLatitude);
            _item.longitude = _cursor.getDouble(_cursorIndexOfLongitude);
            _item.speed = _cursor.getFloat(_cursorIndexOfSpeed);
            _item.timestamp = _cursor.getLong(_cursorIndexOfTimestamp);
            _item.battery = _cursor.getInt(_cursorIndexOfBattery);
            final int _tmp;
            _tmp = _cursor.getInt(_cursorIndexOfSimulated);
            _item.simulated = _tmp != 0;
            final int _tmp_1;
            _tmp_1 = _cursor.getInt(_cursorIndexOfSynced);
            _item.synced = _tmp_1 != 0;
            _result.add(_item);
          }
          return _result;
        } finally {
          _cursor.close();
        }
      }

      @Override
      protected void finalize() {
        _statement.release();
      }
    });
  }

  @NonNull
  public static List<Class<?>> getRequiredConverters() {
    return Collections.emptyList();
  }
}
