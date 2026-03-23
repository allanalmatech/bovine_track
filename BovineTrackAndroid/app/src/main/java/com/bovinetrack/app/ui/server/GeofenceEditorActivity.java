package com.bovinetrack.app.ui.server;

import android.os.Bundle;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import com.bovinetrack.app.R;
import com.bovinetrack.app.data.LocationRepository;
import com.bovinetrack.app.data.local.entity.GeofenceZoneEntity;
import com.google.android.material.button.MaterialButton;

public class GeofenceEditorActivity extends AppCompatActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_geofence_editor);

        EditText nameInput = findViewById(R.id.nameInput);
        EditText latInput = findViewById(R.id.latInput);
        EditText lngInput = findViewById(R.id.lngInput);
        EditText radiusInput = findViewById(R.id.radiusInput);
        CheckBox polygonCheck = findViewById(R.id.polygonCheck);
        EditText polygonPointsInput = findViewById(R.id.polygonPointsInput);
        CheckBox restrictedCheck = findViewById(R.id.restrictedCheck);
        MaterialButton saveButton = findViewById(R.id.saveButton);

        saveButton.setOnClickListener(v -> {
            try {
                GeofenceZoneEntity zone = new GeofenceZoneEntity();
                zone.name = nameInput.getText().toString().trim();
                zone.centerLat = Double.parseDouble(latInput.getText().toString().trim());
                zone.centerLng = Double.parseDouble(lngInput.getText().toString().trim());
                zone.radiusMeters = Float.parseFloat(radiusInput.getText().toString().trim());
                zone.polygon = polygonCheck.isChecked();
                zone.polygonPoints = polygonPointsInput.getText().toString().trim();
                zone.restricted = restrictedCheck.isChecked();

                LocationRepository.get(this).saveZone(zone);
                Toast.makeText(this, "Geofence saved", Toast.LENGTH_SHORT).show();
                finish();
            } catch (Exception ex) {
                Toast.makeText(this, "Please provide valid values", Toast.LENGTH_SHORT).show();
            }
        });
    }
}
