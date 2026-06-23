package com.example.client

import android.app.Activity
import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.MethodChannel

object LynxEngineAndroidLauncher {
    private const val CHANNEL = "lynx/engine_launcher"

    fun register(activity: Activity, messenger: io.flutter.plugin.common.BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "launchEngine" -> {
                    val args = call.arguments as? Map<*, *>
                    val intent = Intent(activity, EngineActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        args?.get("projectPath")?.toString()?.let { putExtra("project-path", it) }
                        args?.get("projectId")?.toString()?.let { putExtra("project-id", it) }
                        args?.get("projectName")?.toString()?.let { putExtra("project-name", it) }
                        args?.get("apiBase")?.toString()?.let { putExtra("api-base", it) }
                        args?.get("engineVer")?.toString()?.let { putExtra("engine-ver", it) }
                        if (args?.get("cloudReadOnly") == true) putExtra("cloud-read-only", true)
                    }
                    activity.startActivity(intent)
                    result.success(true)
                }
                "readIntentExtras" -> {
                    result.success(readIntentExtras(activity))
                }
                else -> result.notImplemented()
            }
        }
    }

    fun readIntentExtras(context: Context): Map<String, Any?> {
        val activity = context as? Activity ?: return emptyMap()
        val i = activity.intent ?: return emptyMap()
        return mapOf(
            "projectPath" to i.getStringExtra("project-path"),
            "projectId" to i.getStringExtra("project-id"),
            "projectName" to i.getStringExtra("project-name"),
            "apiBase" to i.getStringExtra("api-base"),
            "engineVer" to i.getStringExtra("engine-ver"),
            "cloudReadOnly" to i.getBooleanExtra("cloud-read-only", false),
        )
    }
}
