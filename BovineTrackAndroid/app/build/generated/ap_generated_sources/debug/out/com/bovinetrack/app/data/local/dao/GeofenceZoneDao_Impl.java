package com.bovinetrack.app.data.local.dao;

import android.database.Cursor;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.lifecycle.LiveData;
import androidx.room.EntityInsertionAdapter;
import androidx.room.RoomDatabase;
import androidx.room.RoomSQLiteQuery;
import androidx.room.util.CursorUtil;
import androidx.room.util.DBUtil;
import androidx.sqlite.db.SupportSQLiteStatement;
import com.bovinetrack.app.data.local.entity.GeofenceZoneEntity;
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
public final class GeofenceZoneDao_Impl implements GeofenceZoneDao {
  private final RoomDatabase __db;

  private final EntityInsertionAdapter<GeofenceZoneEntity> __insertionAdapterOfGeofenceZoneEntity;

  public GeofenceZoneDao_Impl(@NonNull final RoomDatabase __db) {
    this.__db = __db;
    this.__insertionAdapterOfGeofenceZoneEntity = new EntityInsertionAdapter<GeofenceZoneEntity>(__db) {
      @Override
      @NonNull
      protected String createQuery() {
        return "INSERT OR ABORT INTO `zones` (`id`,`name`,`centerLat`,`centerLng`,`radiusMeters`,`polygon`,`polygonPoints`,`restricted`) VALUES (nullif(?, 0),?,?,?,?,?,?,?)";
      }

      @Override
      protected void bind(@NonNull final SupportSQLiteStatement statement,
          final GeofenceZoneEntity entity) {
        statement.bindLong(1, entity.id);
        if (entity.name == null) {
          statement.bindNull(2);
        } else {
          statement.bindString(2, entity.name);
        }
        statement.bindDouble(3, entity.centerLat);
        statement.bindDouble(4, entity.centerLng);
        statement.bindDouble(5, entity.radiusMeters);
        final int _tmp = entity.polygon ? 1 : 0;
        statement.bindLong(6, _tmp);
        if (entity.polygonPoints == null) {
          statement.bindNull(7);
        } else {
          statement.bindString(7, entity.polygonPoints);
        }
        final int _tmp_1 = entity.restricted ? 1 : 0;
        statement.bindLong(8, _tmp_1);
      }
    };
  }

  @Override
  public long insert(final GeofenceZoneEntity zone) {
    __db.assertNotSuspendingTransaction();
    __db.beginTransaction();
    try {
      final long _result = __insertionAdapterOfGeofenceZoneEntity.insertAndReturnId(zone);
      __db.setTransactionSuccessful();
      return _result;
    } finally {
      __db.endTransaction();
    }
  }

  @Override
  public LiveData<List<GeofenceZoneEntity>> observeAll() {
    final String _sql = "SELECT * FROM zones ORDER BY id DESC";
    final RoomSQLiteQuery _statement = RoomSQLiteQuery.acquire(_sql, 0);
    return __db.getInvalidationTracker().createLiveData(new String[] {"zones"}, false, new Callable<List<GeofenceZoneEntity>>() {
      @Override
      @Nullable
      public List<GeofenceZoneEntity> call() throws Exception {
        final Cursor _cursor = DBUtil.query(__db, _statement, false, null);
        try {
          final int _cursorIndexOfId = CursorUtil.getColumnIndexOrThrow(_cursor, "id");
          final int _cursorIndexOfName = CursorUtil.getColumnIndexOrThrow(_cursor, "name");
          final int _cursorIndexOfCenterLat = CursorUtil.getColumnIndexOrThrow(_cursor, "centerLat");
          final int _cursorIndexOfCenterLng = CursorUtil.getColumnIndexOrThrow(_cursor, "centerLng");
          final int _cursorIndexOfRadiusMeters = CursorUtil.getColumnIndexOrThrow(_cursor, "radiusMeters");
          final int _cursorIndexOfPolygon = CursorUtil.getColumnIndexOrThrow(_cursor, "polygon");
          final int _cursorIndexOfPolygonPoints = CursorUtil.getColumnIndexOrThrow(_cursor, "polygonPoints");
          final int _cursorIndexOfRestricted = CursorUtil.getColumnIndexOrThrow(_cursor, "restricted");
          final List<GeofenceZoneEntity> _result = new ArrayList<GeofenceZoneEntity>(_cursor.getCount());
          while (_cursor.moveToNext()) {
            final GeofenceZoneEntity _item;
            _item = new GeofenceZoneEntity();
            _item.id = _cursor.getLong(_cursorIndexOfId);
            if (_cursor.isNull(_cursorIndexOfName)) {
              _item.name = null;
            } else {
              _item.name = _cursor.getString(_cursorIndexOfName);
            }
            _item.centerLat = _cursor.getDouble(_cursorIndexOfCenterLat);
            _item.centerLng = _cursor.getDouble(_cursorIndexOfCenterLng);
            _item.radiusMeters = _cursor.getFloat(_cursorIndexOfRadiusMeters);
            final int _tmp;
            _tmp = _cursor.getInt(_cursorIndexOfPolygon);
            _item.polygon = _tmp != 0;
            if (_cursor.isNull(_cursorIndexOfPolygonPoints)) {
              _item.polygonPoints = null;
            } else {
              _item.polygonPoints = _cursor.getString(_cursorIndexOfPolygonPoints);
            }
            final int _tmp_1;
            _tmp_1 = _cursor.getInt(_cursorIndexOfRestricted);
            _item.restricted = _tmp_1 != 0;
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
  public List<GeofenceZoneEntity> getAll() {
    final String _sql = "SELECT * FROM zones";
    final RoomSQLiteQuery _statement = RoomSQLiteQuery.acquire(_sql, 0);
    __db.assertNotSuspendingTransaction();
    final Cursor _cursor = DBUtil.query(__db, _statement, false, null);
    try {
      final int _cursorIndexOfId = CursorUtil.getColumnIndexOrThrow(_cursor, "id");
      final int _cursorIndexOfName = CursorUtil.getColumnIndexOrThrow(_cursor, "name");
      final int _cursorIndexOfCenterLat = CursorUtil.getColumnIndexOrThrow(_cursor, "centerLat");
      final int _cursorIndexOfCenterLng = CursorUtil.getColumnIndexOrThrow(_cursor, "centerLng");
      final int _cursorIndexOfRadiusMeters = CursorUtil.getColumnIndexOrThrow(_cursor, "radiusMeters");
      final int _cursorIndexOfPolygon = CursorUtil.getColumnIndexOrThrow(_cursor, "polygon");
      final int _cursorIndexOfPolygonPoints = CursorUtil.getColumnIndexOrThrow(_cursor, "polygonPoints");
      final int _cursorIndexOfRestricted = CursorUtil.getColumnIndexOrThrow(_cursor, "restricted");
      final List<GeofenceZoneEntity> _result = new ArrayList<GeofenceZoneEntity>(_cursor.getCount());
      while (_cursor.moveToNext()) {
        final GeofenceZoneEntity _item;
        _item = new GeofenceZoneEntity();
        _item.id = _cursor.getLong(_cursorIndexOfId);
        if (_cursor.isNull(_cursorIndexOfName)) {
          _item.name = null;
        } else {
          _item.name = _cursor.getString(_cursorIndexOfName);
        }
        _item.centerLat = _cursor.getDouble(_cursorIndexOfCenterLat);
        _item.centerLng = _cursor.getDouble(_cursorIndexOfCenterLng);
        _item.radiusMeters = _cursor.getFloat(_cursorIndexOfRadiusMeters);
        final int _tmp;
        _tmp = _cursor.getInt(_cursorIndexOfPolygon);
        _item.polygon = _tmp != 0;
        if (_cursor.isNull(_cursorIndexOfPolygonPoints)) {
          _item.polygonPoints = null;
        } else {
          _item.polygonPoints = _cursor.getString(_cursorIndexOfPolygonPoints);
        }
        final int _tmp_1;
        _tmp_1 = _cursor.getInt(_cursorIndexOfRestricted);
        _item.restricted = _tmp_1 != 0;
        _result.add(_item);
      }
      return _result;
    } finally {
      _cursor.close();
      _statement.release();
    }
  }

  @NonNull
  public static List<Class<?>> getRequiredConverters() {
    return Collections.emptyList();
  }
}
