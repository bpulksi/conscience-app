package com.conscience.app

import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import com.airbnb.lottie.LottieAnimationView

class OverlayManager(private val context: Context) {

    private var overlayView: View? = null
    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

    // Track drag position so user can reposition the avatar
    private var initialX = 0; private var initialY = 0
    private var initialTouchX = 0f; private var initialTouchY = 0f

    fun showOverlay(stage: AvatarStage) {
        if (overlayView != null) {
            updateAnimation(stage)
            return
        }

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
                setupDragListener(view, params)
                windowManager.addView(view, params)
                updateAnimation(stage)
            }
    }

    private fun updateAnimation(stage: AvatarStage) {
        val lottie = overlayView?.findViewById<LottieAnimationView>(R.id.avatar_lottie) ?: return
        val assetName = when (stage) {
            AvatarStage.ZEN -> "avatars/brain/zen.json"
            AvatarStage.IMPATIENT -> "avatars/brain/impatient.json"
            AvatarStage.FURIOUS -> "avatars/brain/furious.json"
        }
        if (lottie.animationResName != assetName) {
            lottie.setAnimation(assetName)
            lottie.playAnimation()
        }
    }

    private fun setupDragListener(view: View, params: WindowManager.LayoutParams) {
        view.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x; initialY = params.y
                    initialTouchX = event.rawX; initialTouchY = event.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    params.x = initialX + (event.rawX - initialTouchX).toInt()
                    params.y = initialY - (event.rawY - initialTouchY).toInt()
                    windowManager.updateViewLayout(view, params)
                    true
                }
                else -> false
            }
        }
    }

    fun dismissOverlay() {
        overlayView?.let {
            windowManager.removeView(it)
            overlayView = null
        }
    }
}
