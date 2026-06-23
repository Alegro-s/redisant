package com.example.client

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/// Lynx Engine — отдельная Activity (волна 16 / Android).
class EngineActivity : FlutterActivity() {
    override fun getDartEntrypointFunctionName(): String = "main"

    override fun getDartEntrypointLibraryUri(): String = "package:client/main_engine.dart"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        LynxEngineAndroidLauncher.register(this, flutterEngine.dartExecutor.binaryMessenger)
    }
}
