package com.conscience.app

import android.content.Context
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Today's time in vice apps, plus any time earned back. Saved to disk so it
 * survives a service restart, and cleared when the day changes.
 *
 * The service and MainActivity share one instance, so earned time is recorded
 * even if the accessibility service isn't running at that moment.
 */
class UsageTracker(
    private val store: Store,
    private val now: () -> Long,
    private val dayOf: (Long) -> String
) {
    interface Store {
        fun load(): Saved?
        fun save(saved: Saved)
    }

    data class Saved(val day: String, val usedMs: Long, val bonusMs: Long)

    private var day: String
    private var savedUsedMs: Long
    private var bonus: Long
    private var activeSince: Long? = null

    init {
        val today = dayOf(now())
        val saved = store.load()?.takeIf { it.day == today }
        day = today
        savedUsedMs = saved?.usedMs ?: 0L
        bonus = saved?.bonusMs ?: 0L
    }

    @Synchronized
    fun start() {
        rollDayIfNeeded()
        if (activeSince == null) activeSince = now()
    }

    @Synchronized
    fun stop() {
        rollDayIfNeeded()
        val since = activeSince ?: return
        savedUsedMs += (now() - since).coerceAtLeast(0L)
        activeSince = null
        persist()
    }

    @Synchronized
    fun usedMs(): Long {
        rollDayIfNeeded()
        val running = activeSince?.let { (now() - it).coerceAtLeast(0L) } ?: 0L
        return savedUsedMs + running
    }

    @Synchronized
    fun bonusMs(): Long {
        rollDayIfNeeded()
        return bonus
    }

    /** Adds earned time to today's limit. */
    @Synchronized
    fun grant(ms: Long) {
        rollDayIfNeeded()
        bonus += ms.coerceAtLeast(0L)
        persist()
    }

    @Synchronized
    fun resetToday() {
        rollDayIfNeeded()
        savedUsedMs = 0L
        bonus = 0L
        if (activeSince != null) activeSince = now()
        persist()
    }

    private fun rollDayIfNeeded() {
        val today = dayOf(now())
        if (today == day) return
        day = today
        savedUsedMs = 0L
        bonus = 0L
        if (activeSince != null) activeSince = now()
        persist()
    }

    private fun persist() = store.save(Saved(day, savedUsedMs, bonus))

    companion object {
        private const val PREFS = "conscience_usage"
        private const val KEY_DAY = "usage_day"
        private const val KEY_USED = "usage_ms"
        private const val KEY_BONUS = "bonus_ms"

        @Volatile
        private var instance: UsageTracker? = null

        fun get(context: Context): UsageTracker =
            instance ?: synchronized(this) {
                instance ?: create(context.applicationContext).also { instance = it }
            }

        private fun create(context: Context): UsageTracker {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val store = object : Store {
                override fun load(): Saved? {
                    val day = prefs.getString(KEY_DAY, null) ?: return null
                    return Saved(day, prefs.getLong(KEY_USED, 0L), prefs.getLong(KEY_BONUS, 0L))
                }

                override fun save(saved: Saved) {
                    prefs.edit()
                        .putString(KEY_DAY, saved.day)
                        .putLong(KEY_USED, saved.usedMs)
                        .putLong(KEY_BONUS, saved.bonusMs)
                        .apply()
                }
            }
            return UsageTracker(store, System::currentTimeMillis) { ms ->
                SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(ms))
            }
        }
    }
}

/**
 * Windows that appear on top of an app without the person leaving it, such as
 * the keyboard or notification shade. They must not end a session, because the
 * app underneath sends no new event when they close.
 */
fun isTransientWindow(pkg: String, keyboardPkg: String?): Boolean =
    pkg == "com.android.systemui" || pkg == "android" || pkg == keyboardPkg
