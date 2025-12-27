package dev.agixt.agixt

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.net.wifi.WifiManager
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.view.KeyEvent
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.ContentResolver
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.app.KeyguardManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * DeviceControlHandler provides comprehensive device control capabilities
 * including media playback, volume, brightness, system toggles, and more.
 * These are the capabilities enabled by being a digital assistant.
 */
class DeviceControlHandler(
    private val context: Context,
    private val binaryMessenger: BinaryMessenger
) {
    companion object {
        private const val TAG = "DeviceControlHandler"
        private const val CHANNEL = "dev.agixt.agixt/device_control"
    }
    
    private var methodChannel: MethodChannel? = null
    private var cameraManager: CameraManager? = null
    private var cameraId: String? = null
    private var isFlashlightOn = false
    
    fun initialize() {
        methodChannel = MethodChannel(binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                // Flashlight control
                "setFlashlight" -> {
                    val enable = call.argument<Boolean>("enable") ?: true
                    setFlashlight(enable, result)
                }
                
                // Battery status
                "getBatteryStatus" -> {
                    getBatteryStatus(result)
                }
                
                // Media controls
                "mediaControl" -> {
                    val action = call.argument<String>("action") ?: "play_pause"
                    mediaControl(action, result)
                }
                "getMediaInfo" -> {
                    getMediaInfo(result)
                }
                
                // Volume controls
                "setVolume" -> {
                    val level = call.argument<Int>("level") ?: 50
                    val stream = call.argument<String>("stream") ?: "media"
                    setVolume(level, stream, result)
                }
                "getVolume" -> {
                    val stream = call.argument<String>("stream") ?: "media"
                    getVolume(stream, result)
                }
                "adjustVolume" -> {
                    val direction = call.argument<String>("direction") ?: "up"
                    val stream = call.argument<String>("stream") ?: "media"
                    adjustVolume(direction, stream, result)
                }
                
                // Ringer mode
                "setRingerMode" -> {
                    val mode = call.argument<String>("mode") ?: "normal"
                    setRingerMode(mode, result)
                }
                "getRingerMode" -> {
                    getRingerMode(result)
                }
                
                // Brightness controls
                "setBrightness" -> {
                    val level = call.argument<Int>("level") ?: 50
                    setBrightness(level, result)
                }
                "getBrightness" -> {
                    getBrightness(result)
                }
                
                // WiFi controls
                "toggleWifi" -> {
                    val enable = call.argument<Boolean>("enable")
                    toggleWifi(enable, result)
                }
                "getWifiStatus" -> {
                    getWifiStatus(result)
                }
                
                // Bluetooth controls
                "toggleBluetooth" -> {
                    val enable = call.argument<Boolean>("enable")
                    toggleBluetooth(enable, result)
                }
                "getBluetoothStatus" -> {
                    getBluetoothStatus(result)
                }
                
                // Do Not Disturb
                "setDoNotDisturb" -> {
                    val enable = call.argument<Boolean>("enable") ?: true
                    setDoNotDisturb(enable, result)
                }
                "getDoNotDisturbStatus" -> {
                    getDoNotDisturbStatus(result)
                }
                
                // Screen controls
                "wakeScreen" -> {
                    wakeScreen(result)
                }
                "isScreenOn" -> {
                    isScreenOn(result)
                }
                
                // System info
                "getSystemInfo" -> {
                    getSystemInfo(result)
                }
                
                else -> result.notImplemented()
            }
        }
        
        // Initialize camera manager for flashlight
        try {
            cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            cameraId = cameraManager?.cameraIdList?.firstOrNull { id ->
                cameraManager?.getCameraCharacteristics(id)
                    ?.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize camera manager: ${e.message}")
        }
        
        Log.d(TAG, "DeviceControlHandler initialized")
    }
    
    fun destroy() {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
    }
    
    // ==================== Flashlight ====================
    
    private fun setFlashlight(enable: Boolean, result: MethodChannel.Result) {
        try {
            if (cameraManager == null || cameraId == null) {
                result.error("UNAVAILABLE", "Flashlight not available on this device", null)
                return
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                cameraManager?.setTorchMode(cameraId!!, enable)
                isFlashlightOn = enable
                result.success(mapOf(
                    "success" to true,
                    "enabled" to enable
                ))
            } else {
                result.error("UNSUPPORTED", "Flashlight control requires Android 6.0+", null)
            }
        } catch (e: CameraAccessException) {
            result.error("CAMERA_ERROR", "Failed to control flashlight: ${e.message}", null)
        }
    }
    
    // ==================== Battery ====================
    
    private fun getBatteryStatus(result: MethodChannel.Result) {
        try {
            val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            
            val level = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            val isCharging = batteryManager.isCharging
            val chargePlugged = when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.O -> {
                    when (batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_STATUS)) {
                        BatteryManager.BATTERY_STATUS_CHARGING -> "charging"
                        BatteryManager.BATTERY_STATUS_FULL -> "full"
                        BatteryManager.BATTERY_STATUS_DISCHARGING -> "discharging"
                        BatteryManager.BATTERY_STATUS_NOT_CHARGING -> "not_charging"
                        else -> "unknown"
                    }
                }
                else -> if (isCharging) "charging" else "discharging"
            }
            
            result.success(mapOf(
                "level" to level,
                "isCharging" to isCharging,
                "status" to chargePlugged
            ))
        } catch (e: Exception) {
            result.error("BATTERY_ERROR", "Failed to get battery status: ${e.message}", null)
        }
    }
    
    // ==================== Media Controls ====================
    
    private fun mediaControl(action: String, result: MethodChannel.Result) {
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            
            val keyCode = when (action.lowercase()) {
                "play", "resume" -> KeyEvent.KEYCODE_MEDIA_PLAY
                "pause" -> KeyEvent.KEYCODE_MEDIA_PAUSE
                "play_pause", "toggle" -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
                "next", "skip" -> KeyEvent.KEYCODE_MEDIA_NEXT
                "previous", "prev" -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
                "stop" -> KeyEvent.KEYCODE_MEDIA_STOP
                "fast_forward", "ff" -> KeyEvent.KEYCODE_MEDIA_FAST_FORWARD
                "rewind", "rw" -> KeyEvent.KEYCODE_MEDIA_REWIND
                else -> {
                    result.error("INVALID_ACTION", "Unknown media action: $action", null)
                    return
                }
            }
            
            // Send key down and key up events
            val eventDown = KeyEvent(KeyEvent.ACTION_DOWN, keyCode)
            val eventUp = KeyEvent(KeyEvent.ACTION_UP, keyCode)
            
            audioManager.dispatchMediaKeyEvent(eventDown)
            audioManager.dispatchMediaKeyEvent(eventUp)
            
            result.success(mapOf(
                "success" to true,
                "action" to action
            ))
        } catch (e: Exception) {
            result.error("MEDIA_ERROR", "Failed to control media: ${e.message}", null)
        }
    }
    
    private fun getMediaInfo(result: MethodChannel.Result) {
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val isMusicActive = audioManager.isMusicActive
            
            // Basic info we can always get
            val info = mutableMapOf<String, Any>(
                "isMusicActive" to isMusicActive
            )
            
            // Try to get more info from MediaSessionManager (requires notification listener access)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                try {
                    val mediaSessionManager = context.getSystemService(Context.MEDIA_SESSION_SERVICE) as? MediaSessionManager
                    val controllers = mediaSessionManager?.getActiveSessions(null)
                    
                    if (!controllers.isNullOrEmpty()) {
                        val controller = controllers[0]
                        val metadata = controller.metadata
                        val playbackState = controller.playbackState
                        
                        info["packageName"] = controller.packageName ?: "unknown"
                        info["playbackState"] = when (playbackState?.state) {
                            android.media.session.PlaybackState.STATE_PLAYING -> "playing"
                            android.media.session.PlaybackState.STATE_PAUSED -> "paused"
                            android.media.session.PlaybackState.STATE_STOPPED -> "stopped"
                            android.media.session.PlaybackState.STATE_BUFFERING -> "buffering"
                            else -> "unknown"
                        }
                        
                        metadata?.let { meta ->
                            info["title"] = meta.getString(android.media.MediaMetadata.METADATA_KEY_TITLE) ?: ""
                            info["artist"] = meta.getString(android.media.MediaMetadata.METADATA_KEY_ARTIST) ?: ""
                            info["album"] = meta.getString(android.media.MediaMetadata.METADATA_KEY_ALBUM) ?: ""
                            info["duration"] = meta.getLong(android.media.MediaMetadata.METADATA_KEY_DURATION)
                        }
                    }
                } catch (e: SecurityException) {
                    // Notification listener access not granted
                    Log.d(TAG, "Cannot get media metadata - notification listener access required")
                }
            }
            
            result.success(info)
        } catch (e: Exception) {
            result.error("MEDIA_ERROR", "Failed to get media info: ${e.message}", null)
        }
    }
    
    // ==================== Volume Controls ====================
    
    private fun getAudioStream(stream: String): Int {
        return when (stream.lowercase()) {
            "music", "media" -> AudioManager.STREAM_MUSIC
            "ring", "ringtone" -> AudioManager.STREAM_RING
            "notification" -> AudioManager.STREAM_NOTIFICATION
            "alarm" -> AudioManager.STREAM_ALARM
            "voice", "call" -> AudioManager.STREAM_VOICE_CALL
            "system" -> AudioManager.STREAM_SYSTEM
            "dtmf" -> AudioManager.STREAM_DTMF
            else -> AudioManager.STREAM_MUSIC
        }
    }
    
    private fun setVolume(level: Int, stream: String, result: MethodChannel.Result) {
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val audioStream = getAudioStream(stream)
            val maxVolume = audioManager.getStreamMaxVolume(audioStream)
            
            // Convert percentage (0-100) to actual volume level
            val targetVolume = (level.coerceIn(0, 100) * maxVolume) / 100
            
            audioManager.setStreamVolume(audioStream, targetVolume, 0)
            
            result.success(mapOf(
                "success" to true,
                "stream" to stream,
                "level" to level,
                "actualLevel" to targetVolume,
                "maxLevel" to maxVolume
            ))
        } catch (e: Exception) {
            result.error("VOLUME_ERROR", "Failed to set volume: ${e.message}", null)
        }
    }
    
    private fun getVolume(stream: String, result: MethodChannel.Result) {
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val audioStream = getAudioStream(stream)
            
            val currentVolume = audioManager.getStreamVolume(audioStream)
            val maxVolume = audioManager.getStreamMaxVolume(audioStream)
            val percentage = if (maxVolume > 0) (currentVolume * 100) / maxVolume else 0
            
            result.success(mapOf(
                "stream" to stream,
                "level" to percentage,
                "currentLevel" to currentVolume,
                "maxLevel" to maxVolume,
                "isMuted" to (currentVolume == 0)
            ))
        } catch (e: Exception) {
            result.error("VOLUME_ERROR", "Failed to get volume: ${e.message}", null)
        }
    }
    
    private fun adjustVolume(direction: String, stream: String, result: MethodChannel.Result) {
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val audioStream = getAudioStream(stream)
            
            val adjustDirection = when (direction.lowercase()) {
                "up", "raise", "increase" -> AudioManager.ADJUST_RAISE
                "down", "lower", "decrease" -> AudioManager.ADJUST_LOWER
                "mute" -> AudioManager.ADJUST_MUTE
                "unmute" -> AudioManager.ADJUST_UNMUTE
                "toggle_mute" -> AudioManager.ADJUST_TOGGLE_MUTE
                else -> AudioManager.ADJUST_SAME
            }
            
            audioManager.adjustStreamVolume(audioStream, adjustDirection, 0)
            
            // Get the new volume level
            val currentVolume = audioManager.getStreamVolume(audioStream)
            val maxVolume = audioManager.getStreamMaxVolume(audioStream)
            val percentage = if (maxVolume > 0) (currentVolume * 100) / maxVolume else 0
            
            result.success(mapOf(
                "success" to true,
                "stream" to stream,
                "direction" to direction,
                "newLevel" to percentage
            ))
        } catch (e: Exception) {
            result.error("VOLUME_ERROR", "Failed to adjust volume: ${e.message}", null)
        }
    }
    
    // ==================== Ringer Mode ====================
    
    private fun setRingerMode(mode: String, result: MethodChannel.Result) {
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            
            val ringerMode = when (mode.lowercase()) {
                "normal", "ring" -> AudioManager.RINGER_MODE_NORMAL
                "vibrate" -> AudioManager.RINGER_MODE_VIBRATE
                "silent", "mute" -> AudioManager.RINGER_MODE_SILENT
                else -> {
                    result.error("INVALID_MODE", "Unknown ringer mode: $mode", null)
                    return
                }
            }
            
            audioManager.ringerMode = ringerMode
            
            result.success(mapOf(
                "success" to true,
                "mode" to mode
            ))
        } catch (e: SecurityException) {
            result.error("PERMISSION_ERROR", "Do Not Disturb access required", null)
        } catch (e: Exception) {
            result.error("RINGER_ERROR", "Failed to set ringer mode: ${e.message}", null)
        }
    }
    
    private fun getRingerMode(result: MethodChannel.Result) {
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            
            val mode = when (audioManager.ringerMode) {
                AudioManager.RINGER_MODE_NORMAL -> "normal"
                AudioManager.RINGER_MODE_VIBRATE -> "vibrate"
                AudioManager.RINGER_MODE_SILENT -> "silent"
                else -> "unknown"
            }
            
            result.success(mapOf(
                "mode" to mode
            ))
        } catch (e: Exception) {
            result.error("RINGER_ERROR", "Failed to get ringer mode: ${e.message}", null)
        }
    }
    
    // ==================== Brightness ====================
    
    private fun setBrightness(level: Int, result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (!Settings.System.canWrite(context)) {
                    // Request write settings permission
                    val intent = Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS)
                    intent.data = android.net.Uri.parse("package:${context.packageName}")
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                    result.error("PERMISSION_REQUIRED", "Please grant WRITE_SETTINGS permission", null)
                    return
                }
            }
            
            // Convert 0-100 to 0-255
            val brightnessValue = (level.coerceIn(0, 100) * 255) / 100
            
            // Disable auto-brightness first
            Settings.System.putInt(
                context.contentResolver,
                Settings.System.SCREEN_BRIGHTNESS_MODE,
                Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL
            )
            
            // Set brightness
            Settings.System.putInt(
                context.contentResolver,
                Settings.System.SCREEN_BRIGHTNESS,
                brightnessValue
            )
            
            result.success(mapOf(
                "success" to true,
                "level" to level
            ))
        } catch (e: Exception) {
            result.error("BRIGHTNESS_ERROR", "Failed to set brightness: ${e.message}", null)
        }
    }
    
    private fun getBrightness(result: MethodChannel.Result) {
        try {
            val brightness = Settings.System.getInt(
                context.contentResolver,
                Settings.System.SCREEN_BRIGHTNESS,
                128
            )
            
            val isAuto = Settings.System.getInt(
                context.contentResolver,
                Settings.System.SCREEN_BRIGHTNESS_MODE,
                Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL
            ) == Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC
            
            // Convert 0-255 to 0-100
            val percentage = (brightness * 100) / 255
            
            result.success(mapOf(
                "level" to percentage,
                "rawLevel" to brightness,
                "isAutomatic" to isAuto
            ))
        } catch (e: Exception) {
            result.error("BRIGHTNESS_ERROR", "Failed to get brightness: ${e.message}", null)
        }
    }
    
    // ==================== WiFi ====================
    
    private fun toggleWifi(enable: Boolean?, result: MethodChannel.Result) {
        try {
            // On Android Q+, apps can't directly toggle WiFi
            // We need to open settings instead
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val intent = Intent(Settings.Panel.ACTION_WIFI)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                result.success(mapOf(
                    "success" to true,
                    "message" to "Opening WiFi settings panel"
                ))
            } else {
                @Suppress("DEPRECATION")
                val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                val currentState = wifiManager.isWifiEnabled
                val newState = enable ?: !currentState
                
                @Suppress("DEPRECATION")
                wifiManager.isWifiEnabled = newState
                
                result.success(mapOf(
                    "success" to true,
                    "enabled" to newState
                ))
            }
        } catch (e: SecurityException) {
            result.error("PERMISSION_ERROR", "WiFi control permission denied", null)
        } catch (e: Exception) {
            result.error("WIFI_ERROR", "Failed to toggle WiFi: ${e.message}", null)
        }
    }
    
    private fun getWifiStatus(result: MethodChannel.Result) {
        try {
            val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val connectionInfo = wifiManager.connectionInfo
            
            result.success(mapOf<String, Any>(
                "enabled" to wifiManager.isWifiEnabled,
                "connected" to (connectionInfo.networkId != -1),
                "ssid" to (connectionInfo.ssid?.replace("\"", "") ?: "unknown"),
                "signalStrength" to WifiManager.calculateSignalLevel(connectionInfo.rssi, 5)
            ))
        } catch (e: Exception) {
            result.error("WIFI_ERROR", "Failed to get WiFi status: ${e.message}", null)
        }
    }
    
    // ==================== Bluetooth ====================
    
    private fun toggleBluetooth(enable: Boolean?, result: MethodChannel.Result) {
        try {
            val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            val bluetoothAdapter = bluetoothManager.adapter
            
            if (bluetoothAdapter == null) {
                result.error("UNAVAILABLE", "Bluetooth not available on this device", null)
                return
            }
            
            // On Android S+, apps can't directly enable/disable Bluetooth
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                result.success(mapOf(
                    "success" to true,
                    "message" to "Opening Bluetooth settings"
                ))
            } else {
                val currentState = bluetoothAdapter.isEnabled
                val newState = enable ?: !currentState
                
                @Suppress("DEPRECATION")
                if (newState) {
                    bluetoothAdapter.enable()
                } else {
                    bluetoothAdapter.disable()
                }
                
                result.success(mapOf(
                    "success" to true,
                    "enabled" to newState
                ))
            }
        } catch (e: SecurityException) {
            result.error("PERMISSION_ERROR", "Bluetooth permission denied", null)
        } catch (e: Exception) {
            result.error("BLUETOOTH_ERROR", "Failed to toggle Bluetooth: ${e.message}", null)
        }
    }
    
    private fun getBluetoothStatus(result: MethodChannel.Result) {
        try {
            val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            val bluetoothAdapter = bluetoothManager.adapter
            
            if (bluetoothAdapter == null) {
                result.success(mapOf(
                    "available" to false,
                    "enabled" to false
                ))
                return
            }
            
            result.success(mapOf(
                "available" to true,
                "enabled" to bluetoothAdapter.isEnabled,
                "name" to (bluetoothAdapter.name ?: "unknown"),
                "address" to (bluetoothAdapter.address ?: "unknown")
            ))
        } catch (e: SecurityException) {
            result.error("PERMISSION_ERROR", "Bluetooth permission denied", null)
        } catch (e: Exception) {
            result.error("BLUETOOTH_ERROR", "Failed to get Bluetooth status: ${e.message}", null)
        }
    }
    
    // ==================== Do Not Disturb ====================
    
    private fun setDoNotDisturb(enable: Boolean, result: MethodChannel.Result) {
        try {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (!notificationManager.isNotificationPolicyAccessGranted) {
                    // Request DND access
                    val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                    result.error("PERMISSION_REQUIRED", "Please grant Do Not Disturb access", null)
                    return
                }
                
                val filterMode = if (enable) {
                    NotificationManager.INTERRUPTION_FILTER_PRIORITY
                } else {
                    NotificationManager.INTERRUPTION_FILTER_ALL
                }
                
                notificationManager.setInterruptionFilter(filterMode)
                
                result.success(mapOf(
                    "success" to true,
                    "enabled" to enable
                ))
            } else {
                result.error("UNSUPPORTED", "Do Not Disturb requires Android 6.0+", null)
            }
        } catch (e: Exception) {
            result.error("DND_ERROR", "Failed to set Do Not Disturb: ${e.message}", null)
        }
    }
    
    private fun getDoNotDisturbStatus(result: MethodChannel.Result) {
        try {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val filter = notificationManager.currentInterruptionFilter
                val isEnabled = filter != NotificationManager.INTERRUPTION_FILTER_ALL
                
                val mode = when (filter) {
                    NotificationManager.INTERRUPTION_FILTER_ALL -> "off"
                    NotificationManager.INTERRUPTION_FILTER_PRIORITY -> "priority"
                    NotificationManager.INTERRUPTION_FILTER_ALARMS -> "alarms_only"
                    NotificationManager.INTERRUPTION_FILTER_NONE -> "total_silence"
                    else -> "unknown"
                }
                
                result.success(mapOf(
                    "enabled" to isEnabled,
                    "mode" to mode,
                    "hasAccess" to notificationManager.isNotificationPolicyAccessGranted
                ))
            } else {
                result.success(mapOf(
                    "enabled" to false,
                    "mode" to "unsupported"
                ))
            }
        } catch (e: Exception) {
            result.error("DND_ERROR", "Failed to get Do Not Disturb status: ${e.message}", null)
        }
    }
    
    // ==================== Screen Controls ====================
    
    private fun wakeScreen(result: MethodChannel.Result) {
        try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            
            @Suppress("DEPRECATION")
            val wakeLock = powerManager.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "AGiXT:WakeScreen"
            )
            wakeLock.acquire(3000) // Wake for 3 seconds
            wakeLock.release()
            
            result.success(mapOf(
                "success" to true,
                "message" to "Screen awakened"
            ))
        } catch (e: Exception) {
            result.error("SCREEN_ERROR", "Failed to wake screen: ${e.message}", null)
        }
    }
    
    private fun isScreenOn(result: MethodChannel.Result) {
        try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val keyguardManager = context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            
            val isInteractive = powerManager.isInteractive
            val isLocked = keyguardManager.isKeyguardLocked
            
            result.success(mapOf(
                "screenOn" to isInteractive,
                "isLocked" to isLocked
            ))
        } catch (e: Exception) {
            result.error("SCREEN_ERROR", "Failed to check screen status: ${e.message}", null)
        }
    }
    
    // ==================== System Info ====================
    
    private fun getSystemInfo(result: MethodChannel.Result) {
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            
            result.success(mapOf(
                // Audio
                "mediaVolume" to getVolumePercent(audioManager, AudioManager.STREAM_MUSIC),
                "ringVolume" to getVolumePercent(audioManager, AudioManager.STREAM_RING),
                "alarmVolume" to getVolumePercent(audioManager, AudioManager.STREAM_ALARM),
                "ringerMode" to when (audioManager.ringerMode) {
                    AudioManager.RINGER_MODE_NORMAL -> "normal"
                    AudioManager.RINGER_MODE_VIBRATE -> "vibrate"
                    AudioManager.RINGER_MODE_SILENT -> "silent"
                    else -> "unknown"
                },
                "isMusicActive" to audioManager.isMusicActive,
                
                // Battery
                "batteryLevel" to batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY),
                "isCharging" to batteryManager.isCharging,
                
                // Screen
                "screenOn" to powerManager.isInteractive,
                
                // Device
                "androidVersion" to Build.VERSION.SDK_INT,
                "manufacturer" to Build.MANUFACTURER,
                "model" to Build.MODEL
            ))
        } catch (e: Exception) {
            result.error("SYSTEM_ERROR", "Failed to get system info: ${e.message}", null)
        }
    }
    
    private fun getVolumePercent(audioManager: AudioManager, stream: Int): Int {
        val current = audioManager.getStreamVolume(stream)
        val max = audioManager.getStreamMaxVolume(stream)
        return if (max > 0) (current * 100) / max else 0
    }
}
