package com.example.root_wallet

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.WindowManager

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "root_wallet/screen_protection"
        ).setMethodCallHandler { call, result ->
            if (call.method != "setProtected") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val enabled = call.argument<Boolean>("enabled") ?: false
            if (enabled) {
                window.setFlags(
                    WindowManager.LayoutParams.FLAG_SECURE,
                    WindowManager.LayoutParams.FLAG_SECURE
                )
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
            result.success(true)
        }
    }
}
