package com.gpmai.app

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.view.accessibility.AccessibilityEvent

/**
 * Minimal placeholder so release build compiles.
 * TODO: Implement real screen reading / navigation later if you need it.
 */
class GPMaiAccessibilityService : AccessibilityService() {

    override fun onServiceConnected() {
        super.onServiceConnected()
        current = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) { /* no-op */ }

    override fun onInterrupt() { /* no-op */ }

    companion object {
        // Keep a static reference
        @JvmStatic private var current: GPMaiAccessibilityService? = null

        // ---- The app expects a FUNCTION named instance() ----
        @JvmStatic fun instance(): GPMaiAccessibilityService? = current

        // ---- Stubs used by OrbService.kt ----
        @JvmStatic fun readVisibleScreenText(): String = ""
        @JvmStatic fun readVisibleScreenText(maxLen: Int): String = ""
        @JvmStatic fun readVisibleScreenText(ctx: Context?): String = readVisibleScreenText()
        @JvmStatic fun readVisibleScreenText(ctx: Context?, maxLen: Int): String = readVisibleScreenText(maxLen)

        @JvmStatic fun getTopAppName(): String = ""
        @JvmStatic fun getTopAppName(ctx: Context?): String = getTopAppName()

        @JvmStatic fun getTopAppPackage(): String = ""
        @JvmStatic fun getTopAppPackage(ctx: Context?): String = getTopAppPackage()

        @JvmStatic fun goHome() {}
        @JvmStatic fun goHome(ctx: Context?) { goHome() }

        @JvmStatic fun goBack() {}
        @JvmStatic fun goBack(ctx: Context?) { goBack() }
    }
}
