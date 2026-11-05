package com.conscience.app

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.TextView

/**
 * Full-screen block shown over a vice app at the daily limit. The way past it
 * is to earn time in Recharge. Pressing Home still works, but reopening the app
 * blocks again straight away.
 */
class BlockActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_block)

        findViewById<Button>(R.id.btn_recharge).setOnClickListener {
            val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                putExtra(MainActivity.EXTRA_DEEP_LINK, MainActivity.DEEP_LINK_RECHARGE)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            if (intent != null) startActivity(intent)
            finish()
        }

        val prefs = getSharedPreferences(MainActivity.PREFS_SETTINGS, MODE_PRIVATE)
        val toughLove = prefs.getBoolean(MainActivity.KEY_TOUGH_LOVE, false)
        findViewById<TextView>(R.id.tv_message).text = if (toughLove) {
            "Your Conscience has had enough.\nEarn your time back."
        } else {
            "You've hit your limit for today.\nA short break earns more time."
        }
    }

    // Back would return straight to the blocked app.
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() { /* no-op */ }
}
