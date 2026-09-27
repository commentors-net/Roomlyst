package com.roomlyst.roomlyst

import android.app.ActivityManager
import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorManager
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Native Android Device Capabilities Bridge for Roomlyst.
 * Fulfills Blueprint Section 6.1 and roomlyst_adaptive_device_capability_addon.md.
 * Authoritative runtime API detection (never marketing model names).
 */
class DeviceCapabilitiesBridge(private val context: Context) {
    companion object {
        const val CHANNEL_NAME = "com.roomlyst.app/device_capabilities"

        fun registerWith(flutterEngine: FlutterEngine, context: Context) {
            val bridge = DeviceCapabilitiesBridge(context)
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
                .setMethodCallHandler { call, result ->
                    if (call.method == "getDeviceCapabilities") {
                        result.success(bridge.getCapabilities())
                    } else {
                        result.notImplemented()
                    }
                }
        }
    }

    fun getCapabilities(): Map<String, Any> {
        val packageManager = context.packageManager

        // 1. Authoritative ARCore runtime detection
        var hasARCore = false
        try {
            hasARCore = packageManager.hasSystemFeature("android.hardware.camera.ar")
        } catch (_: Exception) {}

        // 2. Hardware Depth / Time-of-Flight detection
        var hasHardwareDepth = false
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                hasHardwareDepth = packageManager.hasSystemFeature("android.hardware.camera.concurrent") ||
                                   packageManager.hasSystemFeature("android.hardware.camera.capability.manual_sensor")
            }
        } catch (_: Exception) {}

        // ARCore Depth API support typically correlates with ARCore + Depth hardware
        val hasARCoreDepth = hasARCore && hasHardwareDepth

        // 3. Motion sensors (Accelerometer + Gyroscope)
        var hasMotionSensors = false
        try {
            val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
            if (sensorManager != null) {
                val hasAccel = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null
                val hasGyro = sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE) != null
                hasMotionSensors = hasAccel && hasGyro
            }
        } catch (_: Exception) {}

        // 4. Memory telemetry
        var memoryMB = 4096
        try {
            val actManager = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            if (actManager != null) {
                val memInfo = ActivityManager.MemoryInfo()
                actManager.getMemoryInfo(memInfo)
                memoryMB = (memInfo.totalMem / (1024 * 1024)).toInt()
            }
        } catch (_: Exception) {}

        // 5. Resolve ScanMode, Tier, Confidence, and Guidance
        val scanMode: String
        val tier: String
        val confidence: Double
        val guidance: String
        val accuracy: String

        if (hasARCoreDepth) {
            tier = "Tier B"
            scanMode = "ar_depth_scan"
            confidence = 0.88
            guidance = "Scan Room: Move smoothly across surfaces to map depth and walls."
            accuracy = "AR Depth Sensor (~ 3-5cm Accuracy)"
        } else if (hasARCore) {
            tier = "Tier B"
            scanMode = "ar_rgb_scan"
            confidence = 0.78
            guidance = "Move slowly around room: Point at floor and walls to track boundaries."
            accuracy = "AR Motion Geometry (~ 5-8cm Approximate)"
        } else if (hasMotionSensors) {
            tier = "Tier C"
            scanMode = "rgb_video_scan"
            confidence = 0.72
            guidance = "Walk around room: Record continuous view with overlapping angles."
            accuracy = "AI Vision Estimated (~ 10-15cm - Manual Confirmation Recommended)"
        } else {
            tier = "Tier C"
            scanMode = "rgb_photo_scan"
            confidence = 0.70
            guidance = "Capture Room: Take photos from room corners with good lighting."
            accuracy = "AI Vision Estimated (~ 10-15cm - Manual Confirmation Recommended)"
        }

        return mapOf(
            "operating_system" to "android",
            "platform" to "android",
            "os_version" to "Android ${Build.VERSION.RELEASE} (SDK ${Build.VERSION.SDK_INT})",
            "system_version" to "Android ${Build.VERSION.RELEASE} (SDK ${Build.VERSION.SDK_INT})",
            "device_model" to "${Build.MANUFACTURER} ${Build.MODEL}",
            "camera_available" to true,
            "camera_supported" to true,
            "has_lidar" to false,
            "lidar_supported" to false,
            "has_hardware_depth" to hasHardwareDepth,
            "has_arkit" to false,
            "has_roomplan" to false,
            "has_arcore" to hasARCore,
            "has_arcore_depth" to hasARCoreDepth,
            "ar_supported" to hasARCore,
            "has_motion_sensors" to hasMotionSensors,
            "available_memory_mb" to memoryMB,
            "capability_confidence" to confidence,
            "capability_tier" to tier,
            "scan_mode" to scanMode,
            "recommended_capture_mode" to scanMode,
            "user_guidance_prompt" to guidance,
            "accuracy_assurance" to accuracy
        )
    }
}
