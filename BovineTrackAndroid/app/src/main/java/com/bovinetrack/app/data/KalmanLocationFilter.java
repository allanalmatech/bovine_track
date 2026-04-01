package com.bovinetrack.app.data;

import android.location.Location;

public class KalmanLocationFilter {
    private final Kalman1D latFilter = new Kalman1D();
    private final Kalman1D lngFilter = new Kalman1D();
    private long lastTimestamp;

    public synchronized Location smooth(Location raw) {
        if (raw == null) {
            return null;
        }
        long now = raw.getTime() > 0 ? raw.getTime() : System.currentTimeMillis();
        double dtSeconds = lastTimestamp == 0 ? 1.0 : Math.max(0.1, (now - lastTimestamp) / 1000.0);
        lastTimestamp = now;

        double noise = Math.max(4.0, raw.hasAccuracy() ? raw.getAccuracy() : 12.0);
        double lat = latFilter.update(raw.getLatitude(), dtSeconds, noise);
        double lng = lngFilter.update(raw.getLongitude(), dtSeconds, noise);

        Location out = new Location(raw);
        out.setLatitude(lat);
        out.setLongitude(lng);
        return out;
    }

    private static class Kalman1D {
        private double estimate;
        private double covariance = 1;
        private boolean initialized;
        private final double processNoise = 0.15;

        double update(double measurement, double dtSeconds, double measurementNoise) {
            if (!initialized) {
                estimate = measurement;
                covariance = 1;
                initialized = true;
                return estimate;
            }

            covariance += processNoise * dtSeconds;

            double r = Math.max(1.0, measurementNoise * measurementNoise);
            double gain = covariance / (covariance + r);
            estimate = estimate + gain * (measurement - estimate);
            covariance = (1 - gain) * covariance;
            return estimate;
        }
    }
}
