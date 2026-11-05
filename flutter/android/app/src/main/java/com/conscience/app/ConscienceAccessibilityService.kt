package com.conscience.app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Handler
import android.os.Looper
import android.provider.Settings
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
        /** Floor so rounding at a stage boundary can't cause a tight wake-up loop. */
        private const val MIN_WAKE_MS = 500L

        private const val KEY_PER_APP_LIMITS = "per_app_limits"
        private const val KEY_VICE_APPS = "vice_apps"
        private const val KEY_DAILY_LIMIT = "daily_limit_ms"

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

        /** Saves the settings so they survive the app and service restarting. */
        fun saveConfig(context: Context, apps: Set<String>, limitMs: Long) {
            viceApps = apps
            dailyLimitMs = limitMs
            prefs(context).edit()
                .putStringSet(KEY_VICE_APPS, apps)
                .putLong(KEY_DAILY_LIMIT, limitMs)
                .apply()
        }

        fun loadConfig(context: Context) {
            val p = prefs(context)
            p.getStringSet(KEY_VICE_APPS, null)?.let { viceApps = it.toSet() }
            if (p.contains(KEY_DAILY_LIMIT)) dailyLimitMs = p.getLong(KEY_DAILY_LIMIT, dailyLimitMs)
        }

        private fun prefs(context: Context) =
            context.getSharedPreferences("conscience_usage", Context.MODE_PRIVATE)
    }

    private val handler = Handler(Looper.getMainLooper())
    private val tracker by lazy { UsageTracker.get(this) }
    private var currentVicePackage = ""
    private var pausedVicePackage = ""
    private var screenAway = false
    private var lastStage: AvatarStage? = null
    private var overlayManager: OverlayManager? = null
    private var commandReceiver: BroadcastReceiver? = null
    private var screenReceiver: BroadcastReceiver? = null
    private var persona: AvatarPersona? = null

    override fun onServiceConnected() {
        serviceInfo = serviceInfo.apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
            notificationTimeout = 500
        }
        loadConfig(this)
        persona = loadPersona()
        perAppLimits = loadPerAppLimits()
        overlayManager = OverlayManager(this)

        // Register for MainActivity signals
        commandReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                when (intent.action) {
                    // The tracker is already updated, so only re-check the current app.
                    ACTION_RESET, ACTION_GRANT_EXT -> {
                        lastStage = null
                        handler.removeCallbacks(stageCheck)
                        if (currentVicePackage.isNotEmpty()) handler.post(stageCheck)
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

        screenReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                when (intent.action) {
                    Intent.ACTION_SCREEN_OFF -> onScreenAway()
                    Intent.ACTION_USER_PRESENT -> onScreenBack()
                    Intent.ACTION_SCREEN_ON -> {
                        // With no lock screen, USER_PRESENT may never arrive.
                        val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                        if (!keyguard.isKeyguardLocked) onScreenBack()
                    }
                }
            }
        }
        registerReceiver(screenReceiver, IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_USER_PRESENT)
        })
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        if (screenAway) return
        val pkg = event.packageName?.toString() ?: return

        if (pkg in viceApps) {
            if (currentVicePackage != pkg) enterVice(pkg)
        } else if (currentVicePackage.isNotEmpty() && !isTransientWindow(pkg, keyboardPackage())) {
            leaveVice()
        }
    }

    private fun enterVice(pkg: String) {
        endSession()
        currentVicePackage = pkg
        tracker.start()
        lastStage = null
        handler.post(stageCheck)
    }

    private fun leaveVice() {
        endSession()
        currentVicePackage = ""
        lastStage = null
        overlayManager?.dismissOverlay()
    }

    private fun onScreenAway() {
        screenAway = true
        pausedVicePackage = currentVicePackage
        if (currentVicePackage.isNotEmpty()) leaveVice()
    }

    private fun onScreenBack() {
        if (!screenAway) return
        screenAway = false
        // Unlocking returns to the same app, which may not send a new event.
        val pkg = pausedVicePackage
        pausedVicePackage = ""
        if (pkg.isNotEmpty()) enterVice(pkg)
    }

    private fun keyboardPackage(): String? =
        Settings.Secure.getString(contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD)
            ?.substringBefore('/')

    private val stageCheck = object : Runnable {
        override fun run() {
            if (currentVicePackage.isEmpty()) return
            val limit = effectiveLimit()
            val used = tracker.usedMs()
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

            if (used >= limit) {
                writeUsageToFirestore(used)
                showBlockScreen()
                return
            }
            scheduleNextWake()
        }
    }

    private fun showBlockScreen() {
        overlayManager?.dismissOverlay()
        startActivity(Intent(this, BlockActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        })
    }

    /** This app's limit plus any time earned today. */
    private fun effectiveLimit(): Long =
        (limitFor(currentVicePackage) + tracker.bonusMs()).coerceAtLeast(1L)

    /** Wake up when the next threshold would be crossed (capped so a restart re-anchors). */
    private fun scheduleNextWake() {
        handler.removeCallbacks(stageCheck)
        if (currentVicePackage.isEmpty()) return
        val limit = effectiveLimit()
        val used = tracker.usedMs()
        val activePersona = persona ?: loadPersona().also { persona = it }
        val ratio = used.toFloat() / limit.toFloat()
        val nextBoundary = nextThresholdAfter(activePersona, ratio)
        val dueMs = (nextBoundary * limit).toLong() - used
        handler.postDelayed(stageCheck, dueMs.coerceIn(MIN_WAKE_MS, MAX_WAKE_MS))
    }

    private fun nextThresholdAfter(p: AvatarPersona, ratio: Float): Float {
        val candidates = listOf(
            p.thresholds[AvatarStage.IMPATIENT] ?: 0.25f,
            p.thresholds[AvatarStage.FURIOUS] ?: 0.75f,
            p.thresholds[AvatarStage.ENOUGH] ?: 1.00f,
            1.00f // the block always happens at the limit, whatever the persona's stages
        ).sorted()
        return candidates.firstOrNull { it > ratio } ?: 1.00f
    }

    private fun endSession() {
        tracker.stop()
        handler.removeCallbacks(stageCheck)
    }

    private fun writeUsageToFirestore(totalMs: Long) {
        val uid = FirebaseAuth.getInstance().currentUser?.uid ?: return
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        FirebaseFirestore.getInstance()
            .collection("usageStats").document(uid)
            .collection("daily").document(today)
            .set(
                mapOf("totalViceMinutes" to totalMs / 60_000),
                com.google.firebase.firestore.SetOptions.merge()
            )
    }

    private fun loadPersona(): AvatarPersona =
        AvatarPersona.loadOrDefault(this, MessageEngine.selectedAvatarId(this))

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
        screenReceiver?.let { unregisterReceiver(it) }
        screenReceiver = null
    }
}

enum class AvatarStage { ZEN, IMPATIENT, FURIOUS, ENOUGH }
