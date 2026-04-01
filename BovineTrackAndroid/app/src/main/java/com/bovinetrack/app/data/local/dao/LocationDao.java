package com.bovinetrack.app.data.local.dao;

import androidx.lifecycle.LiveData;
import androidx.room.Dao;
import androidx.room.Insert;
import androidx.room.Query;

import com.bovinetrack.app.data.local.entity.LocationEntity;

import java.util.List;

@Dao
public interface LocationDao {
    @Insert
    long insert(LocationEntity location);

    @Query("SELECT * FROM locations WHERE deviceId = :deviceId ORDER BY timestamp DESC LIMIT 1")
    LiveData<LocationEntity> observeLatest(String deviceId);

    @Query("SELECT * FROM locations WHERE deviceId = :deviceId ORDER BY timestamp DESC LIMIT 150")
    LiveData<List<LocationEntity>> observeRecent(String deviceId);

    @Query("SELECT * FROM locations WHERE deviceId = :deviceId AND timestamp < :before ORDER BY timestamp DESC LIMIT :limit")
    List<LocationEntity> loadHistoryPage(String deviceId, long before, int limit);

    @Query("SELECT * FROM locations WHERE synced = 0 ORDER BY timestamp ASC LIMIT 100")
    List<LocationEntity> pendingSync();

    @Query("UPDATE locations SET synced = 1 WHERE id = :id")
    void markSynced(long id);

    @Query("SELECT * FROM locations WHERE timestamp > :since ORDER BY timestamp DESC")
    LiveData<List<LocationEntity>> observeLatestAll(long since);

    @Query("SELECT * FROM locations WHERE id IN (SELECT MAX(id) FROM locations GROUP BY deviceId) ORDER BY timestamp DESC")
    LiveData<List<LocationEntity>> observeLatestPerDevice();
}
