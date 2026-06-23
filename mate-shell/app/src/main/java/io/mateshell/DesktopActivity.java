package io.mateshell;

import android.Manifest;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.os.Build;
import android.os.Bundle;
import android.widget.TextView;
import android.widget.Toast;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.ContextCompat;
import androidx.recyclerview.widget.GridLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;

public class DesktopActivity extends AppCompatActivity {

    private TextView clock;
    private TextView statusText;

    private final ActivityResultLauncher<String> notificationPermission =
            registerForActivityResult(new ActivityResultContracts.RequestPermission(), granted -> { });

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        try {
            setContentView(R.layout.activity_desktop);

            clock = findViewById(R.id.clock);
            statusText = findViewById(R.id.statusText);
            RecyclerView grid = findViewById(R.id.desktopGrid);

            updateClock();
            clock.postDelayed(this::updateClockLoop, 30000);

            List<DesktopIcon> icons = buildIcons();
            grid.setLayoutManager(new GridLayoutManager(this, 4));
            grid.setAdapter(new DesktopAdapter(icons, this::onIconClick));

            findViewById(R.id.taskStart).setOnClickListener(v -> showStartMenu());
            findViewById(R.id.taskLinux).setOnClickListener(v -> openLinux());
            findViewById(R.id.taskTermux).setOnClickListener(v -> launchTermux());
            findViewById(R.id.taskSetup).setOnClickListener(v ->
                    startActivity(new Intent(this, SetupActivity.class)));

            refreshStatus();
            requestNotificationPermissionIfNeeded();
        } catch (Exception e) {
            Toast.makeText(this, "Ошибка запуска: " + e.getMessage(), Toast.LENGTH_LONG).show();
            finish();
        }
    }

    private void updateClockLoop() {
        if (clock == null) return;
        updateClock();
        clock.postDelayed(this::updateClockLoop, 30000);
    }

    private void updateClock() {
        if (clock != null) {
            clock.setText(new SimpleDateFormat("HH:mm", Locale.getDefault()).format(new Date()));
        }
    }

    private void requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
                && ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) {
            notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS);
        }
    }

    private void refreshStatus() {
        if (statusText == null) return;
        boolean termux = TermuxHelper.isTermuxInstalled(this);
        boolean linux = getSharedPreferences("mateshell", MODE_PRIVATE)
                .getBoolean("linux_installed", false);
        statusText.setText(termux
                ? (linux ? "Linux готов" : "Termux OK - установите Linux")
                : "Нужен Termux");
    }

    private List<DesktopIcon> buildIcons() {
        List<DesktopIcon> list = new ArrayList<>();
        list.add(new DesktopIcon("linux", "LN", "Linux", "local"));
        list.add(new DesktopIcon("setup", "ST", "Setup", "local"));
        list.add(new DesktopIcon("termux", "TX", "Termux", "local"));
        list.add(new DesktopIcon("vscode", "VS", "VS Code", "linux"));
        list.add(new DesktopIcon("files", "FL", "Files", "android"));
        list.add(new DesktopIcon("browser", "BR", "Browser", "android"));
        list.add(new DesktopIcon("steam", "GM", "Steam", "android"));
        list.add(new DesktopIcon("settings", "CF", "Settings", "android"));
        return list;
    }

    private void onIconClick(DesktopIcon icon) {
        switch (icon.id) {
            case "linux":
                openLinux();
                break;
            case "setup":
                startActivity(new Intent(this, SetupActivity.class));
                break;
            case "termux":
                launchTermux();
                break;
            case "vscode":
                openLinux();
                Toast.makeText(this, "VS Code в Linux Desktop", Toast.LENGTH_SHORT).show();
                break;
            case "files":
                launchApp("com.huawei.hidisk", "com.android.documentsui");
                break;
            case "browser":
                launchApp("com.huawei.browser", "com.android.chrome");
                break;
            case "steam":
                launchSteam();
                break;
            case "settings":
                startActivity(new Intent(android.provider.Settings.ACTION_SETTINGS));
                break;
            default:
                break;
        }
    }

    private void openLinux() {
        if (!TermuxHelper.isTermuxInstalled(this)) {
            startActivity(new Intent(this, SetupActivity.class));
            return;
        }
        startActivity(new Intent(this, LinuxDesktopActivity.class));
    }

    private void launchTermux() {
        if (!TermuxHelper.isTermuxInstalled(this)) {
            TermuxHelper.openTermuxDirectApk(this);
            return;
        }
        Intent i = getPackageManager().getLaunchIntentForPackage("com.termux");
        if (i != null) startActivity(i);
    }

    private void launchSteam() {
        if (!launchApp("com.valvesoftware.android.steam.community", null)) {
            Toast.makeText(this, "Установите Steam (Android) из AppGallery", Toast.LENGTH_LONG).show();
        }
    }

    private boolean launchApp(String primary, String fallback) {
        Intent intent = getPackageManager().getLaunchIntentForPackage(primary);
        if (intent == null && fallback != null) {
            intent = getPackageManager().getLaunchIntentForPackage(fallback);
        }
        if (intent == null) {
            Intent main = new Intent(Intent.ACTION_MAIN);
            main.addCategory(Intent.CATEGORY_LAUNCHER);
            List<ResolveInfo> apps = getPackageManager().queryIntentActivities(main, 0);
            for (ResolveInfo ri : apps) {
                if (ri.activityInfo.packageName.contains("steam")) {
                    intent = getPackageManager().getLaunchIntentForPackage(ri.activityInfo.packageName);
                    break;
                }
            }
        }
        if (intent != null) {
            startActivity(intent);
            return true;
        }
        return false;
    }

    private void showStartMenu() {
        startActivity(new Intent(this, SetupActivity.class));
    }

    @Override
    protected void onResume() {
        super.onResume();
        refreshStatus();
    }
}
