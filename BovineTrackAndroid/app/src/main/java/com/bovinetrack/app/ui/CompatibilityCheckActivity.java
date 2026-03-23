package com.bovinetrack.app.ui;

import android.Manifest;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.location.LocationManager;
import android.net.ConnectivityManager;
import android.net.NetworkCapabilities;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.StatFs;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;

import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.ContextCompat;

import com.bovinetrack.app.R;
import com.bovinetrack.app.data.DevicePreferences;
import com.bovinetrack.app.model.DeviceRole;
import com.google.android.gms.common.ConnectionResult;
import com.google.android.gms.common.GoogleApiAvailability;

import java.util.ArrayList;
import java.util.List;

public class CompatibilityCheckActivity extends AppCompatActivity {
    private ProgressBar progressBar;
    private LinearLayout checkList;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_compatibility_check);

        DevicePreferences prefs = new DevicePreferences(this);
        if (prefs.isFirstLaunchDone() && prefs.getRole() != null) {
            if (prefs.getRole() == DeviceRole.SERVER) {
                startActivity(new Intent(this, com.bovinetrack.app.ui.server.ServerDashboardActivity.class));
            } else {
                startActivity(new Intent(this, com.bovinetrack.app.ui.client.ClientDashboardActivity.class));
            }
            finish();
            return;
        }

        progressBar = findViewById(R.id.checkProgress);
        checkList = findViewById(R.id.checkList);

        runChecks();
    }

    private void runChecks() {
        List<String> failures = new ArrayList<>();
        List<String> checks = new ArrayList<>();

        boolean sdk = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O;
        checks.add("Android Version: " + (sdk ? "PASS" : "FAIL"));
        if (!sdk) failures.add("Android 8.0+ is required");

        LocationManager lm = (LocationManager) getSystemService(LOCATION_SERVICE);
        boolean gps = lm != null && lm.isProviderEnabled(LocationManager.GPS_PROVIDER);
        checks.add("GPS Availability: " + (gps ? "PASS" : "FAIL"));
        if (!gps) failures.add("GPS is disabled or unavailable");

        ConnectivityManager cm = (ConnectivityManager) getSystemService(CONNECTIVITY_SERVICE);
        boolean net = false;
        if (cm != null) {
            NetworkCapabilities cap = cm.getNetworkCapabilities(cm.getActiveNetwork());
            net = cap != null && (cap.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) || cap.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR));
        }
        checks.add("Network Connectivity: " + (net ? "PASS" : "FAIL"));
        if (!net) failures.add("No active internet connection");

        int gms = GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(this);
        boolean play = gms == ConnectionResult.SUCCESS;
        checks.add("Google Play Services: " + (play ? "PASS" : "FAIL"));
        if (!play) failures.add("Google Play Services missing/outdated");

        StatFs stat = new StatFs(getFilesDir().getAbsolutePath());
        long freeMb = stat.getAvailableBytes() / (1024 * 1024);
        boolean storage = freeMb > 500;
        checks.add("Storage Capacity: " + (storage ? "PASS" : "FAIL"));
        if (!storage) failures.add("At least 500MB free storage required");

        boolean permissionReady = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED;
        checks.add("Permission Readiness: " + (permissionReady ? "PASS" : "REQUIRED"));

        for (String item : checks) {
            TextView tv = new TextView(this);
            tv.setText(item);
            tv.setTextSize(16f);
            tv.setPadding(0, 8, 0, 8);
            checkList.addView(tv);
        }

        progressBar.setProgress(100);
        new Handler(Looper.getMainLooper()).postDelayed(() -> {
            if (failures.isEmpty()) {
                startActivity(new Intent(this, OnboardingActivity.class));
            } else {
                Intent intent = new Intent(this, IncompatibleActivity.class);
                intent.putStringArrayListExtra("failures", new ArrayList<>(failures));
                startActivity(intent);
            }
            finish();
        }, 1300);
    }
}
