package io.mateshell;

import android.app.Application;
import android.content.SharedPreferences;

public class MateApp extends Application {
    private static MateApp instance;

    @Override
    public void onCreate() {
        super.onCreate();
        instance = this;
    }

    public static MateApp get() {
        return instance;
    }

    public SharedPreferences prefs() {
        return getSharedPreferences("mateshell", MODE_PRIVATE);
    }

    public boolean isLinuxInstalled() {
        return prefs().getBoolean("linux_installed", false);
    }

    public void setLinuxInstalled(boolean v) {
        prefs().edit().putBoolean("linux_installed", v).apply();
    }
}
