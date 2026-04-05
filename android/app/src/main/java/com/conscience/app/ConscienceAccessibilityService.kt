package com.conscience.app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore

class ConscienceAccessibilityService : AccessibilityService() {

    companion object {
        const val ACTION_AVATAR_UPDATE = "com.conscience.app.AVATAR_UPDATE"
        const val EXTRA_STAGE = "stage"
        const val EXTRA_ELAPSED_MS = "elapsedMs"

        // Populated from Firestore on app launch — see NativeBridge.dart
        var viceApps: Set<String> = setOf(
            "com.instagram.android",
            "com.zhiliaoapp.musically",   // TikTok
            "com.twitter.android",
            "com.google.android.youtube",
            "com.reddit.frontpage"
        )
        var dailyLimitMs: Long = 60 * 60 * 1000L // 1 hour default
    }

    private val handler = Handler(Looper.getMainLooper())
    private var currentVicePackage = ""
    private var sessionStartMs = 0L
    private var totalUsageTodayMs = 0L
    private var overlayManager: OverlayManager? = null

    override fun onServiceConnected() {
        serviceInfo = serviceInfo.apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
            notificationTimeout = 500
        }
        overlayManager = OverlayManager(this)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return

        if (pkg in viceApps) {
            if (currentVicePackage != pkg) {
                // New vice app foregrounded
                currentVicePackage = pkg
                sessionStartMs = System.currentTimeMillis()
                handler.post(monitorRunnable)
            }
        } else {
            if (currentVicePackage.isNotEmpty()) {
                // User left a vice app
                accumulateSession()
                currentVicePackage = ""
                handler.removeCallbacks(monitorRunnable)
                overlayManager?.dismissOverlay()
            }
        }
    }

    private val monitorRunnable = object : Runnable {
        override fun run() {
            val sessionMs = System.currentTimeMillis() - sessionStartMs
            val combinedMs = totalUsageTodayMs + sessionMs
            val stage = resolveStage(combinedMs)

            // Update overlay
            overlayManager?.showOverlay(stage)

            // Broadcast to Flutter via platform channel
            sendBroadcast(Intent(ACTION_AVATAR_UPDATE).apply {
                putExtra(EXTRA_STAGE, stage.name)
                putExtra(EXTRA_ELAPSED_MS, combinedMs)
            })

            // If over daily limit, write to Firestore and trigger block
            if (combinedMs >= dailyLimitMs) {
                writeUsageToFirestore(combinedMs)
                triggerHardBlock()
                return // stop polling after block
            }

            handler.postDelayed(this, 30_000L)
        }
    }

    private fun resolveStage(elapsedMs: Long): AvatarStage {
        val ratio = elapsedMs.toFloat() / dailyLimitMs.toFloat()
        return when {
            ratio < 0.25f -> AvatarStage.ZEN
            ratio < 0.75f -> AvatarStage.IMPATIENT
            else -> AvatarStage.FURIOUS
        }
    }

    private fun accumulateSession() {
        if (sessionStartMs > 0) {
            totalUsageTodayMs += System.currentTimeMillis() - sessionStartMs
            sessionStartMs = 0
        }
    }

    private fun triggerHardBlock() {
        // Launch Conscience block activity over the vice app
        val blockIntent = Intent(this, BlockActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        startActivity(blockIntent)
    }

    private fun writeUsageToFirestore(totalMs: Long) {
        val uid = FirebaseAuth.getInstance().currentUser?.uid ?: return
        val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US)
            .format(java.util.Date())

        FirebaseFirestore.getInstance()
            .collection("usageStats").document(uid)
            .collection("daily").document(today)
            .set(mapOf("totalViceMinutes" to totalMs / 60_000), com.google.firebase.firestore.SetOptions.merge())
    }

    override fun onInterrupt() {
        handler.removeCallbacks(monitorRunnable)
        overlayManager?.dismissOverlay()
    }

    override fun onDestroy() {
        super.onDestroy()
        accumulateSession()
        handler.removeCallbacks(monitorRunnable)
        overlayManager?.dismissOverlay()
    }
}

enum class AvatarStage { ZEN, IMPATIENT, FURIOUS }
