/// Package
/// ------------------------------------------------------------------------------------------------

package com.merigo.solana_wallet_adapter_android


/// Imports
/// ------------------------------------------------------------------------------------------------

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result


/// Solana Wallet Adapter Android Plugin
/// ------------------------------------------------------------------------------------------------

class SolanaWalletAdapterAndroidPlugin:
  FlutterPlugin,
  MethodCallHandler
{
  /// The MethodChannel that communicates between Flutter and native Android.
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel

  /// View context and scope.
//  private var parentJob = Job()
//  private val coroutineContext: CoroutineContext get() = parentJob + Dispatchers.Main
//  private val viewModelScope = CoroutineScope(coroutineContext)
//  private var pingJob: Job? = null

//  /// Main view activity.
//  private var activity: Activity? = null

  /// Application context.
  private lateinit var context: Context

  /// Called when a local association activity completes.
//  private var cancelLocalAssociation: (() -> Unit)? = null

  /// Constants
  companion object {
    private val TAG = SolanaWalletAdapterAndroidPlugin::class.java.name
    private const val WALLET_ACTIVITY_REQUEST_CODE = 1234
    private const val URI_ACTIVITY_REQUEST_CODE = 4321
  }

  /// Method channel function names.
  enum class Method(val method: String) {
    OPEN_URI("openUri"),
    OPEN_WALLET("openWallet"),
//    CLOSE_WALLET("closeWallet"),
//    IS_APP_INSTALLED("isAppInstalled"),
//    IS_LOW_POWER_MODE("isLowPowerMode"),
//    PING("ping")
  }

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    val name = "com.merigo/solana_wallet_adapter"
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, name)
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when(call.method) {
      Method.OPEN_URI.method
        -> openUri(call, result)
      Method.OPEN_WALLET.method
        -> openWallet(call, result)
//      Method.CLOSE_WALLET.method
//        -> closeWallet(call, result)
//      Method.IS_APP_INSTALLED.method
//        -> isAppInstalled(call, result)
//      Method.IS_LOW_POWER_MODE.method
//        -> isLowPowerMode(call, result)
      else
        -> result.notImplemented()
    }
  }

//  /**
//   * Parses [call]'s argument map for an [Int] parameter named [key].
//   */
//  private fun parseInt(
//    call: MethodCall,
//    key: String,
//  ): Int? {
//    return call.argument<Int>(key)
//  }

  /**
   * Parses [call]'s argument map for a [String] parameter named [key].
   */
  private fun parseString(
    call: MethodCall,
    key: String,
  ): String? {
    return call.argument<String>(key)
  }

  /**
   * Parses [call]'s argument map for a "uri" parameter.
   */
  private fun parseUri(
    call: MethodCall,
    key: String = "uri",
  ): Uri? {
    return parseString(call, key)?.let { Uri.parse(it) }
  }

  /**
   * Starts an [Intent.ACTION_VIEW] activity for [uri] and returns whether or not the activity has
   * been started.
   */
  private fun startActivity(
    uri: Uri?,
    flags: Int = Intent.FLAG_ACTIVITY_NEW_TASK,
  ): Boolean {
    val packageManager = context.packageManager
    val intent = Intent(Intent.ACTION_VIEW, uri)
      .addCategory(Intent.CATEGORY_BROWSABLE)
      .addFlags(flags)
      .setData(uri)
    return if (
      uri != null
      && packageManager != null
      && intent.resolveActivity(packageManager) != null
    ) {
      context.startActivity(intent) //startActivityForResult(intent, requestCode)
      true
    } else {
      false
    }
  }

  /**
   * [Method.OPEN_URI] method call handler.
   */
  private fun openUri(
    call: MethodCall,
    result: Result,
  ) {
    result.success(startActivity(parseUri(call)))
  }

  /**
   * The [openWallet] activity intent flags.
   */
  private val openWalletActivityFlags
    get() = Intent.FLAG_ACTIVITY_NEW_TASK or if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
      Intent.FLAG_ACTIVITY_REQUIRE_NON_BROWSER
    } else {
      0
    }

  /**
   * [Method.OPEN_WALLET] method call handler.
   */
  private fun openWallet(
    call: MethodCall,
    result: Result,
  ) {
//    check(cancelLocalAssociation == null)
//    cancelLocalAssociation = { this@coroutineScope.cancel() }
//    pingJob?.cancel()
    val opened = startActivity(parseUri(call), openWalletActivityFlags)
//    Log.d("START PING!!!!", "PING!!! $opened")
//    channel.invokeMethod(Method.PING.method, null)
//   if (opened) pingJob = ping(parseInt(call, "timeLimit"))
    result.success(opened)
  }

//  /**
//   * [Method.CLOSE_WALLET] method call handler.
//   */
//  private fun closeWallet(
//    call: MethodCall,
//    result: Result,
//  ) {
//    pingJob?.cancel()
//    result.success(true)
//  }

//  /**
//   * [Method.IS_APP_INSTALLED] method call handler.
//   */
//  private fun isAppInstalled(
//    call: MethodCall,
//    result: Result,
//  ) {
////    val isInstalled = try {
////      val id = parseString(call, "id")
////      require(id != null) {
////        "App store id required."
////      }
////      val packageManager = activity?.packageManager
////      require(packageManager != null) {
////        "Package manager is null."
////      }
////      packageManager.getPackageInfo(id, 0)
////      true
////    } catch (e: Throwable) {
////      false
////    }
////    result.success(isInstalled)
//    // Add [scheme] to [AndroidManifest.xml]!
//    val scheme = parseString(call, "scheme")
//    val activities = activity?.packageManager?.queryIntentActivities(
//      Intent(Intent.ACTION_VIEW, Uri.parse("$scheme://")),
//      PackageManager.MATCH_DEFAULT_ONLY
//    )
//    result.success(scheme != null && ((activities?.size ?: 0) > 0))
//  }

//  /**
//   * [Method.IS_LOW_POWER_MODE] method call handler.
//   */
//  private fun isLowPowerMode(
//    call: MethodCall,
//    result: Result,
//  ) {
//    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
//      val powerManager = activity?.getSystemService(Context.POWER_SERVICE) as? PowerManager
//      result.success(powerManager?.isPowerSaveMode ?: false)
//    } else {
//      result.success(false)
//    }
//  }

//// @OptIn(ObsoleteCoroutinesApi::class)
// private fun ping(timeLimit: Int?): Job = viewModelScope.launch(
//   newSingleThreadContext(Method.PING.method)
// ) {
//   withTimeout(timeLimit?.toLong() ?: 120000L) { // 2 minutes
//     while (true) {
//       delay(2000)
//       withContext(Dispatchers.Main) {
//         channel.invokeMethod(Method.PING.method, null)
//       }
//     }
//   }
// }

//  private fun createNotificationChannel(context: Context) {
//    // Create the NotificationChannel, but only on API 26+ because
//    // the NotificationChannel class is new and not in the support library
//    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
//      val importance = NotificationManager.IMPORTANCE_HIGH
//      val channel = NotificationChannel("CHANNEL_ID", "Channel Name", importance).apply {
//        description = "Text Description"
//      }
//      // Register the channel with the system
//      val notificationManager: NotificationManager = getSystemService(context, NotificationManager::class.java) as NotificationManager
//      notificationManager.createNotificationChannel(channel)
//    }
//  }
//
//  private fun bringToForeground(
//    call: MethodCall,
//    result: Result,
//  ) {
//    Log.d(TAG, "BRING TO FRONT")
//    activity?.let { activity ->
//      val context = activity.applicationContext
//      val intent: Intent? = context.packageManager.getLaunchIntentForPackage(context.packageName)
//      var builder = NotificationCompat.Builder(activity!!.applicationContext, "CHANNEL_ID")
//        .setSmallIcon(activity!!.applicationInfo.icon)
//        .setContentTitle("Title")
//        .setContentText("Notification body.")
//        .setPriority(NotificationCompat.PRIORITY_DEFAULT)
//        .setCategory(NotificationCompat.CATEGORY_STATUS)
//        .setTimeoutAfter(5000)
//        .setAutoCancel(true)
//        .setLocalOnly(true)
//      intent?.let { builder.setContentIntent(
//        PendingIntent.getActivity(context, 0, it, 0)
//      ) }
//      with(NotificationManagerCompat.from(activity!!.applicationContext)) {
//        notify(0, builder.build())
//      }
//    }
//    result.success(true)
//  }

//  /**
//   * Starts an [Intent.ACTION_VIEW] activity for [uri] and returns whether or not the activity has
//   * been started.
//   */
//  private fun startUriIntent(
//    uri: Uri?,
//  ): Boolean {
//    val intent = Intent(Intent.ACTION_VIEW, uri)
//    val activity = activity
//    val packageManager = activity?.packageManager
//    return if (activity != null
//      && packageManager != null
//      && intent.resolveActivity(packageManager) != null) {
//      activity.startActivity(intent)
//      true
//    } else {
//      false
//    }
//  }

//  /**
//   * Starts an [intent] activity for a local association connection.
//   */
//  private fun startLocalAssociationIntent(
//    intent: Intent,
//    cancelLocalAssociation: () -> Unit
//  ) {
//    synchronized(this) {
//      check(this.cancelLocalAssociation == null)
//      this.cancelLocalAssociation = cancelLocalAssociation
//    }
//    activity?.startActivityForResult(intent, WALLET_ACTIVITY_REQUEST_CODE)
//  }
//
//  /**
//   * Called when a local association completes.
//   */
//  private fun completeLocalAssociationIntent(): Boolean {
//    Log.d(TAG, "WALLET CLOSED!!!!!")
//    cancelLocalAssociation?.let {
//      cancelLocalAssociation = null
//      viewModelScope.launch { it() }
//    }
//    return true
//  }

//  /**
//   * Set [activity] and listen for [ActivityAware] notifications.
//   */
//  private fun setActivity(binding: ActivityPluginBinding?) {
//    activity = binding?.activity
////    cancelLocalAssociation = null
//    binding?.addActivityResultListener(this)
//    activity?.application?.registerActivityLifecycleCallbacks(this);
//  }
//
//  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
//    setActivity(binding)
//  }
//
//  override fun onDetachedFromActivityForConfigChanges() {
//    setActivity(null)
//  }
//
//  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
//    setActivity(binding)
//  }
//
//  override fun onDetachedFromActivity() {
//    setActivity(null)
//  }
//
//  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
//    Log.d("ACTIVITY RESULT", "REQ CODE $requestCode, RES CODE $requestCode, URI ${data?.data?.toString()}")
//    return true
//  }
//
//  override fun onActivityCreated(p0: Activity, p1: Bundle?) {
//    Log.d("ACTIVITY CREATED", "${p0.toString()}")
//  }
//
//  override fun onActivityStarted(p0: Activity) {
//    Log.d("ACTIVITY STARTED", "${p0.toString()}")
//  }
//
//  override fun onActivityResumed(p0: Activity) {
//    Log.d("ACTIVITY RESUMED", "${p0.toString()}")
//  }
//
//  override fun onActivityPaused(p0: Activity) {
//    Log.d("ACTIVITY PAUSED", "${p0.toString()}")
//  }
//
//  override fun onActivityStopped(p0: Activity) {
//    Log.d("ACTIVITY STOPPED", "${p0.toString()}")
//  }
//
//  override fun onActivitySaveInstanceState(p0: Activity, p1: Bundle) {
//    Log.d("ACTIVITY SAVED", "${p0.toString()}")
//  }
//
//  override fun onActivityDestroyed(p0: Activity) {
//    Log.d("ACTIVITY DESTROYED", "${p0.toString()}")
//  }

//  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
//    Log.d(TAG, "REQUEST CODE $requestCode, RESULT CODE $resultCode, DATA $data")
//    return when (requestCode) {
//      WALLET_ACTIVITY_REQUEST_CODE -> completeLocalAssociationIntent()
//      else -> false
//    }
//  }
}