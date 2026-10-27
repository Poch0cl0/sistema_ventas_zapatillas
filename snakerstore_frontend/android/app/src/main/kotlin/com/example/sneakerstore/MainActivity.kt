package com.example.sneakerstore

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.Manifest
import android.content.pm.PackageManager

class MainActivity : FlutterActivity() {
    private var pendingCamera: MethodChannel.Result? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sneakerstore/camera_permission")
            .setMethodCallHandler { call, result ->
                if (call.method != "request") { result.notImplemented(); return@setMethodCallHandler }
                if (checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
                    result.success(true)
                } else if (pendingCamera != null) {
                    result.success(false)
                } else {
                    pendingCamera = result
                    requestPermissions(arrayOf(Manifest.permission.CAMERA), 7401)
                }
            }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 7401) {
            pendingCamera?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            pendingCamera = null
        }
    }
    override fun onDestroy() {
        pendingCamera?.success(false)
        pendingCamera = null
        super.onDestroy()
    }
}
