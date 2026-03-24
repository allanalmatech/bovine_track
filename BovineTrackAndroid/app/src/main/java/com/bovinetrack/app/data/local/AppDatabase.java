package com.bovinetrack.app.data.local;

import android.content.Context;

import androidx.room.Database;
import androidx.room.Room;
import androidx.room.RoomDatabase;

import com.bovinetrack.app.data.local.dao.AlertDao;
import com.bovinetrack.app.data.local.dao.GeofenceZoneDao;
import com.bovinetrack.app.data.local.dao.LocationDao;
import com.bovinetrack.app.data.local.entity.AlertEntity;
import com.bovinetrack.app.data.local.entity.GeofenceZoneEntity;
import com.bovinetrack.app.data.local.entity.LocationEntity;

@Database(entities = {LocationEntity.class, GeofenceZoneEntity.class, AlertEntity.class}, version = 1)
public abstract class AppDatabase extends RoomDatabase {
    private static volatile AppDatabase instance;

    public abstract LocationDao locationDao();
    public abstract GeofenceZoneDao zoneDao();
    public abstract AlertDao alertDao();

    public static AppDatabase get(Context context) {
        if (instance == null) {
            synchronized (AppDatabase.class) {
                if (instance == null) {
                    instance = Room.databaseBuilder(
                            context.getApplicationContext(),
                            AppDatabase.class,
                            "bovinetrack.db"
                    ).build();
                }
            }
        }
        return instance;
    }
}
