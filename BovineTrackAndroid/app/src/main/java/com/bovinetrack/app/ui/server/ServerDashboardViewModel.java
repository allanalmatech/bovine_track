package com.bovinetrack.app.ui.server;

import android.app.Application;

import androidx.annotation.NonNull;
import androidx.lifecycle.AndroidViewModel;
import androidx.lifecycle.LiveData;

import com.bovinetrack.app.data.LocationRepository;
import com.bovinetrack.app.data.local.entity.AlertEntity;
import com.bovinetrack.app.data.local.entity.GeofenceZoneEntity;
import com.bovinetrack.app.data.local.entity.LocationEntity;

import java.util.List;

public class ServerDashboardViewModel extends AndroidViewModel {
    private final LocationRepository repository;

    public ServerDashboardViewModel(@NonNull Application application) {
        super(application);
        repository = LocationRepository.get(application);
    }

    public LiveData<List<LocationEntity>> fleet() {
        return repository.observeRecentFleet();
    }

    public LiveData<Integer> alertsCount() {
        return repository.observeAlertCountToday();
    }

    public LiveData<List<AlertEntity>> alerts() {
        return repository.observeAlerts();
    }

    public LiveData<List<GeofenceZoneEntity>> zones() {
        return repository.observeZones();
    }
}
