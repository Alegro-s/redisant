package io.mateshell;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.widget.Toast;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;

/**
 * Отправка команд в Termux (локально на планшете).
 * Требует: Termux → Settings → Allow external apps → MateShell
 */
public final class TermuxHelper {

    private TermuxHelper() {}

    public static boolean isTermuxInstalled(Context ctx) {
        try {
            ctx.getPackageManager().getPackageInfo("com.termux", 0);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    public static void openTermuxInstallPage(Context ctx) {
        ctx.startActivity(new Intent(Intent.ACTION_VIEW,
                Uri.parse("https://f-droid.org/packages/com.termux/")));
    }

    /**
     * "One-click" install flow: opens direct APK in package installer.
     * Note: Android forbids silent third-party app install without device-owner/root.
     */
    public static void openTermuxDirectApk(Context ctx) {
        ctx.startActivity(new Intent(Intent.ACTION_VIEW,
                Uri.parse("https://github.com/termux/termux-app/releases/latest")));
    }

    public static void runCommand(Context ctx, String bashScript, boolean background) {
        if (!isTermuxInstalled(ctx)) {
            Toast.makeText(ctx, "Установите Termux (F-Droid)", Toast.LENGTH_LONG).show();
            return;
        }
        Intent intent = new Intent();
        intent.setClassName("com.termux", "com.termux.app.RunCommandService");
        intent.setAction("com.termux.RUN_COMMAND");
        intent.putExtra("com.termux.RUN_COMMAND_PATH", "/data/data/com.termux/files/usr/bin/bash");
        intent.putExtra("com.termux.RUN_COMMAND_ARGUMENTS", new String[]{"-c", bashScript});
        intent.putExtra("com.termux.RUN_COMMAND_WORKDIR", "/data/data/com.termux/files/home");
        intent.putExtra("com.termux.RUN_COMMAND_BACKGROUND", background);
        try {
            ctx.startForegroundService(intent);
        } catch (Exception e) {
            // fallback: open Termux
            Intent launch = ctx.getPackageManager().getLaunchIntentForPackage("com.termux");
            if (launch != null) ctx.startActivity(launch);
            Toast.makeText(ctx, "Разрешите MateShell в Termux → Settings", Toast.LENGTH_LONG).show();
        }
    }

    public static void copyAssetScript(Context ctx, String assetName, File dest) throws Exception {
        try (InputStream in = ctx.getAssets().open(assetName);
             FileOutputStream out = new FileOutputStream(dest)) {
            byte[] buf = new byte[8192];
            int n;
            while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
        }
    }

    public static void startLinuxInstall(Context ctx) {
        runCommand(ctx,
                "mkdir -p ~/mate-shell && cp -f '" + extractInstallScript(ctx) + "' ~/mate-shell/install.sh "
                        + "&& chmod +x ~/mate-shell/install.sh && bash ~/mate-shell/install.sh",
                true);
    }

    public static void startLinuxDesktop(Context ctx) {
        runCommand(ctx, "bash ~/mate-shell/start-linux.sh 2>/dev/null || "
                + "(proot-distro login debian -- bash -lc mateshell-start)", true);
    }

    public static void stopLinuxDesktop(Context ctx) {
        runCommand(ctx, "bash ~/mate-shell/stop-linux.sh 2>/dev/null || "
                + "(proot-distro login debian -- bash -lc mateshell-stop)", true);
    }

    private static String extractInstallScript(Context ctx) {
        try {
            File dir = new File(ctx.getFilesDir(), "scripts");
            if (!dir.exists()) dir.mkdirs();
            File script = new File(dir, "install-linux.sh");
            copyAssetScript(ctx, "install-linux.sh", script);
            // Termux can't read app private dir easily — push via cat in command
            return script.getAbsolutePath();
        } catch (Exception e) {
            return "~/mate-shell/install.sh";
        }
    }

    /** Копирует install script в Termux home через base64 pipe */
    public static void pushAndInstall(Context ctx) {
        try {
            InputStream in = ctx.getAssets().open("install-linux.sh");
            StringBuilder sb = new StringBuilder();
            BufferedReader br = new BufferedReader(new InputStreamReader(in));
            String line;
            while ((line = br.readLine()) != null) {
                sb.append(line).append("\n");
            }
            String escaped = sb.toString().replace("'", "'\\''");
            runCommand(ctx,
                    "mkdir -p ~/mate-shell && cat > ~/mate-shell/install.sh << 'MATEEOF'\n"
                            + sb + "MATEEOF\nchmod +x ~/mate-shell/install.sh && bash ~/mate-shell/install.sh",
                    true);
        } catch (Exception e) {
            Toast.makeText(ctx, "Ошибка: " + e.getMessage(), Toast.LENGTH_LONG).show();
        }
    }
}
