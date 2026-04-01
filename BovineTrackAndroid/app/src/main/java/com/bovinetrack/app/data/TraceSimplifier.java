package com.bovinetrack.app.data;

import com.google.android.gms.maps.model.LatLng;

import java.util.ArrayList;
import java.util.List;

public class TraceSimplifier {
    public static List<LatLng> simplifyByZoom(List<LatLng> points, float zoom) {
        if (points == null || points.size() < 3) {
            return points;
        }
        double epsilonMeters;
        if (zoom >= 16f) {
            epsilonMeters = 5.0;
        } else if (zoom >= 13f) {
            epsilonMeters = 15.0;
        } else if (zoom >= 10f) {
            epsilonMeters = 40.0;
        } else {
            epsilonMeters = 120.0;
        }

        List<LatLng> out = new ArrayList<>();
        LatLng lastKept = points.get(0);
        out.add(lastKept);
        for (int i = 1; i < points.size() - 1; i++) {
            LatLng current = points.get(i);
            if (distanceMeters(lastKept, current) >= epsilonMeters) {
                out.add(current);
                lastKept = current;
            }
        }
        out.add(points.get(points.size() - 1));
        return out;
    }

    private static double distanceMeters(LatLng a, LatLng b) {
        double earth = 6371000.0;
        double dLat = Math.toRadians(b.latitude - a.latitude);
        double dLng = Math.toRadians(b.longitude - a.longitude);
        double x = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(a.latitude)) * Math.cos(Math.toRadians(b.latitude))
                * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        return 2 * earth * Math.atan2(Math.sqrt(x), Math.sqrt(1 - x));
    }
}
