package com.bovinetrack.app.ui.server;

import android.graphics.Color;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.widget.CompoundButton;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.lifecycle.ViewModelProvider;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.bovinetrack.app.R;
import com.bovinetrack.app.data.DevicePreferences;
import com.bovinetrack.app.data.TraceSimplifier;
import com.google.android.gms.maps.CameraUpdateFactory;
import com.google.android.gms.maps.GoogleMap;
import com.google.android.gms.maps.OnMapReadyCallback;
import com.google.android.gms.maps.SupportMapFragment;
import com.google.android.gms.maps.model.CircleOptions;
import com.google.android.gms.maps.model.Circle;
import com.google.android.gms.maps.model.LatLng;
import com.google.android.gms.maps.model.Marker;
import com.google.android.gms.maps.model.MarkerOptions;
import com.google.android.gms.maps.model.Polygon;
import com.google.android.gms.maps.model.PolygonOptions;
import com.google.android.gms.maps.model.Polyline;
import com.google.android.gms.maps.model.PolylineOptions;
import com.google.android.material.switchmaterial.SwitchMaterial;
import com.bovinetrack.app.ui.common.SimpleLineAdapter;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class LiveMapActivity extends AppCompatActivity implements OnMapReadyCallback {
    private static final long RENDER_DEBOUNCE_MS = 500L;

    private GoogleMap map;
    private TextView mapStatus;
    private View mapContainer;
    private RecyclerView accessibleList;
    private SwitchMaterial accessibilityToggle;

    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final ExecutorService mapWorker = Executors.newSingleThreadExecutor();
    private final Map<String, Marker> markerByDevice = new HashMap<>();
    private final List<Circle> zoneCircles = new ArrayList<>();
    private final List<Polygon> zonePolygons = new ArrayList<>();
    private final List<Polyline> traceLines = new ArrayList<>();
    private final List<String> pendingAccessibleSummaries = new ArrayList<>();
    private List<com.bovinetrack.app.data.local.entity.LocationEntity> latestRows = new ArrayList<>();
    private boolean renderScheduled;
    private SimpleLineAdapter listAdapter;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_live_map);
        mapStatus = findViewById(R.id.mapStatus);
        mapContainer = findViewById(R.id.mapContainer);
        accessibleList = findViewById(R.id.accessibleList);
        accessibilityToggle = findViewById(R.id.accessibilityModeSwitch);
        listAdapter = new SimpleLineAdapter();
        accessibleList.setLayoutManager(new LinearLayoutManager(this));
        accessibleList.setAdapter(listAdapter);

        DevicePreferences preferences = new DevicePreferences(this);
        boolean accessibilityMode = preferences.isAccessibilityModeEnabled();
        accessibilityToggle.setChecked(accessibilityMode);
        applyAccessibilityMode(accessibilityMode);
        accessibilityToggle.setOnCheckedChangeListener((CompoundButton buttonView, boolean isChecked) -> {
            preferences.setAccessibilityModeEnabled(isChecked);
            applyAccessibilityMode(isChecked);
            renderAccessibleSummaries();
        });

        SupportMapFragment mapFragment = SupportMapFragment.newInstance();
        getSupportFragmentManager().beginTransaction()
                .replace(R.id.mapContainer, mapFragment)
                .commitNow();
        mapFragment.getMapAsync(this);
    }

    @Override
    public void onMapReady(@NonNull GoogleMap googleMap) {
        map = googleMap;
        map.getUiSettings().setZoomControlsEnabled(true);
        map.moveCamera(CameraUpdateFactory.newLatLngZoom(new LatLng(-1.2921, 36.8219), 11f));

        ServerDashboardViewModel vm = new ViewModelProvider(this).get(ServerDashboardViewModel.class);
        vm.fleet().observe(this, rows -> {
            latestRows = rows;
            scheduleFleetRender();
        });

        vm.zones().observe(this, zones -> {
            if (map == null) {
                return;
            }
            for (int i = 0; i < zoneCircles.size(); i++) {
                zoneCircles.get(i).remove();
            }
            zoneCircles.clear();
            for (int i = 0; i < zonePolygons.size(); i++) {
                zonePolygons.get(i).remove();
            }
            zonePolygons.clear();

            for (int i = 0; i < zones.size(); i++) {
                var zone = zones.get(i);
                if (zone.polygon && zone.polygonPoints != null && !zone.polygonPoints.isEmpty()) {
                    List<LatLng> points = parsePolygon(zone.polygonPoints);
                    if (points.size() >= 3) {
                        Polygon polygon = map.addPolygon(new PolygonOptions()
                                .addAll(points)
                                .strokeColor(zone.restricted ? Color.RED : Color.parseColor("#065F18"))
                                .strokeWidth(4f)
                                .fillColor(zone.restricted ? 0x33FF0000 : 0x3300AA00));
                        zonePolygons.add(polygon);
                    }
                } else {
                    Circle circle = map.addCircle(new CircleOptions()
                            .center(new LatLng(zone.centerLat, zone.centerLng))
                            .radius(zone.radiusMeters)
                            .strokeWidth(4f)
                            .strokeColor(zone.restricted ? Color.RED : Color.parseColor("#065F18"))
                            .fillColor(zone.restricted ? 0x33FF0000 : 0x3300AA00));
                    zoneCircles.add(circle);
                }
            }
        });
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        mapWorker.shutdownNow();
        mainHandler.removeCallbacksAndMessages(null);
    }

    private void scheduleFleetRender() {
        if (renderScheduled) {
            return;
        }
        renderScheduled = true;
        mainHandler.postDelayed(() -> {
            renderScheduled = false;
            mapWorker.execute(this::prepareAndRenderFleet);
        }, RENDER_DEBOUNCE_MS);
    }

    private void prepareAndRenderFleet() {
        Set<String> unique = new HashSet<>();
        List<com.bovinetrack.app.data.local.entity.LocationEntity> deduped = new ArrayList<>();
        Map<String, List<LatLng>> traces = new HashMap<>();
        List<String> summaries = new ArrayList<>();
        for (int i = 0; i < latestRows.size(); i++) {
            var row = latestRows.get(i);
            List<LatLng> path = traces.get(row.deviceId);
            if (path == null) {
                path = new ArrayList<>();
                traces.put(row.deviceId, path);
            }
            if (path.size() < 120) {
                path.add(new LatLng(row.latitude, row.longitude));
            }
            if (!unique.add(row.deviceId)) {
                continue;
            }
            deduped.add(row);
            summaries.add(row.deviceId + ": "
                    + String.format(java.util.Locale.US, "%.5f, %.5f", row.latitude, row.longitude)
                    + " speed " + String.format(java.util.Locale.US, "%.1f", row.speed) + " m/s");
        }
        synchronized (pendingAccessibleSummaries) {
            pendingAccessibleSummaries.clear();
            pendingAccessibleSummaries.addAll(summaries);
        }
        mainHandler.post(() -> renderFleet(deduped, traces));
    }

    private void renderFleet(List<com.bovinetrack.app.data.local.entity.LocationEntity> rows, Map<String, List<LatLng>> traces) {
        if (map == null) {
            return;
        }
        Set<String> seen = new HashSet<>();
        for (int i = 0; i < rows.size(); i++) {
            var row = rows.get(i);
            seen.add(row.deviceId);
            LatLng latLng = new LatLng(row.latitude, row.longitude);
            Marker marker = markerByDevice.get(row.deviceId);
            if (marker == null) {
                marker = map.addMarker(new MarkerOptions().position(latLng).title(row.deviceId));
                if (marker != null) {
                    markerByDevice.put(row.deviceId, marker);
                }
            } else {
                marker.setPosition(latLng);
            }
        }

        List<String> stale = new ArrayList<>();
        for (String deviceId : markerByDevice.keySet()) {
            if (!seen.contains(deviceId)) {
                stale.add(deviceId);
            }
        }
        for (int i = 0; i < stale.size(); i++) {
            Marker marker = markerByDevice.remove(stale.get(i));
            if (marker != null) {
                marker.remove();
            }
        }

        for (int i = 0; i < traceLines.size(); i++) {
            traceLines.get(i).remove();
        }
        traceLines.clear();
        float zoom = map.getCameraPosition().zoom;
        for (Map.Entry<String, List<LatLng>> entry : traces.entrySet()) {
            List<LatLng> path = entry.getValue();
            if (path.size() < 2) {
                continue;
            }
            List<LatLng> simplified = TraceSimplifier.simplifyByZoom(path, zoom);
            Polyline line = map.addPolyline(new PolylineOptions()
                    .addAll(simplified)
                    .width(5f)
                    .color(0xFF1565C0));
            traceLines.add(line);
        }

        mapStatus.setText("Monitoring live positions: " + rows.size() + " devices");
        renderAccessibleSummaries();
    }

    private void renderAccessibleSummaries() {
        if (accessibilityToggle == null || !accessibilityToggle.isChecked()) {
            return;
        }
        List<SimpleLineAdapter.Item> items = new ArrayList<>();
        synchronized (pendingAccessibleSummaries) {
            for (int i = 0; i < pendingAccessibleSummaries.size(); i++) {
                String summary = pendingAccessibleSummaries.get(i);
                items.add(new SimpleLineAdapter.Item("Livestock update", summary));
            }
        }
        listAdapter.submit(items);
    }

    private void applyAccessibilityMode(boolean enabled) {
        mapContainer.setVisibility(enabled ? View.GONE : View.VISIBLE);
        accessibleList.setVisibility(enabled ? View.VISIBLE : View.GONE);
    }

    private List<LatLng> parsePolygon(String raw) {
        List<LatLng> out = new ArrayList<>();
        String[] pairs = raw.split(";");
        for (String pair : pairs) {
            String[] parts = pair.trim().split(",");
            if (parts.length == 2) {
                try {
                    out.add(new LatLng(Double.parseDouble(parts[0].trim()), Double.parseDouble(parts[1].trim())));
                } catch (Exception ignored) {
                }
            }
        }
        return out;
    }
}
