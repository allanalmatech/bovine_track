package com.bovinetrack.app.data.local.entity;

import androidx.room.Entity;
import androidx.room.PrimaryKey;

@Entity(tableName = "locations")
public class LocationEntity {
    @PrimaryKey(autoGenerate = true)
    public long id;

    public String deviceId;
    public double latitude;
    public double longitude;
    public float speed;
    public long timestamp;
    public int battery;
    public boolean simulated;
    public boolean synced;
}
