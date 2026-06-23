package io.mateshell;

import android.content.Intent;
import android.os.Bundle;
import android.widget.Button;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

public class SetupActivity extends AppCompatActivity {

    private ProgressBar progress;
    private TextView log;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_setup);

        progress = findViewById(R.id.progress);
        log = findViewById(R.id.logText);

        append("MatePad 11 · MateShell Setup\n\n");
        append("1. Установите Termux (кнопка ниже откроет установщик)\n");
        append("2. В Termux: Allow external apps\n");
        append("3. Нажмите «Установить Linux» (~2 GB, Wi-Fi)\n\n");

        findViewById(R.id.btnInstallTermux).setOnClickListener(v -> TermuxHelper.openTermuxDirectApk(this));

        findViewById(R.id.btnInstallLinux).setOnClickListener(v -> {
            if (!TermuxHelper.isTermuxInstalled(this)) {
                Toast.makeText(this, "Сначала Termux", Toast.LENGTH_LONG).show();
                return;
            }
            progress.setVisibility(android.view.View.VISIBLE);
            append("Установка Debian + XFCE + VNC + VS Code...\n");
            append("Следите в Termux: tail -f ~/mate-shell/install.log\n");
            TermuxHelper.pushAndInstall(this);
            MateApp.get().setLinuxInstalled(true);
            Toast.makeText(this, "Установка запущена в Termux (10–30 мин)", Toast.LENGTH_LONG).show();
            progress.setVisibility(android.view.View.GONE);
        });

        findViewById(R.id.btnOpenTermux).setOnClickListener(v -> {
            Intent i = getPackageManager().getLaunchIntentForPackage("com.termux");
            if (i != null) startActivity(i);
        });

        findViewById(R.id.btnDone).setOnClickListener(v -> finish());
    }

    private void append(String s) {
        log.append(s);
    }
}
