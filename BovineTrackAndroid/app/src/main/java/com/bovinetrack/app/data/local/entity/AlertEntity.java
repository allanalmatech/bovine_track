package com.bovinetrack.app.data.local.entity;

import androidx.room.Entity;
import androidx.room.PrimaryKey;

@Entity(tableName = "alerts")
public class AlertEntity {
    @PrimaryKey(autoGenerate = true)
    public long id;

    public String deviceId;
    public String type;
    public String message;
    public double latitude;
    public double longitude;
    public long timestamp;
}
