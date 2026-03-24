package com.bovinetrack.app.data.local.dao;

import androidx.lifecycle.LiveData;
import androidx.room.Dao;
import androidx.room.Insert;
import androidx.room.Query;

import com.bovinetrack.app.data.local.entity.AlertEntity;

import java.util.List;

@Dao
public interface AlertDao {
    @Insert
    long insert(AlertEntity alert);

    @Query("SELECT * FROM alerts ORDER BY timestamp DESC LIMIT 200")
    LiveData<List<AlertEntity>> observeRecent();

    @Query("SELECT COUNT(*) FROM alerts WHERE timestamp > :since")
    LiveData<Integer> countSince(long since);
}
