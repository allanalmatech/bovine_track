package com.bovinetrack.app.ui.server;

import android.os.Bundle;

import androidx.appcompat.app.AppCompatActivity;
import androidx.lifecycle.ViewModelProvider;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.bovinetrack.app.R;
import com.bovinetrack.app.ui.common.SimpleLineAdapter;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;

public class AlertsActivity extends AppCompatActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_alerts);

        RecyclerView recycler = findViewById(R.id.alertsRecycler);
        recycler.setLayoutManager(new LinearLayoutManager(this));
        SimpleLineAdapter adapter = new SimpleLineAdapter();
        recycler.setAdapter(adapter);

        ServerDashboardViewModel vm = new ViewModelProvider(this).get(ServerDashboardViewModel.class);
        vm.alerts().observe(this, alerts -> {
            List<SimpleLineAdapter.Item> rows = new ArrayList<>();
            SimpleDateFormat fmt = new SimpleDateFormat("MMM dd HH:mm:ss", Locale.US);
            for (int i = 0; i < alerts.size(); i++) {
                var alert = alerts.get(i);
                String title = alert.type + " - " + alert.message;
                String subtitle = alert.deviceId + " | " + fmt.format(new Date(alert.timestamp));
                rows.add(new SimpleLineAdapter.Item(title, subtitle));
            }
            adapter.submit(rows);
        });
    }
}
