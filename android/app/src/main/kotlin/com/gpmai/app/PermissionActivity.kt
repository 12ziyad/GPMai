package com.gpmai.app

import android.app.Activity
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Bundle
import android.util.Log

class PermissionActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("OrbProjection", "PermissionActivity created")
        try {
            val mgr = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            Log.d("OrbProjection", "starting createScreenCaptureIntent")
            startActivityForResult(mgr.createScreenCaptureIntent(), REQ)
        } catch (e: Exception) {
            Log.e("OrbProjection", "createScreenCaptureIntent failed: ${e.message}")
            broadcast(RESULT_CANCELED, null)
            finish()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        Log.d("OrbProjection", "onActivityResult resultCode=$resultCode dataNull=${data == null}")
        if (requestCode == REQ) {
            broadcast(resultCode, data)
        }
        finish()
    }

    private fun broadcast(resultCode: Int, data: Intent?) {
        Log.d("OrbProjection", "broadcasting GPM_SCREEN_PROJECTION_RESULT resultCode=$resultCode")
        val out = Intent("GPM_SCREEN_PROJECTION_RESULT").apply {
            putExtra("resultCode", resultCode)
            if (data != null) putExtra("data", data)
        }
        sendBroadcast(out)
    }

    companion object {
        private const val REQ = 1001
    }
}
