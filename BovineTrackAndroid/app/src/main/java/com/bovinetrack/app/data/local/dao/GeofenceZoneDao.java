package com.bovinetrack.app.data.local.dao;

import androidx.lifecycle.LiveData;
import androidx.room.Dao;
import androidx.room.Insert;
import androidx.room.Query;

import com.bovinetrack.app.data.local.entity.GeofenceZoneEntity;

import java.util.List;

@Dao
public interface GeofenceZoneDao {
    @Insert
    long insert(GeofenceZoneEntity zone);

    @Query("SELECT * FROM zones ORDER BY id DESC")
    LiveData<List<GeofenceZoneEntity>> observeAll();

    @Query("SELECT * FROM zones")
    List<GeofenceZoneEntity> getAll();
}
