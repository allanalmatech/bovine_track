package com.bovinetrack.app.ui.server;

import android.os.Bundle;
import android.text.TextUtils;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;

import com.bovinetrack.app.R;
import com.bovinetrack.app.data.LocationRepository;
import com.bovinetrack.app.data.PolygonValidator;
import com.bovinetrack.app.data.local.entity.GeofenceZoneEntity;
import com.google.android.gms.maps.CameraUpdateFactory;
import com.google.android.gms.maps.GoogleMap;
import com.google.android.gms.maps.OnMapReadyCallback;
import com.google.android.gms.maps.SupportMapFragment;
import com.google.android.gms.maps.model.LatLng;
import com.google.android.gms.maps.model.MarkerOptions;
import com.google.android.gms.maps.model.Polygon;
import com.google.android.gms.maps.model.PolygonOptions;
import com.google.android.material.button.MaterialButton;

import java.util.ArrayList;
import java.util.List;

public class GeofenceEditorActivity extends AppCompatActivity implements OnMapReadyCallback {
    private final List<LatLng> vertices = new ArrayList<>();
    private GoogleMap map;
    private Polygon draftPolygon;
    private EditText polygonPointsInput;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_geofence_editor);

        EditText nameInput = findViewById(R.id.nameInput);
        EditText latInput = findViewById(R.id.latInput);
        EditText lngInput = findViewById(R.id.lngInput);
        EditText radiusInput = findViewById(R.id.radiusInput);
        CheckBox polygonCheck = findViewById(R.id.polygonCheck);
        polygonPointsInput = findViewById(R.id.polygonPointsInput);
        CheckBox restrictedCheck = findViewById(R.id.restrictedCheck);
        MaterialButton clearPolygonButton = findViewById(R.id.clearPolygonButton);
        MaterialButton saveButton = findViewById(R.id.saveButton);

        SupportMapFragment mapFragment = (SupportMapFragment) getSupportFragmentManager().findFragmentById(R.id.editorMap);
        if (mapFragment != null) {
            mapFragment.getMapAsync(this);
        }

        clearPolygonButton.setOnClickListener(v -> {
            vertices.clear();
            redrawPolygon();
            polygonPointsInput.setText("");
        });

        saveButton.setOnClickListener(v -> {
            try {
                GeofenceZoneEntity zone = new GeofenceZoneEntity();
                zone.name = nameInput.getText().toString().trim();
                zone.centerLat = Double.parseDouble(latInput.getText().toString().trim());
                zone.centerLng = Double.parseDouble(lngInput.getText().toString().trim());
                zone.radiusMeters = Float.parseFloat(radiusInput.getText().toString().trim());
                zone.polygon = polygonCheck.isChecked();
                String polygonPoints = polygonPointsInput.getText().toString().trim();
                if (zone.polygon) {
                    if (vertices.size() >= 3) {
                        polygonPoints = serializeVertices(vertices);
                        polygonPointsInput.setText(polygonPoints);
                    }
                    if (TextUtils.isEmpty(polygonPoints)) {
                        Toast.makeText(this, "Add at least 3 polygon points", Toast.LENGTH_SHORT).show();
                        return;
                    }
                    List<LatLng> points = parseVertices(polygonPoints);
                    if (points.size() < 3) {
                        Toast.makeText(this, "Polygon needs at least 3 valid points", Toast.LENGTH_SHORT).show();
                        return;
                    }
                    if (PolygonValidator.isSelfIntersecting(points)) {
                        Toast.makeText(this, "Invalid polygon: edges intersect", Toast.LENGTH_LONG).show();
                        return;
                    }
                }
                zone.polygonPoints = polygonPoints;
                zone.restricted = restrictedCheck.isChecked();

                LocationRepository.get(this).saveZone(zone);
                Toast.makeText(this, "Geofence saved", Toast.LENGTH_SHORT).show();
                finish();
            } catch (Exception ex) {
                Toast.makeText(this, "Please provide valid values", Toast.LENGTH_SHORT).show();
            }
        });
    }

    @Override
    public void onMapReady(@NonNull GoogleMap googleMap) {
        map = googleMap;
        map.moveCamera(CameraUpdateFactory.newLatLngZoom(new LatLng(-1.2921, 36.8219), 12f));
        map.getUiSettings().setZoomControlsEnabled(true);
        map.setOnMapClickListener(point -> {
            vertices.add(point);
            redrawPolygon();
            polygonPointsInput.setText(serializeVertices(vertices));
        });
    }

    private void redrawPolygon() {
        if (map == null) {
            return;
        }
        map.clear();
        for (int i = 0; i < vertices.size(); i++) {
            map.addMarker(new MarkerOptions().position(vertices.get(i)).title("P" + (i + 1)));
        }
        if (draftPolygon != null) {
            draftPolygon.remove();
        }
        if (vertices.size() >= 3) {
            draftPolygon = map.addPolygon(new PolygonOptions()
                    .addAll(vertices)
                    .strokeColor(0xFF2E7D32)
                    .fillColor(0x332E7D32)
                    .strokeWidth(4f));
        }
    }

    private String serializeVertices(List<LatLng> points) {
        StringBuilder builder = new StringBuilder();
        for (int i = 0; i < points.size(); i++) {
            LatLng point = points.get(i);
            if (i > 0) {
                builder.append(';');
            }
            builder.append(point.latitude).append(',').append(point.longitude);
        }
        return builder.toString();
    }

    private List<LatLng> parseVertices(String raw) {
        List<LatLng> out = new ArrayList<>();
        String[] pairs = raw.split(";");
        for (String pair : pairs) {
            String[] parts = pair.trim().split(",");
            if (parts.length != 2) {
                continue;
            }
            try {
                out.add(new LatLng(Double.parseDouble(parts[0].trim()), Double.parseDouble(parts[1].trim())));
            } catch (Exception ignored) {
            }
        }
        return out;
    }
}
