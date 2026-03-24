package com.bovinetrack.app.ui.settings;

import android.os.Bundle;
import android.widget.EditText;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import com.bovinetrack.app.R;
import com.bovinetrack.app.data.DevicePreferences;
import com.google.android.material.button.MaterialButton;

public class SettingsActivity extends AppCompatActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_settings);

        DevicePreferences prefs = new DevicePreferences(this);

        EditText deviceIdInput = findViewById(R.id.deviceIdInput);
        EditText firebaseUrlInput = findViewById(R.id.firebasePathInput);
        MaterialButton saveButton = findViewById(R.id.saveSettingsButton);

        deviceIdInput.setText(prefs.getDeviceId());
        firebaseUrlInput.setText(prefs.getFirebaseUrl());

        saveButton.setOnClickListener(v -> {
            prefs.setDeviceId(deviceIdInput.getText().toString());
            prefs.setFirebaseUrl(firebaseUrlInput.getText().toString());
            Toast.makeText(this, "Settings saved", Toast.LENGTH_SHORT).show();
            finish();
        });
    }
}
