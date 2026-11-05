package com.conscience.app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Accessibility service v2.
 *
 * The 30-second poll is gone. The service schedules a single wake-up at the next
 * stage boundary for the app currently in the foreground, so a session costs
 * three or four wake-ups instead of one every 30 seconds, and a wake-up that
 * crosses no boundary does nothing at all.
 */
class ConscienceAccessibilityService : AccessibilityService() {

    companion object {
        const val ACTION_AVATAR_UPDATE = "com.conscience.app.AVATAR_UPDATE"
        const val ACTION_RESET = "com.conscience.app.RESET"
        const val ACTION_GRANT_EXT = "com.conscience.app.GRANT_EXT"
        const val ACTION_PERSONA_CHANGED = "com.conscience.app.PERSONA_CHANGED"
        const val EXTRA_STAGE = "stage"
        const val EXTRA_ELAPSED_MS = "elapsedMs"
        const val EXTRA_AVATAR_ID = "avatarId"

        /** Safety cap so a restarted service re-anchors instead of trusting a long delay. */
        private const val MAX_WAKE_MS = 15 * 60 * 1000L

        private const val KEY_PER_APP_LIMITS = "per_app_limits"
        private const val KEY_USAGE_DAY = "usage_day"
        private const val KEY_USAGE_MS = "usage_ms"

        // Populated from Firestore on app launch — see native_bridge.dart
        var viceApps: Set<String> = setOf(
            "com.instagram.android",
            "com.zhiliaoapp.musically",   // TikTok
            "com.twitter.android",
            "com.google.android.youtube",
            "com.reddit.frontpage"
        )
        var dailyLimitMs: Long = 60 * 60 * 1000L // 1 hour default
        var perAppLimits: Map<String, Long> = emptyMap()

        fun limitFor(pkg: String): Long = perAppLimits[pkg] ?: dailyLimitMs

        fun setPerAppLimits(context: Context, limits: Map<String, Long>) {
            perAppLimits = limits
            val json = JSONObject()
            limits.forEach { (pkg, ms) -> json.put(pkg, ms) }
            prefs(context).edit().putString(KEY_PER_APP_LIMITS, json.toString()).apply()
        }

        private fun prefs(context: Context) =
            context.getSharedPreferences("conscience_usage", Context.MODE_PRIVATE)
    }

    private val handler = Handler(Looper.getMainLooper())
    private var currentVicePackage = ""
    private var sessionStartMs = 0L
    private var totalUsageTodayMs = 0L
    private var lastStage: AvatarStage? = null
    private var overlayManager: OverlayManager? = null
    private var commandReceiver: BroadcastReceiver? = null
    private var persona: AvatarPersona? = null

    override fun onServiceConnected() {
        serviceInfo = serviceInfo.apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
            notificationTimeout = 500
        }
        persona = loadPersona()
        perAppLimits = loadPerAppLimits()
        totalUsageTodayMs = loadUsageToday()
        overlayManager = OverlayManager(this)

        // Register for MainActivity signals
        commandReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                when (intent.action) {
                    ACTION_RESET -> {
                        totalUsageTodayMs = 0L
                        sessionStartMs = 0L
                        saveUsageToday()
                        currentVicePackage = ""
                        lastStage = null
                        handler.removeCallbacks(stageCheck)
                        overlayManager?.dismissOverlay()
                    }
                    ACTION_GRANT_EXT -> {
                        val durationMs = intent.getLongExtra("durationMs", 10 * 60 * 1000L)
                        overlayManager?.dismissOverlay()
                        lastStage = null
                        handler.removeCallbacks(stageCheck)
                        handler.postDelayed(stageCheck, durationMs)
                    }
                    ACTION_PERSONA_CHANGED -> {
                        persona = loadPersona()
                        overlayManager?.refreshPersona()
                    }
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(ACTION_RESET)
            addAction(ACTION_GRANT_EXT)
            addAction(ACTION_PERSONA_CHANGED)
        }
        LocalBroadcastManager.getInstance(this).registerReceiver(commandReceiver!!, filter)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return

        if (pkg in viceApps) {
            if (currentVicePackage != pkg) {
                endSession()
                currentVicePackage = pkg
                sessionStartMs = System.currentTimeMillis()
                lastStage = null
                handler.removeCallbacks(stageCheck)
                handler.post(stageCheck)
            }
        } else if (currentVicePackage.isNotEmpty()) {
            endSession()
            currentVicePackage = ""
            lastStage = null
            overlayManager?.dismissOverlay()
        }
    }

    private val stageCheck = object : Runnable {
        override fun run() {
            if (currentVicePackage.isEmpty()) return
            val limit = limitFor(currentVicePackage).coerceAtLeast(1L)
            val used = usedMs()
            val activePersona = persona ?: loadPersona().also { persona = it }
            val stage = activePersona.stageFor(used.toFloat() / limit.toFloat())

            if (stage != lastStage) {
                lastStage = stage
                overlayManager?.showStage(stage)
                // Local, because that is what MainActivity's receiver listens on.
                LocalBroadcastManager.getInstance(this@ConscienceAccessibilityService)
                    .sendBroadcast(Intent(ACTION_AVATAR_UPDATE).apply {
                        putExtra(EXTRA_STAGE, stage.name)
                        putExtra(EXTRA_ELAPSED_MS, used)
                        putExtra(EXTRA_AVATAR_ID, activePersona.id)
                    })
            }

            // Over the limit: record it and stop waking up. The overlay stays on screen,
            // because this build has no block screen.
            if (stage == AvatarStage.ENOUGH) {
                writeUsageToFirestore(used)
                return
            }
            scheduleNextWake()
        }
    }

    /** Wake up when the next threshold would be crossed (capped so a restart re-anchors). */
    private fun scheduleNextWake() {
        handler.removeCallbacks(stageCheck)
        if (currentVicePackage.isEmpty()) return
        val limit = limitFor(currentVicePackage).coerceAtLeast(1L)
        val used = usedMs()
        val activePersona = persona ?: loadPersona().also { persona = it }
        val ratio = used.toFloat() / limit.toFloat()
        val nextBoundary = nextThresholdAfter(activePersona, ratio)
        val dueMs = (nextBoundary * limit).toLong() - used
        handler.postDelayed(stageCheck, dueMs.coerceIn(0L, MAX_WAKE_MS))
    }

    private fun nextThresholdAfter(p: AvatarPersona, ratio: Float): Float {
        val candidates = listOf(
            p.thresholds[AvatarStage.IMPATIENT] ?: 0.25f,
            p.thresholds[AvatarStage.FURIOUS] ?: 0.75f,
            p.thresholds[AvatarStage.ENOUGH] ?: 1.00f
        ).sorted()
        return candidates.firstOrNull { it > ratio } ?: 1.00f
    }

    private fun usedMs(): Long {
        val session = if (sessionStartMs > 0) System.currentTimeMillis() - sessionStartMs else 0L
        return totalUsageTodayMs + session
    }

    private fun endSession() {
        if (sessionStartMs > 0) {
            totalUsageTodayMs += System.currentTimeMillis() - sessionStartMs
            sessionStartMs = 0
            saveUsageToday()
        }
        handler.removeCallbacks(stageCheck)
    }

    private fun writeUsageToFirestore(totalMs: Long) {
        val uid = FirebaseAuth.getInstance().currentUser?.uid ?: return
        FirebaseFirestore.getInstance()
            .collection("usageStats").document(uid)
            .collection("daily").document(dayKey())
            .set(
                mapOf("totalViceMinutes" to totalMs / 60_000),
                com.google.firebase.firestore.SetOptions.merge()
            )
    }

    // --- persistence: usage must survive a service restart -------------------

    private fun loadPersona(): AvatarPersona =
        AvatarPersona.loadOrDefault(this, MessageEngine.selectedAvatarId(this))

    private fun dayKey(): String =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    private fun loadUsageToday(): Long {
        val p = prefs(this)
        return if (p.getString(KEY_USAGE_DAY, null) == dayKey()) p.getLong(KEY_USAGE_MS, 0L) else 0L
    }

    private fun saveUsageToday() {
        prefs(this).edit()
            .putString(KEY_USAGE_DAY, dayKey())
            .putLong(KEY_USAGE_MS, totalUsageTodayMs)
            .apply()
    }

    private fun loadPerAppLimits(): Map<String, Long> {
        val raw = prefs(this).getString(KEY_PER_APP_LIMITS, null) ?: return emptyMap()
        return runCatching {
            val json = JSONObject(raw)
            json.keys().asSequence().associateWith { json.getLong(it) }
        }.getOrDefault(emptyMap())
    }

    override fun onInterrupt() {
        endSession()
        overlayManager?.dismissOverlay()
    }

    override fun onDestroy() {
        super.onDestroy()
        endSession()
        overlayManager?.dismissOverlay()
        if (commandReceiver != null) {
            LocalBroadcastManager.getInstance(this).unregisterReceiver(commandReceiver!!)
            commandReceiver = null
        }
    }
}

enum class AvatarStage { ZEN, IMPATIENT, FURIOUS, ENOUGH }
