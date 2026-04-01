package com.bovinetrack.app.ui.client;

import android.Manifest;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;
import android.text.format.DateFormat;
import android.widget.Toast;
import android.widget.TextView;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.ContextCompat;
import androidx.lifecycle.ViewModelProvider;

import com.bovinetrack.app.R;
import com.bovinetrack.app.data.DevicePreferences;
import com.bovinetrack.app.data.LocationRepository;
import com.bovinetrack.app.service.TrackingService;
import com.bovinetrack.app.ui.settings.SettingsActivity;
import com.google.android.material.button.MaterialButton;
import com.google.android.material.switchmaterial.SwitchMaterial;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

public class ClientDashboardActivity extends AppCompatActivity {
    private SwitchMaterial trackingSwitch;
    private SwitchMaterial simulationSwitch;
    private TextView locationLabel;
    private TextView statusLabel;
    private DevicePreferences preferences;
    private ActivityResultLauncher<String[]> permissionLauncher;
    private boolean pendingTrackingStart;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_client_dashboard);
        preferences = new DevicePreferences(this);

        trackingSwitch = findViewById(R.id.trackingSwitch);
        simulationSwitch = findViewById(R.id.simulationSwitch);
        locationLabel = findViewById(R.id.locationLabel);
        statusLabel = findViewById(R.id.statusLabel);
        MaterialButton logButton = findViewById(R.id.logButton);
        MaterialButton settingsButton = findViewById(R.id.settingsButton);

        permissionLauncher = registerForActivityResult(new ActivityResultContracts.RequestMultiplePermissions(), result -> {
            if (!pendingTrackingStart) {
                return;
            }
            pendingTrackingStart = false;
            if (hasRequiredPermissions()) {
                startTracking(simulationSwitch.isChecked());
            } else {
                trackingSwitch.setChecked(false);
                statusLabel.setText("Permissions denied");
                Toast.makeText(this, "Location permissions are required", Toast.LENGTH_SHORT).show();
            }
        });

        trackingSwitch.setChecked(preferences.isTrackingEnabled());
        if (preferences.isTrackingEnabled()) {
            statusLabel.setText("Tracking service requested");
        }

        ClientTrackingViewModel vm = new ViewModelProvider(this).get(ClientTrackingViewModel.class);
        LocationRepository.get(this).syncMessagingToken();
        vm.latest().observe(this, location -> {
            if (location != null) {
                String t = DateFormat.format("yyyy-MM-dd HH:mm:ss", location.timestamp).toString();
                locationLabel.setText(String.format(Locale.US, "%.5f, %.5f | %.1f m/s | %s", location.latitude, location.longitude, location.speed, t));
                statusLabel.setText(location.simulated ? "Simulation Active" : "Live GPS Active");
            }
        });

        trackingSwitch.setOnCheckedChangeListener((buttonView, isChecked) -> {
            if (isChecked) {
                if (hasRequiredPermissions()) {
                    startTracking(simulationSwitch.isChecked());
                } else {
                    pendingTrackingStart = true;
                    permissionLauncher.launch(requiredPermissions());
                }
            } else {
                stopService(new Intent(this, TrackingService.class));
                preferences.setTrackingEnabled(false);
                statusLabel.setText("Service Stopped");
            }
        });

        logButton.setOnClickListener(v -> startActivity(new Intent(this, ClientActivityLogActivity.class)));
        settingsButton.setOnClickListener(v -> startActivity(new Intent(this, SettingsActivity.class)));
    }

    private void startTracking(boolean simulation) {
        preferences.setTrackingEnabled(true);
        Intent intent = new Intent(this, TrackingService.class);
        intent.putExtra(TrackingService.EXTRA_SIMULATION, simulation);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent);
        } else {
            startService(intent);
        }
    }

    private String[] requiredPermissions() {
        List<String> permissions = new ArrayList<>();
        permissions.add(Manifest.permission.ACCESS_FINE_LOCATION);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            permissions.add(Manifest.permission.ACCESS_BACKGROUND_LOCATION);
            permissions.add(Manifest.permission.ACTIVITY_RECOGNITION);
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions.add(Manifest.permission.POST_NOTIFICATIONS);
        }
        return permissions.toArray(new String[0]);
    }

    private boolean hasRequiredPermissions() {
        String[] perms = requiredPermissions();
        for (String permission : perms) {
            if (ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED) {
                return false;
            }
        }
        return true;
    }
}
