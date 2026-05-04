package com.gpmai.app

import android.app.Activity
import android.os.Bundle

// Minimal placeholder used by OrbService to request permissions.
// TODO: Port your real MediaProjection consent flow here later.
class PermissionActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        finish() // no-op for now
    }
}
