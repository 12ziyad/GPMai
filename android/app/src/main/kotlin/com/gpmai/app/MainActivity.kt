package com.gpmai.app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "gpmai/orb_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "startOrb" -> {
                        if (!Settings.canDrawOverlays(this)) {
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    Uri.parse("package:$packageName")
                                )
                            )
                            result.error("NO_OVERLAY", "Overlay permission required", null)
                            return@setMethodCallHandler
                        }

                        val svc = Intent(this, OrbService::class.java)
                        startService(svc) // NOT foreground here — OrbService handles it safely
                        result.success(true)
                    }

                    "stopOrb" -> {
                        stopService(Intent(this, OrbService::class.java))
                        result.success(true)
                    }

                    "isOrbRunning", "orbRunning", "is_orb_running" -> {
                        result.success(OrbService.isActive)
                    }

                    "updateMood" -> {
                        val mood = call.arguments as? String ?: "neutral"
                        Log.d("GPMai", "updateMood($mood)")
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
