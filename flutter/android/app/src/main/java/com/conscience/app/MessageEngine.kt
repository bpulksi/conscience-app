package com.conscience.app

import android.content.Context
import android.content.SharedPreferences
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Decides *whether* the avatar speaks, and which line it says.
 *
 * Three rules, all deliberate:
 *  - one line per stage change, never on a timer;
 *  - at least minGapSeconds between lines;
 *  - never more than maxLinesPerDay, so it can't become nagging wallpaper.
 * Lines are shuffled without repeating until the stage's pool is used up.
 */
class MessageEngine(
    private val persona: AvatarPersona,
    private val prefs: SharedPreferences
) {
    private val queues = HashMap<AvatarStage, ArrayDeque<String>>()
    private val lastLine = HashMap<AvatarStage, String>()
    private var lastServedAtMs = 0L

    fun isMuted(now: Long = System.currentTimeMillis()): Boolean =
        prefs.getLong(KEY_MUTE_UNTIL, 0L) > now

    fun mutedUntil(now: Long = System.currentTimeMillis()): Long =
        prefs.getLong(KEY_MUTE_UNTIL, 0L).takeIf { it > now } ?: 0L

    fun muteFor(ms: Long = MUTE_MS, now: Long = System.currentTimeMillis()) {
        prefs.edit().putLong(KEY_MUTE_UNTIL, now + ms).apply()
    }

    fun unmute() {
        prefs.edit().remove(KEY_MUTE_UNTIL).apply()
    }

    /**
     * Returns the line to show for [stage], or null when the avatar should stay
     * quiet (muted, too soon, daily cap reached, or no lines for this stage).
     */
    fun nextLine(stage: AvatarStage, now: Long = System.currentTimeMillis()): String? {
        if (isMuted(now)) return null
        val gapMs = persona.minGapSeconds * 1000L
        if (lastServedAtMs > 0 && now - lastServedAtMs < gapMs) return null
        // Check for a line first, so a stage with no lines doesn't use up the daily cap.
        if (persona.linesFor(stage).isEmpty()) return null
        if (!reserveDailySlot(now)) return null
        val line = draw(stage) ?: return null
        lastServedAtMs = now
        return line
    }

    /** Test/QA helper: draw a line for the stage ignoring every rate limit. */
    fun sampleLine(stage: AvatarStage): String? = draw(stage)

    fun servedToday(now: Long = System.currentTimeMillis()): Int {
        val day = dayKey(now)
        return if (prefs.getString(KEY_SERVED_DAY, null) == day) prefs.getInt(KEY_SERVED_COUNT, 0) else 0
    }

    private fun reserveDailySlot(now: Long): Boolean {
        val day = dayKey(now)
        val stored = prefs.getString(KEY_SERVED_DAY, null)
        var count = if (stored == day) prefs.getInt(KEY_SERVED_COUNT, 0) else 0
        if (count >= persona.maxLinesPerDay) return false
        count += 1
        prefs.edit().putString(KEY_SERVED_DAY, day).putInt(KEY_SERVED_COUNT, count).apply()
        return true
    }

    private fun draw(stage: AvatarStage): String? {
        val pool = persona.linesFor(stage)
        if (pool.isEmpty()) return null
        val queue = queues.getOrPut(stage) { ArrayDeque() }
        if (queue.isEmpty()) {
            val shuffled = pool.shuffled().toMutableList()
            val previous = lastLine[stage]
            if (shuffled.size > 1 && shuffled.first() == previous) {
                shuffled.add(shuffled.removeAt(0))
            }
            queue.addAll(shuffled)
        }
        val line = queue.removeFirst()
        lastLine[stage] = line
        return line
    }

    private fun dayKey(now: Long): String =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(now))

    companion object {
        const val MUTE_MS = 30 * 60 * 1000L
        const val KEY_MUTE_UNTIL = "avatar_mute_until"
        private const val KEY_SERVED_DAY = "avatar_served_day"
        private const val KEY_SERVED_COUNT = "avatar_served_count"

        fun prefs(context: Context): SharedPreferences =
            context.getSharedPreferences("conscience_avatar", Context.MODE_PRIVATE)

        fun selectedAvatarId(context: Context): String =
            prefs(context).getString("selected_avatar", null) ?: AvatarPersona.DEFAULT_AVATAR_ID

        fun selectAvatar(context: Context, id: String) {
            prefs(context).edit().putString("selected_avatar", id).apply()
        }
    }
}
