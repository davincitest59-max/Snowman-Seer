package com.oceanbaby.ocean_baby

import android.app.Notification
import android.content.ContentValues
import android.content.Context
import android.content.SharedPreferences
import android.database.sqlite.SQLiteDatabase
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.plugin.common.EventChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.Locale
import kotlin.math.roundToInt

class OceanBabyNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (!allowedPackageNames.contains(sbn.packageName)) {
            return
        }

        val title = extractTitle(sbn.notification)
        val body = extractBody(sbn.notification)
        val event = mapOf(
            "packageName" to sbn.packageName,
            "title" to title,
            "body" to body,
            "postedAtMillis" to sbn.postTime,
        )

        runCatching {
            saveLedgerRecord(this, event)
        }
        enqueueEvent(this, event)
        flushPendingEvents(this)
    }

    companion object {
        private const val preferencesName = "ocean_baby_notifications"
        private const val pendingEventsKey = "pending_events"
        private const val maxPendingEvents = 100

        private val allowedPackageNames = setOf(
            "com.tencent.mm",
            "com.eg.android.AlipayGphone",
        )
        private val mainHandler = Handler(Looper.getMainLooper())
        private val sinkLock = Any()
        private val queueLock = Any()

        private var eventSink: EventChannel.EventSink? = null

        fun setSink(context: Context, sink: EventChannel.EventSink?) {
            synchronized(sinkLock) {
                eventSink = sink
            }
            if (sink != null) {
                flushPendingEvents(context)
            }
        }

        fun clearSink() {
            synchronized(sinkLock) {
                eventSink = null
            }
        }

        private fun extractTitle(notification: Notification): String {
            val extras = notification.extras
            return extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        }

        private fun extractBody(notification: Notification): String {
            val extras = notification.extras
            val parts = mutableListOf<String>()

            listOf(
                Notification.EXTRA_TEXT,
                Notification.EXTRA_BIG_TEXT,
                Notification.EXTRA_SUB_TEXT,
                Notification.EXTRA_SUMMARY_TEXT,
                Notification.EXTRA_INFO_TEXT,
            ).forEach { key ->
                extras.getCharSequence(key)?.toString()?.takeIf { it.isNotBlank() }?.let(parts::add)
            }

            extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
                ?.map { it.toString() }
                ?.filter { it.isNotBlank() }
                ?.let(parts::addAll)

            return parts.distinct().joinToString("\n")
        }

        private fun saveLedgerRecord(context: Context, event: Map<String, Any>) {
            val record = parseLedgerRecord(event) ?: return
            val database = openDatabase(context)
            try {
                ensureLedgerSchema(database)
                database.insertWithOnConflict(
                    "ledger_records",
                    null,
                    record,
                    SQLiteDatabase.CONFLICT_IGNORE,
                )
            } finally {
                database.close()
            }
        }

        private fun parseLedgerRecord(event: Map<String, Any>): ContentValues? {
            val packageName = event["packageName"] as? String ?: return null
            val title = event["title"] as? String ?: ""
            val body = event["body"] as? String ?: ""
            val postedAtMillis = event["postedAtMillis"] as? Long ?: return null
            val text = "$title $body"
            val amount = extractAmount(text) ?: return null
            val direction = extractDirection(text) ?: return null
            val counterparty = extractCounterparty(text).orEmpty()
            val amountCents = (amount * 100).roundToInt()
            val source = when (packageName) {
                "com.tencent.mm" -> "wechat"
                "com.eg.android.AlipayGphone" -> "alipay"
                else -> return null
            }
            val occurredAt = isoLikeLocalTime(postedAtMillis)
            val fingerprint = listOf(
                source,
                occurredAt,
                amountCents.toString(),
                direction,
                counterparty,
                body,
            ).joinToString("|")

            return ContentValues().apply {
                put("source", source)
                put("origin", "notification")
                put("occurred_at", occurredAt)
                put("amount_cents", amountCents)
                put("amount", amountCents / 100.0)
                put("direction", direction)
                put("counterparty", counterparty)
                put("description", body)
                put("payment_method", "未知")
                put("original_category", "通知自动记账")
                put("user_category", "未分类")
                put("note", "")
                put("import_batch_id", "通知自动记账")
                put(
                    "confirmation_status",
                    if (counterparty.isBlank()) "pending" else "confirmed",
                )
                put("fingerprint", fingerprint)
                put("updated_at", occurredAt)
            }
        }

        private fun extractAmount(text: String): Double? {
            val regex = Regex("""(?:¥|￥)\s*(\d+(?:\.\d{1,2})?)|(\d+(?:\.\d{1,2})?)\s*元""")
            val match = regex.find(text) ?: return null
            return (match.groups[1]?.value ?: match.groups[2]?.value)?.toDoubleOrNull()
        }

        private fun extractDirection(text: String): String? {
            if (text.contains("付款") || text.contains("支付成功") || text.contains("成功付款")) {
                return "expense"
            }
            if (text.contains("收款") || text.contains("到账")) {
                return "income"
            }
            return null
        }

        private fun extractCounterparty(text: String): String? {
            Regex("""向(.+?)付款""").find(text)?.groups?.get(1)?.value?.trim()?.let {
                if (it.isNotEmpty()) return it
            }
            Regex("""给\s*([^\s，,。；;]+)""").find(text)?.groups?.get(1)?.value?.trim()?.let {
                if (it.isNotEmpty()) return it
            }
            return null
        }

        private fun openDatabase(context: Context): SQLiteDatabase {
            val databaseFile = File(context.applicationContext.filesDir, "ocean_baby.sqlite")
            return SQLiteDatabase.openOrCreateDatabase(databaseFile, null)
        }

        private fun ensureLedgerSchema(database: SQLiteDatabase) {
            database.execSQL(
                """
                CREATE TABLE IF NOT EXISTS ledger_records (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  source TEXT NOT NULL,
                  origin TEXT NOT NULL,
                  occurred_at TEXT NOT NULL,
                  amount_cents INTEGER NOT NULL,
                  amount REAL NOT NULL,
                  direction TEXT NOT NULL,
                  counterparty TEXT NOT NULL,
                  description TEXT NOT NULL,
                  payment_method TEXT NOT NULL,
                  original_category TEXT NOT NULL,
                  user_category TEXT NOT NULL,
                  note TEXT NOT NULL,
                  import_batch_id TEXT NOT NULL,
                  confirmation_status TEXT NOT NULL,
                  fingerprint TEXT NOT NULL UNIQUE,
                  updated_at TEXT NOT NULL
                )
                """.trimIndent(),
            )
            database.execSQL(
                """
                CREATE INDEX IF NOT EXISTS idx_ledger_records_occurred_at
                ON ledger_records (occurred_at DESC)
                """.trimIndent(),
            )
        }

        private fun isoLikeLocalTime(milliseconds: Long): String {
            return java.text.SimpleDateFormat(
                "yyyy-MM-dd'T'HH:mm:ss.SSS",
                Locale.ROOT,
            ).format(java.util.Date(milliseconds))
        }

        private fun enqueueEvent(context: Context, event: Map<String, Any>) {
            synchronized(queueLock) {
                val preferences = preferences(context)
                val events = readEvents(preferences)
                events.put(JSONObject(event))
                while (events.length() > maxPendingEvents) {
                    events.remove(0)
                }
                preferences.edit().putString(pendingEventsKey, events.toString()).commit()
            }
        }

        fun flushPendingEvents(context: Context) {
            val sink = synchronized(sinkLock) { eventSink } ?: return
            val events = synchronized(queueLock) {
                val preferences = preferences(context)
                readEvents(preferences)
            }
            if (events.length() == 0) return

            val deliveredKeys = mutableSetOf<String>()
            for (index in 0 until events.length()) {
                val event = events.getJSONObject(index)
                val eventKey = eventKey(event)
                mainHandler.post {
                    runCatching {
                        sink.success(
                            mapOf(
                                "packageName" to event.optString("packageName"),
                                "title" to event.optString("title"),
                                "body" to event.optString("body"),
                                "postedAtMillis" to event.optLong("postedAtMillis"),
                            )
                        )
                        synchronized(queueLock) {
                            deliveredKeys.add(eventKey)
                            removeDeliveredEvents(context, deliveredKeys)
                        }
                    }
                }
            }
        }

        private fun removeDeliveredEvents(context: Context, deliveredKeys: Set<String>) {
            val preferences = preferences(context)
            val currentEvents = readEvents(preferences)
            val remainingEvents = JSONArray()
            for (index in 0 until currentEvents.length()) {
                val event = currentEvents.getJSONObject(index)
                if (!deliveredKeys.contains(eventKey(event))) {
                    remainingEvents.put(event)
                }
            }
            if (remainingEvents.length() == 0) {
                preferences.edit().remove(pendingEventsKey).commit()
            } else {
                preferences.edit().putString(pendingEventsKey, remainingEvents.toString()).commit()
            }
        }

        private fun eventKey(event: JSONObject): String {
            return listOf(
                event.optString("packageName"),
                event.optString("title"),
                event.optString("body"),
                event.optLong("postedAtMillis").toString(),
            ).joinToString("|")
        }

        private fun readEvents(preferences: SharedPreferences): JSONArray {
            val raw = preferences.getString(pendingEventsKey, null) ?: return JSONArray()
            return runCatching { JSONArray(raw) }.getOrDefault(JSONArray())
        }

        private fun preferences(context: Context): SharedPreferences {
            return context.applicationContext.getSharedPreferences(
                preferencesName,
                Context.MODE_PRIVATE,
            )
        }
    }
}
