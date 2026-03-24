package com.bovinetrack.app.ui.server;

import android.content.Intent;
import android.os.Bundle;
import android.widget.TextView;

import androidx.appcompat.app.AppCompatActivity;
import androidx.lifecycle.ViewModelProvider;

import com.bovinetrack.app.R;
import com.bovinetrack.app.ui.settings.SettingsActivity;

import java.util.HashSet;
import java.util.Set;

public class ServerDashboardActivity extends AppCompatActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_server_dashboard);

        TextView connected = findViewById(R.id.connectedDevicesLabel);
        TextView activeAlerts = findViewById(R.id.activeAlertsLabel);

        findViewById(R.id.liveMapButton).setOnClickListener(v -> startActivity(new Intent(this, LiveMapActivity.class)));
        findViewById(R.id.geofenceButton).setOnClickListener(v -> startActivity(new Intent(this, GeofenceEditorActivity.class)));
        findViewById(R.id.alertsButton).setOnClickListener(v -> startActivity(new Intent(this, AlertsActivity.class)));
        findViewById(R.id.settingsButton).setOnClickListener(v -> startActivity(new Intent(this, SettingsActivity.class)));

        ServerDashboardViewModel vm = new ViewModelProvider(this).get(ServerDashboardViewModel.class);
        vm.fleet().observe(this, rows -> {
            Set<String> ids = new HashSet<>();
            for (int i = 0; i < rows.size(); i++) {
                ids.add(rows.get(i).deviceId);
            }
            connected.setText("Connected Devices: " + ids.size());
        });
        vm.alertsCount().observe(this, count -> activeAlerts.setText("Active Alerts: " + (count == null ? 0 : count)));
    }
}
