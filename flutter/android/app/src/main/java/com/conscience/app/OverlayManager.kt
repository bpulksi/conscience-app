package com.conscience.app

import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import com.airbnb.lottie.LottieAnimationView

/**
 * Overlay v2: the avatar plus a speech bubble.
 *
 * The overlay keeps FLAG_NOT_FOCUSABLE so it never steals the keyboard, and it
 * only speaks when [showStage] is called with a *new* stage — the avatar is
 * driven by events, not by a render loop.
 */
class OverlayManager(private val context: Context) {

    private var overlayView: View? = null
    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val handler = Handler(Looper.getMainLooper())

    private var persona: AvatarPersona =
        AvatarPersona.loadOrDefault(context, MessageEngine.selectedAvatarId(context))
    private var engine: MessageEngine = MessageEngine(persona, MessageEngine.prefs(context))

    private var lastStage: AvatarStage? = null
    private var currentAnimation: String? = null

    // Drag state
    private var initialX = 0; private var initialY = 0
    private var initialTouchX = 0f; private var initialTouchY = 0f
    private var movedBeyondSlop = false

    private val hideBubble = Runnable { bubble()?.visibility = View.GONE }

    /** Reload persona + engine after the Cast screen changes the selection. */
    fun refreshPersona() {
        persona = AvatarPersona.loadOrDefault(context, MessageEngine.selectedAvatarId(context))
        engine = MessageEngine(persona, MessageEngine.prefs(context))
        currentAnimation = null // force the next stage change to reload the animation
        lastStage?.let { updateAnimation(it) }
    }

    /** Backwards-compatible entry point: show the avatar in [stage] and let it speak. */
    fun showOverlay(stage: AvatarStage) = showStage(stage)

    fun showStage(stage: AvatarStage) {
        ensureView()
        val changed = stage != lastStage
        lastStage = stage
        updateAnimation(stage)
        if (changed) speak(stage)
    }

    private fun ensureView() {
        if (overlayView != null) return

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.END
            x = 24; y = 120
        }

        overlayView = LayoutInflater.from(context)
            .inflate(R.layout.overlay_avatar, null)
            .also { view ->
                setupTouchListener(view, params)
                windowManager.addView(view, params)
            }
    }

    private fun updateAnimation(stage: AvatarStage) {
        val lottie = overlayView?.findViewById<LottieAnimationView>(R.id.avatar_lottie) ?: return
        // A persona may name artwork that isn't shipped yet, so fall back to the
        // brain animation for the same stage rather than always showing zen.
        val wanted = persona.animationFor(stage)
        val exists = runCatching {
            context.assets.open(wanted).close()
            true
        }.getOrDefault(false)
        val resolved = if (exists) wanted else AvatarPersona.fallbackAnimation(stage)
        if (currentAnimation == resolved) return
        currentAnimation = resolved
        runCatching {
            lottie.setAnimation(resolved)
            lottie.playAnimation()
        }
        if (!exists) {
            // Persona ships a Lottie slot but no artwork yet — the bubble still works,
            // so the personality is testable before the animations are commissioned.
            android.util.Log.w("Conscience", "Missing animation $wanted, fell back to $resolved")
        }
    }

    private fun speak(stage: AvatarStage) {
        val line = engine.nextLine(stage) ?: return
        showBubble(line)
    }

    private fun showBubble(text: String) {
        val view = bubble() ?: return
        view.text = text
        view.visibility = View.VISIBLE
        handler.removeCallbacks(hideBubble)
        handler.postDelayed(hideBubble, persona.bubbleSeconds * 1000L)
    }

    private fun bubble(): TextView? = overlayView?.findViewById(R.id.avatar_bubble)

    private fun setupTouchListener(view: View, params: WindowManager.LayoutParams) {
        val dragArea = view.findViewById<View>(R.id.avatar_drag_area) ?: view
        val slop = 12f

        dragArea.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x; initialY = params.y
                    initialTouchX = event.rawX; initialTouchY = event.rawY
                    movedBeyondSlop = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - initialTouchX
                    val dy = event.rawY - initialTouchY
                    if (kotlin.math.abs(dx) > slop || kotlin.math.abs(dy) > slop) {
                        movedBeyondSlop = true
                    }
                    if (movedBeyondSlop) {
                        params.x = initialX + dx.toInt()
                        params.y = initialY - dy.toInt()
                        runCatching { windowManager.updateViewLayout(view, params) }
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!movedBeyondSlop) {
                        // Tap = mute for 30 minutes. Never nagging wallpaper.
                        engine.muteFor()
                        showBubble("Muted for 30 minutes.")
                    }
                    true
                }
                else -> false
            }
        }
    }

    fun dismissOverlay() {
        handler.removeCallbacks(hideBubble)
        overlayView?.let {
            runCatching { windowManager.removeView(it) }
            overlayView = null
            currentAnimation = null
            lastStage = null
        }
    }
}
