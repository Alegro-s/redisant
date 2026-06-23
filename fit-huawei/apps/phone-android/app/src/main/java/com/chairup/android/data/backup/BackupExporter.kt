package com.chairup.android.data.backup

import android.content.Context
import android.net.Uri
import com.chairup.android.data.local.ChairUpDatabase
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class BackupExporter @Inject constructor(
    @ApplicationContext private val context: Context,
    private val db: ChairUpDatabase,
) {
    suspend fun exportToJson(): Result<String> = withContext(Dispatchers.IO) {
        runCatching {
            val root = JSONObject()
                .put("app", "ChairUp")
                .put("version", 1)
                .put("exportedAt", System.currentTimeMillis())
            root.put("daily", queryArray("SELECT * FROM daily_aggregate"))
            root.put("micro", queryArray("SELECT * FROM micro_session"))
            root.put("strength", queryArray("SELECT * FROM strength_workout"))
            root.put("weight", queryArray("SELECT * FROM weight_entry"))
            root.put("waist", queryArray("SELECT * FROM waist_entry"))
            root.put("health", queryArray("SELECT * FROM health_day"))
            root.toString(2)
        }
    }

    suspend fun writeToUri(uri: Uri, json: String): Result<Unit> = withContext(Dispatchers.IO) {
        runCatching {
            context.contentResolver.openOutputStream(uri)?.use { it.write(json.toByteArray()) }
                ?: error("Не удалось записать файл")
        }
    }

    private fun queryArray(sql: String): JSONArray {
        val arr = JSONArray()
        val cursor = db.openHelper.readableDatabase.query(sql)
        cursor.use {
            val cols = it.columnNames
            while (it.moveToNext()) {
                val row = JSONObject()
                for (col in cols) {
                    when (it.getType(it.getColumnIndexOrThrow(col))) {
                        android.database.Cursor.FIELD_TYPE_INTEGER -> row.put(col, it.getLong(it.getColumnIndexOrThrow(col)))
                        android.database.Cursor.FIELD_TYPE_FLOAT -> row.put(col, it.getDouble(it.getColumnIndexOrThrow(col)))
                        android.database.Cursor.FIELD_TYPE_STRING -> row.put(col, it.getString(it.getColumnIndexOrThrow(col)))
                        android.database.Cursor.FIELD_TYPE_NULL -> row.put(col, JSONObject.NULL)
                        else -> row.put(col, it.getString(it.getColumnIndexOrThrow(col)))
                    }
                }
                arr.put(row)
            }
        }
        return arr
    }
}
