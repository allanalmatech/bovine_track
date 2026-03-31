package com.bovinetrack.app.ui.client;

import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;

import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.DividerItemDecoration;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.bovinetrack.app.R;
import com.bovinetrack.app.data.DevicePreferences;
import com.bovinetrack.app.data.LocationRepository;
import com.bovinetrack.app.data.local.entity.LocationEntity;
import com.bovinetrack.app.ui.common.SimpleLineAdapter;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;

public class ClientActivityLogActivity extends AppCompatActivity {
    private static final int PAGE_SIZE = 200;

    private final List<LocationEntity> loadedRows = new ArrayList<>();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private SimpleLineAdapter adapter;
    private String deviceId;
    private long cursorTimestamp = Long.MAX_VALUE;
    private boolean loading;
    private boolean endReached;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_client_log);
        deviceId = new DevicePreferences(this).getDeviceId();

        RecyclerView recycler = findViewById(R.id.logRecycler);
        LinearLayoutManager layoutManager = new LinearLayoutManager(this);
        recycler.setLayoutManager(layoutManager);
        recycler.addItemDecoration(new DividerItemDecoration(this, DividerItemDecoration.VERTICAL));
        adapter = new SimpleLineAdapter();
        recycler.setAdapter(adapter);
        recycler.addOnScrollListener(new RecyclerView.OnScrollListener() {
            @Override
            public void onScrolled(RecyclerView rv, int dx, int dy) {
                super.onScrolled(rv, dx, dy);
                if (dy <= 0 || loading || endReached) {
                    return;
                }
                int lastVisible = layoutManager.findLastVisibleItemPosition();
                if (lastVisible >= Math.max(0, adapter.getItemCount() - 25)) {
                    loadNextPage();
                }
            }
        });

        loadNextPage();
    }

    private void loadNextPage() {
        loading = true;
        LocationRepository.get(this).loadHistoryPage(deviceId, cursorTimestamp, PAGE_SIZE, page -> {
            mainHandler.post(() -> {
                loading = false;
                if (page.isEmpty()) {
                    endReached = true;
                    return;
                }
                loadedRows.addAll(page);
                cursorTimestamp = page.get(page.size() - 1).timestamp;
                if (page.size() < PAGE_SIZE) {
                    endReached = true;
                }
                bindRows();
            });
        });
    }

    private void bindRows() {
            List<SimpleLineAdapter.Item> items = new ArrayList<>();
            SimpleDateFormat fmt = new SimpleDateFormat("MMM dd HH:mm:ss", Locale.US);
            for (int i = 0; i < loadedRows.size(); i++) {
                var row = loadedRows.get(i);
                String title = String.format(Locale.US, "%.5f, %.5f", row.latitude, row.longitude);
                String subtitle = fmt.format(new Date(row.timestamp)) + " | " + (row.simulated ? "SIM" : "GPS") + " | " + row.speed + "m/s";
                items.add(new SimpleLineAdapter.Item(title, subtitle));
            }
            adapter.submit(items);
    }
}
