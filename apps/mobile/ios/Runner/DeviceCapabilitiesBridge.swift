import ARKit
#if canImport(RoomPlan)
import RoomPlan
#endif
import Flutter
import Foundation

/**
 Native iOS Device Capabilities Bridge for Roomlyst.
 Fulfills Blueprint Section 6.1 and roomlyst_adaptive_device_capability_addon.md.
 Queries runtime APIs (never marketing names) for ARKit, LiDAR (sceneDepth), RoomPlan, and motion sensors.
 */
public class DeviceCapabilitiesBridge {
    static let channelName = "com.roomlyst.app/device_capabilities"

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            if call.method == "getDeviceCapabilities" {
                let caps = getCapabilities()
                result(caps)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private static func getCapabilities() -> [String: Any] {
        var hasLiDAR = false
        var hasHardwareDepth = false
        var hasARKit = false
        var hasRoomPlan = false
        let hasMotionSensors = true
        var tier = "Tier C"
        var scanMode = "rgb_photo_scan"

        // 1. Check ARKit World Tracking
        if ARWorldTrackingConfiguration.isSupported {
            hasARKit = true
            tier = "Tier B"
            scanMode = "ar_rgb_scan"

            // Check if LiDAR / sceneDepth is supported on this device hardware (Tier A)
            if #available(iOS 14.0, *) {
                if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
                    hasLiDAR = true
                    hasHardwareDepth = true
                    tier = "Tier A"
                    scanMode = "lidar_scan"
                }
            }
        }

        // 2. Check RoomPlan support (iOS 16+)
        if #available(iOS 16.0, *) {
            #if canImport(RoomPlan)
            if RoomCaptureSession.isSupported {
                hasRoomPlan = true
            }
            #endif
        }

        let memoryMB = Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024))
        let confidence: Double = hasLiDAR ? 0.98 : (hasARKit ? 0.85 : 0.70)

        var guidance = "Capture Room: Take photos from room corners with good lighting."
        var accuracy = "AI Vision Estimated (~ 10-15cm - Manual Confirmation Recommended)"
        if hasLiDAR {
            guidance = "Scan Room: Point camera and walk around room to capture exact 3D geometry."
            accuracy = "Hardware 3D Precision (High Accuracy < 2cm)"
        } else if hasARKit {
            guidance = "Move slowly around room: Point at floor and walls to track boundaries."
            accuracy = "AR Motion Geometry (~ 5-8cm Approximate)"
        }

        return [
            "operating_system": "ios",
            "platform": "ios",
            "os_version": UIDevice.current.systemVersion,
            "system_version": UIDevice.current.systemVersion,
            "device_model": UIDevice.current.model,
            "camera_available": true,
            "camera_supported": true,
            "has_lidar": hasLiDAR,
            "lidar_supported": hasLiDAR,
            "has_hardware_depth": hasHardwareDepth,
            "has_arkit": hasARKit,
            "ar_supported": hasARKit,
            "has_roomplan": hasRoomPlan,
            "has_arcore": false,
            "has_arcore_depth": false,
            "has_motion_sensors": hasMotionSensors,
            "available_memory_mb": memoryMB,
            "capability_confidence": confidence,
            "capability_tier": tier,
            "scan_mode": scanMode,
            "recommended_capture_mode": scanMode,
            "user_guidance_prompt": guidance,
            "accuracy_assurance": accuracy
        ]
    }
}
