package com.bovinetrack.app.data;

import com.google.android.gms.maps.model.LatLng;

import java.util.List;

public class PolygonValidator {
    private static final double MIN_AREA_SQ_METERS = 100.0;

    public static boolean isSelfIntersecting(List<LatLng> points) {
        if (points == null || points.size() < 4) {
            return false;
        }
        int n = points.size();
        for (int i = 0; i < n; i++) {
            LatLng a1 = points.get(i);
            LatLng a2 = points.get((i + 1) % n);
            for (int j = i + 1; j < n; j++) {
                if (Math.abs(i - j) <= 1) {
                    continue;
                }
                if (i == 0 && j == n - 1) {
                    continue;
                }
                LatLng b1 = points.get(j);
                LatLng b2 = points.get((j + 1) % n);
                if (segmentsIntersect(a1, a2, b1, b2)) {
                    return true;
                }
            }
        }
        return false;
    }

    private static boolean segmentsIntersect(LatLng p1, LatLng p2, LatLng q1, LatLng q2) {
        int o1 = orientation(p1, p2, q1);
        int o2 = orientation(p1, p2, q2);
        int o3 = orientation(q1, q2, p1);
        int o4 = orientation(q1, q2, p2);

        if (o1 != o2 && o3 != o4) {
            return true;
        }
        if (o1 == 0 && onSegment(p1, q1, p2)) {
            return true;
        }
        if (o2 == 0 && onSegment(p1, q2, p2)) {
            return true;
        }
        if (o3 == 0 && onSegment(q1, p1, q2)) {
            return true;
        }
        return o4 == 0 && onSegment(q1, p2, q2);
    }

    private static int orientation(LatLng p, LatLng q, LatLng r) {
        double value = (q.longitude - p.longitude) * (r.latitude - q.latitude)
                - (q.latitude - p.latitude) * (r.longitude - q.longitude);
        if (Math.abs(value) < 1e-12) {
            return 0;
        }
        return value > 0 ? 1 : 2;
    }

    private static boolean onSegment(LatLng p, LatLng q, LatLng r) {
        return q.latitude <= Math.max(p.latitude, r.latitude)
                && q.latitude >= Math.min(p.latitude, r.latitude)
                && q.longitude <= Math.max(p.longitude, r.longitude)
                && q.longitude >= Math.min(p.longitude, r.longitude);
    }

    public static double calculateAreaSqMeters(List<LatLng> points) {
        if (points == null || points.size() < 3) {
            return 0.0;
        }
        double sum = 0.0;
        int n = points.size();
        for (int i = 0; i < n; i++) {
            LatLng curr = points.get(i);
            LatLng next = points.get((i + 1) % n);
            sum += curr.longitude * next.latitude - next.longitude * curr.latitude;
        }
        double absAreaDeg2 = Math.abs(sum) / 2.0;
        double avgLat = 0.0;
        for (LatLng p : points) {
            avgLat += p.latitude;
        }
        avgLat /= n;
        return absAreaDeg2 * 111320.0 * 111320.0 * Math.cos(Math.toRadians(avgLat));
    }

    public static boolean hasValidArea(List<LatLng> points) {
        return calculateAreaSqMeters(points) >= MIN_AREA_SQ_METERS;
    }
}
