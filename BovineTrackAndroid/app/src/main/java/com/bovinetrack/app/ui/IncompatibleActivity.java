package com.bovinetrack.app.ui;

import android.os.Bundle;
import android.widget.TextView;

import androidx.appcompat.app.AppCompatActivity;

import com.bovinetrack.app.R;
import com.google.android.material.button.MaterialButton;

import java.util.ArrayList;

public class IncompatibleActivity extends AppCompatActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_incompatible);

        TextView reasons = findViewById(R.id.reasonText);
        MaterialButton exit = findViewById(R.id.exitButton);

        ArrayList<String> failures = getIntent().getStringArrayListExtra("failures");
        if (failures == null || failures.isEmpty()) {
            reasons.setText("Device did not pass compatibility checks.");
        } else {
            StringBuilder message = new StringBuilder();
            for (String failure : failures) {
                message.append("- ").append(failure).append("\n");
            }
            reasons.setText(message.toString());
        }

        exit.setOnClickListener(v -> finishAffinity());
    }
}
