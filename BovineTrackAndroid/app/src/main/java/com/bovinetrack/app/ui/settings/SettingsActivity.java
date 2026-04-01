package com.bovinetrack.app.ui.settings;

import android.os.Bundle;
import android.widget.EditText;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import com.bovinetrack.app.R;
import com.bovinetrack.app.data.DevicePreferences;
import com.google.android.material.button.MaterialButton;
import com.google.android.material.switchmaterial.SwitchMaterial;

public class SettingsActivity extends AppCompatActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_settings);

        DevicePreferences prefs = new DevicePreferences(this);

        EditText deviceIdInput = findViewById(R.id.deviceIdInput);
        EditText firebaseUrlInput = findViewById(R.id.firebasePathInput);
        SwitchMaterial accessibilitySwitch = findViewById(R.id.accessibilityModeSwitch);
        MaterialButton saveButton = findViewById(R.id.saveSettingsButton);

        deviceIdInput.setText(prefs.getDeviceId());
        firebaseUrlInput.setText(prefs.getFirebaseUrl());
        accessibilitySwitch.setChecked(prefs.isAccessibilityModeEnabled());

        saveButton.setOnClickListener(v -> {
            prefs.setDeviceId(deviceIdInput.getText().toString());
            prefs.setFirebaseUrl(firebaseUrlInput.getText().toString());
            prefs.setAccessibilityModeEnabled(accessibilitySwitch.isChecked());
            Toast.makeText(this, "Settings saved", Toast.LENGTH_SHORT).show();
            finish();
        });
    }
}
