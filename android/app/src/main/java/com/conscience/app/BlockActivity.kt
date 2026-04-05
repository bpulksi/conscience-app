package com.conscience.app

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.TextView

/**
 * Full-screen block activity shown when user exceeds their daily limit.
 * Launched by ConscienceAccessibilityService over the vice app.
 */
class BlockActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_block)

        findViewById<Button>(R.id.btn_recharge).setOnClickListener {
            // Open main app on Recharge Hub tab
            val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                putExtra("deeplink", "rechargeHub")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            startActivity(intent)
            finish()
        }

        findViewById<Button>(R.id.btn_ask_friend).setOnClickListener {
            val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                putExtra("deeplink", "askFriend")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            startActivity(intent)
            finish()
        }

        // Show tone-appropriate message
        val prefs = getSharedPreferences("conscience_prefs", MODE_PRIVATE)
        val isToughLove = prefs.getBoolean("toughLove", true)
        findViewById<TextView>(R.id.tv_message).text = if (isToughLove) {
            "Your Conscience has had enough.\nClose the app. Now."
        } else {
            "Hey, you've hit your limit for today.\nHow about a quick break?"
        }
    }

    // Prevent back button from returning to vice app
    override fun onBackPressed() { /* no-op */ }
}
