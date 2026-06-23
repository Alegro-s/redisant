package com.chairup.android.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import androidx.room.Room
import com.chairup.android.R
import com.chairup.android.data.local.ChairUpDatabase
import kotlinx.coroutines.runBlocking
import java.time.LocalDate
import java.time.format.DateTimeFormatter

class ChairUpWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val today = LocalDate.now().format(DateTimeFormatter.ISO_LOCAL_DATE)
        val db = Room.databaseBuilder(
            context.applicationContext,
            ChairUpDatabase::class.java,
            "chairup.db",
        ).fallbackToDestructiveMigration().build()
        val daily = runBlocking { db.dailyAggregateDao().getByDate(today) }
        db.close()
        val micro = "${daily?.microDone ?: 0}/${daily?.microTarget ?: 4}"
        val score = daily?.dailyScore?.toInt() ?: 0

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_chairup)
            views.setTextViewText(R.id.widget_score, score.toString())
            views.setTextViewText(R.id.widget_micro, micro)
            views.setTextViewText(R.id.widget_hint, "ChairUp · микро")
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    companion object {
        fun requestUpdate(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val component = android.content.ComponentName(context, ChairUpWidgetProvider::class.java)
            val ids = mgr.getAppWidgetIds(component)
            if (ids.isNotEmpty()) {
                ChairUpWidgetProvider().onUpdate(context, mgr, ids)
            }
        }
    }
}
