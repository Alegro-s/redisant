package io.mateshell;

import android.annotation.SuppressLint;
import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.ProgressBar;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

/**
 * Локальный Linux-рабочий стол через noVNC → TigerVNC → XFCE (всё на 127.0.0.1).
 */
public class LinuxDesktopActivity extends AppCompatActivity {

    private WebView webView;
    private ProgressBar progress;

    @SuppressLint("SetJavaScriptEnabled")
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_linux_desktop);

        webView = findViewById(R.id.vncWebView);
        progress = findViewById(R.id.progress);

        WebSettings s = webView.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setUseWideViewPort(true);
        s.setLoadWithOverviewMode(true);
        webView.setWebViewClient(new WebViewClient() {
            @Override
            public void onPageFinished(WebView view, String url) {
                progress.setVisibility(View.GONE);
            }
        });

        findViewById(R.id.btnStartVnc).setOnClickListener(v -> bootLinux());
        findViewById(R.id.btnOpenDesktop).setOnClickListener(v -> openDesktop());
        findViewById(R.id.btnStopVnc).setOnClickListener(v -> stopLinux());

        bootLinux();
    }

    private void bootLinux() {
        progress.setVisibility(View.VISIBLE);
        startService(new Intent(this, LinuxService.class).setAction(LinuxService.ACTION_START));
        Toast.makeText(this, "Запуск VNC (подождите 15–30 сек)...", Toast.LENGTH_SHORT).show();
        webView.postDelayed(this::openDesktop, 15000);
    }

    private void openDesktop() {
        // noVNC локально в proot debian на порту 6080
        webView.loadUrl("http://127.0.0.1:6080/vnc.html?autoconnect=true&password=mateshell");
    }

    private void stopLinux() {
        startService(new Intent(this, LinuxService.class).setAction(LinuxService.ACTION_STOP));
        Toast.makeText(this, "Linux остановлен", Toast.LENGTH_SHORT).show();
        finish();
    }

    @Override
    public void onBackPressed() {
        if (webView.canGoBack()) webView.goBack();
        else super.onBackPressed();
    }
}
