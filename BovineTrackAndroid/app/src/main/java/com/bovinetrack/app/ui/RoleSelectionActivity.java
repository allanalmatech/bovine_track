package com.bovinetrack.app.ui;

import android.Manifest;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.ContextCompat;

import com.bovinetrack.app.R;
import com.bovinetrack.app.data.DevicePreferences;
import com.bovinetrack.app.model.DeviceRole;
import com.bovinetrack.app.ui.client.ClientDashboardActivity;
import com.bovinetrack.app.ui.server.ServerDashboardActivity;

public class RoleSelectionActivity extends AppCompatActivity {
    private DevicePreferences prefs;

    private final ActivityResultLauncher<String[]> permissionLauncher = registerForActivityResult(
            new ActivityResultContracts.RequestMultiplePermissions(),
            result -> {}
    );

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_role_selection);
        prefs = new DevicePreferences(this);

        findViewById(R.id.serverCard).setOnClickListener(v -> chooseRole(DeviceRole.SERVER));
        findViewById(R.id.clientCard).setOnClickListener(v -> chooseRole(DeviceRole.CLIENT));
        askPermissionsIfNeeded();
    }

    private void askPermissionsIfNeeded() {
        boolean fine = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED;
        boolean notif = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU
                || ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED;

        if (!fine || !notif) {
            permissionLauncher.launch(new String[]{
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                    Manifest.permission.POST_NOTIFICATIONS
            });
        }
    }

    private void chooseRole(DeviceRole role) {
        prefs.saveRole(role);
        prefs.setFirstLaunchDone(true);
        if (role == DeviceRole.SERVER) {
            startActivity(new Intent(this, ServerDashboardActivity.class));
        } else {
            startActivity(new Intent(this, ClientDashboardActivity.class));
        }
        finish();
    }
}
