package com.bovinetrack.app.ui;

import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.TextView;

import androidx.appcompat.app.AppCompatActivity;

import com.bovinetrack.app.R;
import com.google.android.material.button.MaterialButton;

public class OnboardingActivity extends AppCompatActivity {
    private int index = 0;
    private TextView title;
    private TextView body;
    private View dot1;
    private View dot2;
    private View dot3;

    private final String[] titles = {
            "Track from anywhere",
            "Draw digital boundaries",
            "Respond to live alerts"
    };

    private final String[] bodies = {
            "Monitor herd movement in real time, even in remote grazing sectors.",
            "Set safe and restricted zones to prevent livestock theft and accidental entry.",
            "Receive immediate breach, inactivity, and low-battery alerts."
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_onboarding);

        title = findViewById(R.id.slideTitle);
        body = findViewById(R.id.slideBody);
        dot1 = findViewById(R.id.dot1);
        dot2 = findViewById(R.id.dot2);
        dot3 = findViewById(R.id.dot3);

        MaterialButton next = findViewById(R.id.nextButton);
        MaterialButton skip = findViewById(R.id.skipButton);

        render();
        next.setOnClickListener(v -> {
            if (index < 2) {
                index++;
                render();
            } else {
                startRoleSelection();
            }
        });
        skip.setOnClickListener(v -> startRoleSelection());
    }

    private void render() {
        title.setText(titles[index]);
        body.setText(bodies[index]);
        dot1.setAlpha(index == 0 ? 1f : 0.4f);
        dot2.setAlpha(index == 1 ? 1f : 0.4f);
        dot3.setAlpha(index == 2 ? 1f : 0.4f);
    }

    private void startRoleSelection() {
        startActivity(new Intent(this, RoleSelectionActivity.class));
        finish();
    }
}
