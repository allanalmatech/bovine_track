package com.bovinetrack.app.ui.client;

import android.app.Application;

import androidx.annotation.NonNull;
import androidx.lifecycle.AndroidViewModel;
import androidx.lifecycle.LiveData;

import com.bovinetrack.app.data.LocationRepository;
import com.bovinetrack.app.data.local.entity.LocationEntity;

import java.util.List;

public class ClientTrackingViewModel extends AndroidViewModel {
    private final LocationRepository repository;

    public ClientTrackingViewModel(@NonNull Application application) {
        super(application);
        repository = LocationRepository.get(application);
    }

    public LiveData<LocationEntity> latest() {
        return repository.observeLatestSelf();
    }

    public LiveData<List<LocationEntity>> history() {
        return repository.observeRecentSelf();
    }
}
