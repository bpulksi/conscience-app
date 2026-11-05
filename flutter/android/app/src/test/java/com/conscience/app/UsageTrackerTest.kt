package com.conscience.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class UsageTrackerTest {
    private val minute = 60_000L
    private val day = 24 * 60 * minute

    private class MemoryStore(var saved: UsageTracker.Saved? = null) : UsageTracker.Store {
        override fun load() = saved
        override fun save(saved: UsageTracker.Saved) {
            this.saved = saved
        }
    }

    private var clock = 10 * minute
    private val store = MemoryStore()

    private fun tracker() = UsageTracker(store, { clock }, { "day-${it / day}" })

    @Test
    fun countsOnlyTimeBetweenStartAndStop() {
        val t = tracker()
        t.start()
        clock += 5 * minute
        t.stop()
        clock += 30 * minute
        assertEquals(5 * minute, t.usedMs())
    }

    @Test
    fun includesARunningSession() {
        val t = tracker()
        t.start()
        clock += 3 * minute
        assertEquals(3 * minute, t.usedMs())
    }

    @Test
    fun startingTwiceDoesNotRestartTheSession() {
        val t = tracker()
        t.start()
        clock += 3 * minute
        t.start()
        clock += 2 * minute
        assertEquals(5 * minute, t.usedMs())
    }

    @Test
    fun usageAndEarnedTimeSurviveARestart() {
        val first = tracker()
        first.start()
        clock += 4 * minute
        first.stop()
        first.grant(10 * minute)

        val second = tracker()
        assertEquals(4 * minute, second.usedMs())
        assertEquals(10 * minute, second.bonusMs())
    }

    @Test
    fun earnedTimeAddsUp() {
        val t = tracker()
        t.grant(10 * minute)
        t.grant(20 * minute)
        assertEquals(30 * minute, t.bonusMs())
    }

    @Test
    fun aNewDayClearsUsageAndEarnedTime() {
        val t = tracker()
        t.start()
        clock += 5 * minute
        t.stop()
        t.grant(10 * minute)

        clock += day
        assertEquals(0L, t.usedMs())
        assertEquals(0L, t.bonusMs())
    }

    @Test
    fun aSessionAcrossMidnightOnlyCountsTowardTheNewDay() {
        val t = tracker()
        t.start()
        clock += day
        assertEquals(0L, t.usedMs())
        clock += 2 * minute
        assertEquals(2 * minute, t.usedMs())
    }

    @Test
    fun savedDataFromAnotherDayIsIgnored() {
        store.saved = UsageTracker.Saved("day-99", 50 * minute, 10 * minute)
        val t = tracker()
        assertEquals(0L, t.usedMs())
        assertEquals(0L, t.bonusMs())
    }

    @Test
    fun aClockMovedBackwardsNeverReducesUsage() {
        val t = tracker()
        t.start()
        clock += 5 * minute
        t.stop()
        t.start()
        clock -= 3 * minute
        assertEquals(5 * minute, t.usedMs())
    }

    @Test
    fun negativeGrantsAreIgnored() {
        val t = tracker()
        t.grant(-5 * minute)
        assertEquals(0L, t.bonusMs())
    }

    @Test
    fun resetClearsTodayAndRestartsARunningSession() {
        val t = tracker()
        t.start()
        clock += 5 * minute
        t.grant(10 * minute)
        t.resetToday()
        assertEquals(0L, t.usedMs())
        assertEquals(0L, t.bonusMs())
        clock += minute
        assertEquals(minute, t.usedMs())
    }

    @Test
    fun keyboardAndSystemWindowsDoNotCountAsLeaving() {
        assertTrue(isTransientWindow("com.android.systemui", null))
        assertTrue(isTransientWindow("android", null))
        assertTrue(isTransientWindow("com.google.android.inputmethod.latin", "com.google.android.inputmethod.latin"))
        assertFalse(isTransientWindow("com.google.android.apps.nexuslauncher", "com.google.android.inputmethod.latin"))
        assertFalse(isTransientWindow("com.conscience.app", null))
    }
}
