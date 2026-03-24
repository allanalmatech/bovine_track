package com.bovinetrack.app.data.local.entity;

import androidx.room.Entity;
import androidx.room.PrimaryKey;

@Entity(tableName = "zones")
public class GeofenceZoneEntity {
    @PrimaryKey(autoGenerate = true)
    public long id;

    public String name;
    public double centerLat;
    public double centerLng;
    public float radiusMeters;
    public boolean polygon;
    public String polygonPoints;
    public boolean restricted;
}
