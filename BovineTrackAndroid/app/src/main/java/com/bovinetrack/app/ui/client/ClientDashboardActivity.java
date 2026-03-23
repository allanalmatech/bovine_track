package com.bovinetrack.app.ui.client;

import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.text.format.DateFormat;
import android.widget.TextView;

import androidx.appcompat.app.AppCompatActivity;
import androidx.lifecycle.ViewModelProvider;

import com.bovinetrack.app.R;
import com.bovinetrack.app.service.TrackingService;
import com.bovinetrack.app.ui.settings.SettingsActivity;
import com.google.android.material.button.MaterialButton;
import com.google.android.material.switchmaterial.SwitchMaterial;

import java.util.Locale;

public class ClientDashboardActivity extends AppCompatActivity {
    private SwitchMaterial trackingSwitch;
    private SwitchMaterial simulationSwitch;
    private TextView locationLabel;
    private TextView statusLabel;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_client_dashboard);

        trackingSwitch = findViewById(R.id.trackingSwitch);
        simulationSwitch = findViewById(R.id.simulationSwitch);
        locationLabel = findViewById(R.id.locationLabel);
        statusLabel = findViewById(R.id.statusLabel);
        MaterialButton logButton = findViewById(R.id.logButton);
        MaterialButton settingsButton = findViewById(R.id.settingsButton);

        ClientTrackingViewModel vm = new ViewModelProvider(this).get(ClientTrackingViewModel.class);
        vm.latest().observe(this, location -> {
            if (location != null) {
                String t = DateFormat.format("yyyy-MM-dd HH:mm:ss", location.timestamp).toString();
                locationLabel.setText(String.format(Locale.US, "%.5f, %.5f | %.1f m/s | %s", location.latitude, location.longitude, location.speed, t));
                statusLabel.setText(location.simulated ? "Simulation Active" : "Live GPS Active");
            }
        });

        trackingSwitch.setOnCheckedChangeListener((buttonView, isChecked) -> {
            if (isChecked) {
                startTracking(simulationSwitch.isChecked());
            } else {
                stopService(new Intent(this, TrackingService.class));
                statusLabel.setText("Service Stopped");
            }
        });

        logButton.setOnClickListener(v -> startActivity(new Intent(this, ClientActivityLogActivity.class)));
        settingsButton.setOnClickListener(v -> startActivity(new Intent(this, SettingsActivity.class)));
    }

    private void startTracking(boolean simulation) {
        Intent intent = new Intent(this, TrackingService.class);
        intent.putExtra(TrackingService.EXTRA_SIMULATION, simulation);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent);
        } else {
            startService(intent);
        }
    }
}
