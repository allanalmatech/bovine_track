package com.bovinetrack.app.ui.server;

import android.graphics.Color;
import android.os.Bundle;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.lifecycle.ViewModelProvider;

import com.bovinetrack.app.R;
import com.google.android.gms.maps.CameraUpdateFactory;
import com.google.android.gms.maps.GoogleMap;
import com.google.android.gms.maps.OnMapReadyCallback;
import com.google.android.gms.maps.SupportMapFragment;
import com.google.android.gms.maps.model.CircleOptions;
import com.google.android.gms.maps.model.LatLng;
import com.google.android.gms.maps.model.MarkerOptions;
import com.google.android.gms.maps.model.PolygonOptions;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

public class LiveMapActivity extends AppCompatActivity implements OnMapReadyCallback {
    private GoogleMap map;
    private TextView mapStatus;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_live_map);
        mapStatus = findViewById(R.id.mapStatus);

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
            if (map == null) {
                return;
            }
            map.clear();
            Set<String> unique = new HashSet<>();
            int plotted = 0;
            for (int i = 0; i < rows.size(); i++) {
                var row = rows.get(i);
                if (unique.add(row.deviceId)) {
                    LatLng latLng = new LatLng(row.latitude, row.longitude);
                    map.addMarker(new MarkerOptions().position(latLng).title(row.deviceId));
                    plotted++;
                }
            }
            mapStatus.setText("Monitoring live positions: " + plotted + " devices");
        });

        vm.zones().observe(this, zones -> {
            if (map == null) {
                return;
            }
            for (int i = 0; i < zones.size(); i++) {
                var zone = zones.get(i);
                if (zone.polygon && zone.polygonPoints != null && !zone.polygonPoints.isEmpty()) {
                    List<LatLng> points = parsePolygon(zone.polygonPoints);
                    if (points.size() >= 3) {
                        map.addPolygon(new PolygonOptions()
                                .addAll(points)
                                .strokeColor(zone.restricted ? Color.RED : Color.parseColor("#065F18"))
                                .strokeWidth(4f)
                                .fillColor(zone.restricted ? 0x33FF0000 : 0x3300AA00));
                    }
                } else {
                    map.addCircle(new CircleOptions()
                            .center(new LatLng(zone.centerLat, zone.centerLng))
                            .radius(zone.radiusMeters)
                            .strokeWidth(4f)
                            .strokeColor(zone.restricted ? Color.RED : Color.parseColor("#065F18"))
                            .fillColor(zone.restricted ? 0x33FF0000 : 0x3300AA00));
                }
            }
        });
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
