package com.gesture.overlay;

import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.widget.Button;
import android.widget.TextView;
import androidx.appcompat.app.AppCompatActivity;

public class MainActivity extends AppCompatActivity {

    Button btnToggle, btnAccessibility;
    TextView tvStatus;
    boolean running = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        btnToggle        = findViewById(R.id.btn_toggle);
        btnAccessibility = findViewById(R.id.btn_accessibility);
        tvStatus         = findViewById(R.id.tv_status);

        btnToggle.setOnClickListener(v -> {
            if (!running) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
                        && !Settings.canDrawOverlays(this)) {
                    Intent i = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:" + getPackageName()));
                    startActivity(i);
                    return;
                }
                startService(new Intent(this, OverlayService.class));
                running = true;
                btnToggle.setText("ВИМКНУТИ");
                tvStatus.setText("Працює");
                tvStatus.setTextColor(0xFF00FFCC);
            } else {
                stopService(new Intent(this, OverlayService.class));
                running = false;
                btnToggle.setText("УВІМКНУТИ");
                tvStatus.setText("Вимкнено");
                tvStatus.setTextColor(0xFF304050);
            }
        });

        btnAccessibility.setOnClickListener(v ->
            startActivity(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)));
    }
}
