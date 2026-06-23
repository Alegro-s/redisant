package com.chairup.android

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.chairup.android.ui.ChairUpRoot
import com.chairup.android.ui.theme.ChairUpTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            ChairUpTheme {
                ChairUpRoot()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == com.chairup.android.integration.health.DefaultHealthGateway.AUTH_REQUEST_CODE) {
            // HMS Health authorization result — HealthViewModel refresh via re-open screen
        }
    }
}
