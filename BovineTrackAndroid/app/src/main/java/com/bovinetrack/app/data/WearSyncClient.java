package com.bovinetrack.app.data;

import android.content.Context;

import com.google.android.gms.tasks.Tasks;
import com.google.android.gms.wearable.DataClient;
import com.google.android.gms.wearable.PutDataMapRequest;
import com.google.android.gms.wearable.PutDataRequest;
import com.google.android.gms.wearable.Wearable;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

public class WearSyncClient {
    private final DataClient dataClient;
    private final ExecutorService io = Executors.newSingleThreadExecutor();

    public WearSyncClient(Context context) {
        dataClient = Wearable.getDataClient(context.getApplicationContext());
    }

    public void publishLatestLocation(String deviceId, double lat, double lng, long timestamp, int battery) {
        io.execute(() -> {
            try {
                PutDataMapRequest mapRequest = PutDataMapRequest.create("/bovinetrack/latest");
                mapRequest.getDataMap().putString("deviceId", deviceId);
                mapRequest.getDataMap().putDouble("lat", lat);
                mapRequest.getDataMap().putDouble("lng", lng);
                mapRequest.getDataMap().putLong("timestamp", timestamp);
                mapRequest.getDataMap().putInt("battery", battery);
                mapRequest.getDataMap().putLong("nonce", System.currentTimeMillis());
                PutDataRequest request = mapRequest.asPutDataRequest().setUrgent();
                Tasks.await(dataClient.putDataItem(request), 2, TimeUnit.SECONDS);
            } catch (Exception ignored) {
            }
        });
    }
}
