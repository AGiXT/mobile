package dev.agixt.agixt

import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.view.FlutterCallbackInformation
import io.flutter.embedding.engine.loader.FlutterLoader

class BackgroundService : Service(), LifecycleDetector.Listener {

    private var flutterEngine: FlutterEngine? = null
    private val flutterLoader = FlutterLoader()

    override fun onCreate() {
        super.onCreate()

        // Initialize FlutterLoader if it hasn't been initialized yet
        if (!flutterLoader.initialized()) {
            flutterLoader.startInitialization(applicationContext)
            flutterLoader.ensureInitializationComplete(applicationContext, null)
        }

        val notification = Notifications.buildForegroundNotification(this)
        startForeground(Notifications.NOTIFICATION_ID_BACKGROUND_SERVICE, notification)

        LifecycleDetector.listener = this
    }


    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        intent?.getLongExtra(KEY_CALLBACK_RAW_HANDLE, -1)?.let { callbackRawHandle ->
            if (callbackRawHandle != -1L) setCallbackRawHandle(callbackRawHandle)
        }

        // Ensure service maintains proper foreground state even when location is enabled
        val notification = Notifications.buildForegroundNotification(this)
        startForeground(Notifications.NOTIFICATION_ID_BACKGROUND_SERVICE, notification)

        if (!LifecycleDetector.isActivityRunning) {
            startFlutterNativeView()
        }

        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        LifecycleDetector.listener = null
    }

    override fun onBind(intent: Intent): IBinder? = null

    override fun onFlutterActivityCreated() {
        stopFlutterNativeView()
    }

    override fun onFlutterActivityDestroyed() {
        startFlutterNativeView()
    }

    private fun startFlutterNativeView() {
        if (flutterEngine != null) return

        Log.i("BackgroundService", "Starting FlutterEngine")

        getCallbackRawHandle()?.let { callbackRawHandle ->
            flutterEngine = FlutterEngine(this).also { engine ->
                val callbackInformation =
                    FlutterCallbackInformation.lookupCallbackInformation(callbackRawHandle)

                engine.dartExecutor.executeDartCallback(
                    DartExecutor.DartCallback(
                        assets,
                        flutterLoader.findAppBundlePath(),
                        callbackInformation
                    )
                )
            }
        }
    }

    private fun stopFlutterNativeView() {
        Log.i("BackgroundService", "Stopping FlutterEngine")
        flutterEngine?.destroy()
        flutterEngine = null
    }

    private fun getCallbackRawHandle(): Long? {
        val prefs = getSharedPreferences(SHARED_PREFERENCES_NAME, Context.MODE_PRIVATE)
        val callbackRawHandle = prefs.getLong(KEY_CALLBACK_RAW_HANDLE, -1)
        return if (callbackRawHandle != -1L) callbackRawHandle else null
    }

    private fun setCallbackRawHandle(handle: Long) {
        val prefs = getSharedPreferences(SHARED_PREFERENCES_NAME, Context.MODE_PRIVATE)
        prefs.edit().putLong(KEY_CALLBACK_RAW_HANDLE, handle).apply()
    }


    companion object {
        private const val SHARED_PREFERENCES_NAME = "dev.agixt.agixt.BackgroundService"

        private var callbackRawHandle: Long? = null;

        private const val KEY_CALLBACK_RAW_HANDLE = "callbackRawHandle"

        fun startService(context: Context, callbackRawHandle: Long) {
            this.callbackRawHandle = callbackRawHandle;
            val intent: Intent;

            intent = Intent(context, BackgroundService::class.java).apply {
                putExtra(KEY_CALLBACK_RAW_HANDLE, callbackRawHandle)
            }
            ContextCompat.startForegroundService(context, intent)
        }

        fun stopService(context: Context, callbackRawHandle: Long? = null) {
            val intent: Intent;
            val cbr = this.callbackRawHandle;

            intent = Intent(context, BackgroundService::class.java).apply {
                putExtra(KEY_CALLBACK_RAW_HANDLE, cbr)
            }
            context.stopService(intent);
        }


    }

}