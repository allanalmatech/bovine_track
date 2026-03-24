package com.bovinetrack.app.ui.client;

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

public class ClientActivityLogActivity extends AppCompatActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_client_log);

        RecyclerView recycler = findViewById(R.id.logRecycler);
        recycler.setLayoutManager(new LinearLayoutManager(this));
        SimpleLineAdapter adapter = new SimpleLineAdapter();
        recycler.setAdapter(adapter);

        ClientTrackingViewModel vm = new ViewModelProvider(this).get(ClientTrackingViewModel.class);
        vm.history().observe(this, rows -> {
            List<SimpleLineAdapter.Item> items = new ArrayList<>();
            SimpleDateFormat fmt = new SimpleDateFormat("MMM dd HH:mm:ss", Locale.US);
            for (int i = 0; i < rows.size(); i++) {
                var row = rows.get(i);
                String title = String.format(Locale.US, "%.5f, %.5f", row.latitude, row.longitude);
                String subtitle = fmt.format(new Date(row.timestamp)) + " | " + (row.simulated ? "SIM" : "GPS") + " | " + row.speed + "m/s";
                items.add(new SimpleLineAdapter.Item(title, subtitle));
            }
            adapter.submit(items);
        });
    }
}
