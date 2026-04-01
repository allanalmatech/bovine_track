package com.bovinetrack.app.data;

import com.bovinetrack.app.data.local.entity.GeofenceZoneEntity;
import com.bovinetrack.app.data.local.entity.LocationEntity;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class GeofenceEngine {
    public static GeofenceEvaluation evaluateCrossings(
            LocationEntity location,
            List<GeofenceZoneEntity> zones,
            Map<Long, Boolean> previousInside
    ) {
        List<String> alerts = new ArrayList<>();
        Map<Long, Boolean> currentInside = new HashMap<>();
        for (GeofenceZoneEntity zone : zones) {
            boolean inside = isInsideZone(location.latitude, location.longitude, zone);
            currentInside.put(zone.id, inside);
            Boolean before = previousInside.get(zone.id);
            if (before == null || before == inside) {
                continue;
            }

            if (zone.restricted) {
                if (inside) {
                    alerts.add("Restricted zone entry: " + zone.name);
                } else {
                    alerts.add("Restricted zone exit: " + zone.name);
                }
            } else {
                if (inside) {
                    alerts.add("Returned to safe zone: " + zone.name);
                } else {
                    alerts.add("Safe zone breach: " + zone.name);
                }
            }
        }
        return new GeofenceEvaluation(alerts, currentInside);
    }

    private static boolean isInsideZone(double lat, double lng, GeofenceZoneEntity zone) {
        if (zone.polygon && zone.polygonPoints != null && !zone.polygonPoints.isEmpty()) {
            List<double[]> points = parsePoints(zone.polygonPoints);
            if (points.size() >= 3) {
                return pointInPolygon(lat, lng, points);
            }
        }
        double distance = distanceMeters(lat, lng, zone.centerLat, zone.centerLng);
        return distance <= zone.radiusMeters;
    }

    public static List<double[]> parsePoints(String raw) {
        List<double[]> out = new ArrayList<>();
        String[] pairs = raw.split(";");
        for (String pair : pairs) {
            String[] parts = pair.trim().split(",");
            if (parts.length == 2) {
                try {
                    out.add(new double[]{Double.parseDouble(parts[0].trim()), Double.parseDouble(parts[1].trim())});
                } catch (Exception ignored) {
                }
            }
        }
        return out;
    }

    private static boolean pointInPolygon(double lat, double lng, List<double[]> polygon) {
        boolean inside = false;
        for (int i = 0, j = polygon.size() - 1; i < polygon.size(); j = i++) {
            double latI = polygon.get(i)[0];
            double lngI = polygon.get(i)[1];
            double latJ = polygon.get(j)[0];
            double lngJ = polygon.get(j)[1];

            boolean intersect = ((lngI > lng) != (lngJ > lng))
                    && (lat < (latJ - latI) * (lng - lngI) / (lngJ - lngI + 1e-12) + latI);
            if (intersect) {
                inside = !inside;
            }
        }
        return inside;
    }

    private static double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
        double earth = 6371000.0;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLng = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        return 2 * earth * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }

    public static class GeofenceEvaluation {
        public final List<String> alerts;
        public final Map<Long, Boolean> zoneInsideState;

        public GeofenceEvaluation(List<String> alerts, Map<Long, Boolean> zoneInsideState) {
            this.alerts = alerts;
            this.zoneInsideState = zoneInsideState;
        }
    }
}
