package lab.neruno.android_package_manager

import android.content.ComponentName
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.Checksum
import android.content.pm.PackageManager
import android.content.pm.PackageManager.ApplicationInfoFlags
import android.graphics.Bitmap
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.graphics.Canvas
import android.os.Build
import androidx.annotation.NonNull
import androidx.core.graphics.BitmapCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.security.cert.CertificateFactory

/** AndroidPackageManagerPlugin */
class AndroidPackageManagerPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var channel : MethodChannel

    private lateinit var packageManager: PackageManager
    private lateinit var activityContext: Context
    
    companion object {
        @JvmStatic
        private val flags = "flags"
        
        @JvmStatic
        private val packageName = "packageName"
        
        @JvmStatic
        private val permName = "permName"
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "android_package_manager")
        channel.setMethodCallHandler(this)
        // Instead of using the `Context` from `ActivityPluginBinding`, now using
        // the one from `FlutterPluginBinding` to allow usages in Isolates
        packageManager = flutterPluginBinding.applicationContext.packageManager
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "addPermission" -> {
                // TODO: Find way to obtain PermissionInfo instances somewhere
                result.success(null)
            }
            "addWhitelistedRestrictedPermission" -> addWhitelistedRestrictedPermission(call, result)
            "canPackageQuery" -> canPackageQuery(call, result)
            "canRequestPackageInstalls" -> canRequestPackageInstalls(result)
            "canonicalToCurrentPackageNames" -> canonicalToCurrentPackageNames(call, result)
            "checkPermission" -> checkPermission(call, result)
            "checkSignatures" -> checkSignatures(call, result)
            "clearInstantAppCookie" -> clearInstantAppCookie(result)
            "currentToCanonicalPackageNames" -> currentToCanonicalPackageNames(call, result)
            "extendVerificationTimeout" -> {
                // TODO: Research required
                result.success(null)
            }
            "getActivityBanner" -> getActivityBanner(call, result)
            "getActivityIcon" -> getActivityIcon(call, result)
            "getActivityInfo" -> getActivityInfo(call, result)
            "getActivityLogo" -> getActivityLogo(call, result)
            "getAllPermissionGroups" -> getAllPermissionGroups(call, result)
            "getApplicationBanner" -> getApplicationBanner(call, result)
            "getApplicationEnabledSetting" -> getApplicationEnabledSetting(call, result)
            "getApplicationIcon" -> getApplicationIcon(call, result)
            "getApplicationLabel" -> getApplicationLabel(call, result)
            "getBackgroundPermissionOptionLabel" -> getBackgroundPermissionOptionLabel(result)
            "getChangedPackages" -> getChangedPackages(call, result)
            "getComponentEnabledSetting" -> getComponentEnabledSetting(call, result)
            "getDefaultActivityIcon" -> getDefaultActivityIcon(result)
            "getDrawable" -> {
                // TODO: Research or refer other drawable fetching plugins
                result.success(null)
            }
            "getInstallSourceInfo" -> getInstallSourceInfo(call, result)
            "getInstalledApplications" -> getInstalledApplications(call, result)
            "getInstalledModules" -> getInstalledModules(result)
            "getInstalledPackages" -> getInstalledPackages(call, result)
            "getInstallerPackageName" -> getInstallerPackageName(call, result)
            "getInstantAppCookie" -> getInstantAppCookie(result)
            "getInstantAppCookieMaxBytes" -> getInstantAppCookieMaxBytes(result)
            "getInstrumentationInfo" -> getInstrumentationInfo(call, result)
            "getLaunchIntentForPackage" -> {
                // @see openApp
                result.notImplemented()
            }
            "getLaunchIntentSenderForPackage" -> {
                // TODO: Raise targetSdk to Tiramisu
                result.success(null)
            }
            "getLeanbackLaunchIntentForPackage" -> {
                // @see launchLeanback
                result.notImplemented()
            }
            "getMimeGroup" -> getMimeGroup(call, result)
            "getModuleInfo" -> getModuleInfo(call, result)
            "getNameForUid" -> getNameForUid(call, result)
            "getPackageArchiveInfo" -> getPackageArchiveInfo(call, result)
            "getPackageGids" -> getPackageGids(call, result)
            "getPackageInfo" -> getPackageInfo(call, result)
            "getPackageUid" -> getPackageUid(call, result)
            "getPackagesForUid" -> getPackagesForUid(call, result)
            "getPackagesHoldingPermissions" -> getPackagesHoldingPermissions(call, result)
            "getPackageInstaller" -> {
                // TODO: Handle PackageInstaller
                result.success(null)
            }
            "getPermissionGroupInfo" -> getPermissionGroupInfo(call, result)
            "getPermissionInfo" -> getPermissionInfo(call, result)
            "getProperty" -> getProperty(call, result)
            "getProviderInfo" -> getProviderInfo(call, result)
            "getReceiverInfo" -> getReceiverInfo(call, result)
            "getResourcesForActivity" -> {
                // TODO: Handle Resources
                result.success(null)
            }
            "getResourcesForApplication" -> {
                // TODO: Handle Resources
                result.success(null)
            }
            "getServiceInfo" -> getServiceInfo(call, result)
            "getSharedLibraries" -> {
                // TODO: Handle unresolved references for InstallFlags
                result.success(null)
            }
            "getSuspendedPackageAppExtras" -> getSuspendedPackageAppExtras(result)
            "getSyntheticAppDetailsActivityEnabled" -> getSyntheticAppDetailsActivityEnabled(call, result)
            "getSystemAvailableFeatures" -> getSystemAvailableFeatures(result)
            "getSystemSharedLibraryNames" -> getSystemSharedLibraryNames(result)
            "getTargetSdkVersion" -> getTargetSdkVersion(call, result)
            "getText" -> {
                // TODO: Add ApplicationInfo handling
                result.success(null)
            }
            "getWhitelistedRestrictedPermissions" -> getWhitelistedRestrictedPermissions(call, result)
            "getXml" -> {
                // TODO: Add ApplicationInfo and XmlResourceParser handlers
                result.success(null)
            }
            "hasSigningCertificate" -> hasSigningCertificate(call, result)
            "hasSigningCertificateWithUid" -> hasSigningCertificateWithUid(call, result)
            "hasSystemFeature" -> hasSystemFeature(call, result)
            "isAutoRevokeWhitelisted" -> isAutoRevokeWhitelisted(call, result)
            "isDefaultApplicationIcon" -> isDefaultApplicationIcon(call, result)
            "isDeviceUpgrading" -> isDeviceUpgrading(result)
            "isInstantApp" -> isInstantApp(call, result)
            "isPackageSuspended" -> isPackageSuspended(call, result)
            "isPermissionRevokedByPolicy" -> isPermissionRevokedByPolicy(call, result)
            "isSafeMode" -> isSafeMode(result)
            "launchLeanback" -> launchLeanback(call, result)
            "openApp" -> openApp(call, result)
            "queryActivityProperty" -> queryActivityProperty(call, result)
            "queryApplicationProperty" -> queryApplicationProperty(call, result)
            "queryBroadcastReceivers" -> {
                // TODO: Handle Intent
                result.success(null)
            }
            "queryContentProviders" -> queryContentProviders(call, result)
            "queryInstrumentation" -> queryInstrumentation(call, result)
            "queryIntentActivities" -> {
                // TODO: Handle Intent
                result.success(null)
            }
            "queryIntentContentProviders" -> {
                // TODO: Handle Intent
                result.success(null)
            }
            "queryIntentServices" -> {
                // TODO: Handle Intent
                result.success(null)
            }
            "queryPermissionsByGroup" -> queryPermissionsByGroup(call, result)
            "queryProviderProperty" -> queryProviderProperty(call, result)
            "queryReceiverProperty" -> queryReceiverProperty(call, result)
            "queryServiceProperty" -> queryServiceProperty(call, result)
            "removePermission" -> removePermission(call, result)
            "removeWhitelistedRestrictedPermission" -> removeWhitelistedRestrictedPermission(call, result)
            "requestChecksums" -> requestChecksums(call, result)
            "resolveActivity" -> {
                // TODO: Handle Intent
                result.success(null)
            }
            "resolveContentProvider" -> resolveContentProvider(call, result)
            "resolveService" -> {
                // TODO: Handle Intent
                result.success(null)
            }
            "setApplicationCategoryHint" -> setApplicationCategoryHint(call, result)
            "setApplicationEnabledSetting" -> setApplicationEnabledSetting(call, result)
            "setAutoRevokeWhitelisted" -> setAutoRevokeWhitelisted(call, result)
            "setComponentEnabledSetting" -> setComponentEnabledSetting(call, result)
            "setInstallerPackageName" -> setInstallerPackageName(call, result)
            "setMimeGroup" -> setMimeGroup(call, result)
            "updateInstantCookie" -> updateInstantCookie(call, result)
            "verifyPendingInstall" -> verifyPendingInstall(call, result)
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        // This is called when it's being used by an actual running App which is having
        // an actual `Activity` running
        activityContext = binding.activity
        // Then use the `PackageManager` instance from it
        packageManager = binding.activity.packageManager
    }

    override fun onDetachedFromActivityForConfigChanges() {}

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {}

    override fun onDetachedFromActivity() {}

    private fun provideComponentName(call: MethodCall, result: Result? = null): ComponentName? {
        val pkg = call.argument<String>("pkg")
        val cls = call.argument<String>("cls")
        if (pkg != null && cls != null) {
            return ComponentName(pkg, cls)
        } else {
            result?.success(null)
        }
        return null
    }

    private fun provideFlags(call: MethodCall): Int = call.argument<Int>(flags) ?: 0

    private fun provideFlagsAsLong(call: MethodCall): Long = (call.argument<Int>(flags) ?: 0).toLong()

    private fun <F, T> runWithFlags(
        call: MethodCall,
        result: Result? = null,
        flagFactory: (flags: Long) -> F,
        resultBuilder: (flags: Int) -> T?,
        api33ResultBuilder: (flags: F) -> T?
    ) {
        if (Build.VERSION.SDK_INT >= 33) {
            result?.success(
                api33ResultBuilder(
                    flagFactory(
                        provideFlagsAsLong(call)
                    )
                )
            )
        } else {
            result?.success(
                resultBuilder(
                    provideFlags(call)
                )
            )
        }
    }

    private fun <F, T> runWithComponentNameAndFlags(
        call: MethodCall,
        result: Result? = null,
        flagFactory: (flags: Long) -> F,
        resultBuilder: (componentName: ComponentName, flags: Int) -> T,
        api33ResultBuilder: (componentName: ComponentName, flags: F) -> T
    ) {
        provideComponentName(call, result)?.run {
            try {
                if (Build.VERSION.SDK_INT >= 33) {
                    result?.success(
                        api33ResultBuilder(
                            this,
                            flagFactory(
                                provideFlagsAsLong(call)
                            )
                        )
                    )
                } else {
                    result?.success(
                        resultBuilder(
                            this,
                            provideFlags(call)
                        )
                    )
                }
            } catch (ex: PackageManager.NameNotFoundException) {
                result?.error(ex.javaClass.name, ex.message, null)
            }
        }
    }

    private fun <F, T> runWithPackageNameAndFlags(
        call: MethodCall,
        result: Result,
        flagFactory: (flags: Long) -> F,
        resultBuilder: (packageName: String, flags: Int) -> T,
        api33ResultBuilder: (packageName: String, flags: F) -> T
    ) {
        providePackageName(call, result)?.run {
            if (Build.VERSION.SDK_INT >= 33) {
                result.success(
                    api33ResultBuilder(
                        this,
                        flagFactory(
                            provideFlagsAsLong(call)
                        )
                    )
                )
            } else {
                result.success(
                    resultBuilder(
                        this,
                        provideFlags(call)
                    )
                )
            }
        }
    }

//    private fun provideFlags(call: MethodCall, validator: (Int) -> Boolean, fallbackFlags: Int? = null): Int {
//        val flags = call.argument<Int>(flags)
//        if (flags != null) {
//            if (validator(flags)) {
//                return flags
//            }
//        }
//        return fallbackFlags ?: PackageManager.GET_META_DATA
//    }

    private fun provideNewState(call: MethodCall, result: Result): Int? = call.argument<Int>("newState").run {
        val isValidState = listOf(
            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT,
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED_USER,
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED_UNTIL_USED
        ).contains(this)
        if (isValidState) {
            this
        } else {
            result.success(null)
            null
        }
    }

    private fun providePackageAndPermName(call: MethodCall, result: Result): Pair<String, String>? {
        val packageName = call.argument<String>(packageName)
        val permName = call.argument<String>(permName)
        if (packageName != null && permName != null) {
            return Pair(packageName, permName)
        }
        result.success(null)
        return null
    }

    private fun providePackageName(call: MethodCall, result: Result): String? {
        val packageName = call.argument<String>(packageName)
        if (packageName == null) {
            result.success(null)
        }
        return packageName
    }

    private fun providePermName(call: MethodCall, result: Result? = null): String? {
        val permName = call.argument<String>(permName)
        if (permName == null) {
            result?.success(null)
        }
        return permName
    }

    private fun providePropertyName(call: MethodCall, result: Result): String? {
        val propertyName = call.argument<String>("propertyName")
        if (propertyName == null) {
            result.success(null)
        }
        return propertyName
    }

    private fun provideDrawable(call: MethodCall, result: Result): Drawable? {
        val drawable = call.argument<ByteArray>("drawable")
        if (drawable != null) {
            try {
                return ByteArrayInputStream(drawable).use {
                    BitmapDrawable.createFromStream(
                        it, "drawable"
                    )
                }
            } catch (ex: Exception) {
                result.error(ex.javaClass.name, ex.message, null)
            }
        }
        return null
    }

    private fun addWhitelistedRestrictedPermission(call: MethodCall, result: Result) {
        if (!isAtLeastAndroid29()) {
            result.error("UnsupportedException", "Requires at least Android 29 (Q)", null)
            return
        }
        providePackageAndPermName(call, result)?.let { (packageName, permName) ->
            val whitelistFlags = call.argument<Int>("whitelistFlags")
            if (whitelistFlags == null) {
                result.success(null)
                return
            }
            val allPermissionFlags = listOf(
                PackageManager.FLAG_PERMISSION_WHITELIST_INSTALLER,
                PackageManager.FLAG_PERMISSION_WHITELIST_SYSTEM,
                PackageManager.FLAG_PERMISSION_WHITELIST_UPGRADE
            )
            if (!allPermissionFlags.contains(whitelistFlags)) {
                result.success(null)
                return
            }
            packageManager.addWhitelistedRestrictedPermission(packageName, permName, whitelistFlags)
            result.success(null)
        }
    }

    private fun canRequestPackageInstalls(result: Result) {
        if (!isAtLeastAndroid26()) {
            result.success(false)
            return
        }
        result.success(packageManager.canRequestPackageInstalls())
    }

    private fun canPackageQuery(call: MethodCall, result: Result) {
        if (!isAtLeastAndroid33()) {
            result.success(false)
            return
        }
        try {
            val sourcePackageName = call.argument<String>("sourcePackageName")
            val targetPackageName = call.argument<String>("targetPackageName")
            if (sourcePackageName != null && targetPackageName != null) {
                result.success(
                    packageManager.canPackageQuery(
                        sourcePackageName, targetPackageName
                    )
                )
            } else {
                result.success(false)
            }
        } catch (ex: PackageManager.NameNotFoundException) {
            result.error(ex.javaClass.name, ex.message, null)
        }
    }

    private fun canonicalToCurrentPackageNames(call: MethodCall, result: Result) {
        val packageNames = call.argument<List<String>>("packageNames")?.toTypedArray()
        if (packageNames == null) {
            result.success(null)
            return
        }
        result.success(
            packageManager.canonicalToCurrentPackageNames(packageNames)
        )
    }

    private fun checkPermission(call: MethodCall, result: Result) {
        providePackageAndPermName(call, result)?.let { (packageName, permName) ->
            result.success(
                packageManager.checkPermission(permName, packageName)
            )
        }
    }

    private fun checkSignatures(call: MethodCall, result: Result) {
        val packageName1 = call.argument<String>("packageName1")
        val packageName2 = call.argument<String>("packageName2")
        if (packageName1 == null || packageName2 == null) {
            result.success(PackageManager.SIGNATURE_UNKNOWN_PACKAGE)
            return
        }
        result.success(
            packageManager.checkSignatures(packageName1, packageName2)
        )
    }

    private fun clearInstantAppCookie(result: Result) {
        if (isAtLeastAndroid26()) {
            packageManager.clearInstantAppCookie()
        }
        result.success(null)
    }

    private fun currentToCanonicalPackageNames(call: MethodCall, result: Result) {
        val packageNames = call.argument<List<String>>("packageNames")?.toTypedArray()
        if (packageNames == null) {
            result.success(null)
            return
        }
        result.success(
            packageManager.currentToCanonicalPackageNames(packageNames)
        )
    }

    private fun getActivityBanner(call: MethodCall, result: Result) {
        provideComponentName(call, result)?.let {
            try {
                sendDrawableResult(
                    packageManager.getActivityBanner(it),
                    null,
                    result = result
                )
            } catch (ex: PackageManager.NameNotFoundException) {
                result.error(ex.javaClass.name, ex.message, null)
            }
        }
    }

    private fun getActivityIcon(call: MethodCall, result: Result) {
        provideComponentName(call, result)?.let {
            try {
                sendDrawableResult(
                    packageManager.getActivityIcon(it),
                    call.argument<Int?>("quality"),
                    call.argument<Int?>("format") ?: 0,
                    result
                )
            } catch (ex: PackageManager.NameNotFoundException) {
                result.error(ex.javaClass.name, ex.message, null)
            }
        }
    }

    private fun getActivityInfo(call: MethodCall, result: Result) {
        runWithComponentNameAndFlags(
            call,
            result,
            flagFactory = { flags -> PackageManager.ComponentInfoFlags.of(flags) },
            resultBuilder = { componentName, flags ->
                packageManager.getActivityInfo(componentName, flags).toMap()
            },
            api33ResultBuilder = { componentName, flags ->
                packageManager.getActivityInfo(componentName, flags).toMap()
            }
        )
    }

    private fun getActivityLogo(call: MethodCall, result: Result) {
        provideComponentName(call, result)?.let {
            try {
                sendDrawableResult(
                    packageManager.getActivityLogo(it),
                    call.argument<Int?>("quality"),
                    call.argument<Int?>("format") ?: 0,
                    result
                )
            } catch (ex: PackageManager.NameNotFoundException) {
                result.error(ex.javaClass.name, ex.message, null)
            }
        }
    }

    private fun getAllPermissionGroups(call: MethodCall, result: Result) {
        provideFlags(call).run {
            val permissionGroups = packageManager.getAllPermissionGroups(this)
            permissionGroups.map {
                it.toMap()
            }.run {
                result.success(this)
            }
        }
    }

    private fun getApplicationBanner(call: MethodCall, result: Result) {
        providePackageName(call, result)?.let {
            try {
                sendDrawableResult(
                    packageManager.getApplicationBanner(it),
                    null,
                    result = result
                )
            } catch (ex: PackageManager.NameNotFoundException) {
                result.error(ex.javaClass.name, ex.message, null)
            }
        }
    }

    private fun getApplicationEnabledSetting(call: MethodCall, result: Result) {
        providePackageName(call, result)?.let {
            try {
                result.success(
                    packageManager.getApplicationEnabledSetting(it)
                )
            } catch (ex: IllegalArgumentException) {
                result.error(ex.javaClass.name, ex.message, null)
            }
        }
    }

    private fun getApplicationIcon(call: MethodCall, result: Result) {
        providePackageName(call, result)?.let {
            try {
                sendDrawableResult(
                    packageManager.getApplicationIcon(it),
                    call.argument<Int?>("quality"),
                    call.argument<Int?>("format") ?: 0,
                    result
                )
            } catch (ex: PackageManager.NameNotFoundException) {
                result.error(ex.javaClass.name, ex.message, null)
            }
        }
    }

    private fun getApplicationLabel(call: MethodCall, result: Result) {
        try {
            runWithPackageNameAndFlags(
                call,
                result,
                flagFactory = { flags -> ApplicationInfoFlags.of(flags) },
                resultBuilder = { packageName, flags ->
                    result.success(
                        packageManager.getApplicationLabel(
                            packageManager.getApplicationInfo(packageName, flags)
                        ).toString()
                    )
                },
                api33ResultBuilder = { packageName, flags ->
                    result.success(
                        packageManager.getApplicationLabel(
                            packageManager.getApplicationInfo(packageName, flags)
                        ).toString()
                    )
                },
            )
        } catch (ex: PackageManager.NameNotFoundException) {
            result.error(ex.javaClass.name, ex.message, null)
        }
    }

    private fun getBackgroundPermissionOptionLabel(result: Result) {
        if (!isAtLeastAndroid30()) {
            result.success(null)
            return
        }
        result.success(packageManager.backgroundPermissionOptionLabel.toString())
    }

    private fun getChangedPackages(call: MethodCall, result: Result) {
        if (!isAtLeastAndroid26()) {
            result.success(null)
            return
        }
        val sequenceNumber = call.argument<Int>("sequenceNumber")
        if (sequenceNumber == null) {
            result.success(null)
            return
        }
        result.success(packageManager.getChangedPackages(sequenceNumber))
    }

    private fun getComponentEnabledSetting(call: MethodCall, result: Result) {
        provideComponentName(call, result)?.let {
            result.success(
                packageManager.getComponentEnabledSetting(it)
            )
        }
    }

    private fun getDefaultActivityIcon(result: Result) {
        sendDrawableResult(packageManager.defaultActivityIcon, null, result = result)
    }

    private fun getInstallSourceInfo(call: MethodCall, result: Result) {
        if (!isAtLeastAndroid30()) {
            result.success(null)
            return
        }
        providePackageName(call, result)?.let {
            try {
                packageManager.getInstallSourceInfo(it).run {
                    result.success(
                        this.toMap()
                    )
                }
            } catch (ex: PackageManager.NameNotFoundException) {
                result.error(ex.javaClass.name, ex.message, null)
            }
        }
    }

    private fun getInstalledApplications(call: MethodCall, result: Result) {
        runWithFlags(
            call,
            result,
            flagFactory = { flags -> PackageManager.ApplicationInfoFlags.of(flags) },
            resultBuilder = { flags ->
                packageManager.getInstalledApplications(flags).map { it.toMap() }
            },
            api33ResultBuilder = { flags ->
                packageManager.getInstalledApplications(flags).map { it.toMap() }
            },
        )
    }

    private fun getInstalledModules(result: Result) {
        if (!isAtLeastAndroid29()) {
            result.success(null)
            return
        }
        result.success(
            packageManager.getInstalledModules(PackageManager.MATCH_ALL).map {
                it.toMap()
            }
        )
    }

    private fun getInstalledPackages(call: MethodCall, result: Result) {
        runWithFlags(
            call,
            result,
            flagFactory = { flags -> PackageManager.PackageInfoFlags.of(flags) },
            resultBuilder = { flags -> packageManager.getInstalledPackages(flags).map {
                it.toMap()
            }},
            api33ResultBuilder = { flags -> packageManager.getInstalledPackages(flags).map {
                it.toMap()
            }}
        )
    }

    private fun getInstallerPackageName(call: MethodCall, result: Result) {
        if (isAtLeastAndroid30()) {
            result.success(null)
            return
        }
        providePackageName(call, result)?.let {
            result.success(packageManager.getInstallerPackageName(it))
        }
    }

    private fun getInstantAppCookie(result: Result) {
        if (!isAtLeastAndroid26()) {
            result.success(null)
            return
        }
        result.success(packageManager.instantAppCookie)
    }

    private fun getInstantAppCookieMaxBytes(result: Result) {
        if (!isAtLeastAndroid26()) {
            result.success(null)
            return
        }
        result.success(packageManager.instantAppCookieMaxBytes)
    }

    private fun getInstrumentationInfo(call: MethodCall, result: Result) {
        provideComponentName(call, result)?.let {
            try {
                packageManager.getInstrumentationInfo(it, PackageManager.GET_META_DATA).run {
                    result.success(
                        this.toMap()
                    )
                }
            } catch (ex: PackageManager.NameNotFoundException) {
                result.error(ex.javaClass.name, ex.message, null)
            }
        }
    }

    private fun getMimeGroup(call: MethodCall, result: Result) {
        if (!isAtLeastAndroid30()) {
            result.success(null)
            return
        }
        val mimeGroup = call.argument<String>("mimeGroup")
        if (mimeGroup == null) {
            result.success(null)
            return
        }
        try {
            result.success(
                packageManager.getMimeGroup(mimeGroup).toList<String>()
            )
        } catch (ex: IllegalArgumentException) {
            result.error(ex.javaClass.name, ex.message, null)
        }
    }

    private fun getModuleInfo(call: MethodCall, result: Result) {
        if (!isAtLeastAndroid29()) {
            result.success(null)
            return
        }
        providePackageName(call, result)?.let {
            try {
                packageManager.getModuleInfo(it, 0).run {
                    result.success(
                        this.toMap()
                    )
                }
            } catch (ex: PackageManager.NameNotFoundException) {
                result.error(ex.javaClass.name, ex.message, null)
            }
        }
    }

    private fun getNameForUid(call: MethodCall, result: Result) {
        val uid = call.argument<Int>("uid")
        if (uid == null) {
            result.success(null)
            return
        }
        result.success(
            packageManager.getNameForUid(uid)
        )
    }

    private fun getPackageArchiveInfo(call: MethodCall, result: Result) {
        val archiveFilePath = call.argument<String>("archiveFilePath")
        if (archiveFilePath == null) {
            result.success(null)
            return
        }
        runWithFlags(
            call,
            result,
            flagFactory = { flags -> PackageManager.PackageInfoFlags.of(flags) },
            resultBuilder = { flags ->
                packageManager.getPackageArchiveInfo(archiveFilePath, flags)?.toMap()
            },
            api33ResultBuilder = { flags ->
                packageManager.getPackageArchiveInfo(archiveFilePath, flags)?.toMap()
            }
        )
    }

    private fun getPackageGids(call: MethodCall, result: Result) {
        providePackageName(call, result)?.let {
            result.success(
                packageManager.getPackageGids(it)?.toList()
            )
        }
    }

    private fun getPackageInfo(call: MethodCall, result: Result) {
        runWithPackageNameAndFlags(
            call,
            result,
            flagFactory = { flags -> PackageManager.PackageInfoFlags.of(flags) },
            resultBuilder = { packageName, flags ->
                packageManager.getPackageInfo(packageName, flags).toMap()
            },
            api33ResultBuilder = { packageName, flags ->
                packageManager.getPackageInfo(packageName, flags).toMap()
            }
        )
    }

    private fun getPackageUid(call: MethodCall, result: Result) {
        if (!isAtLeastAndroid24()) {
            result.success(null)
            return
        }
        runWithPackageNameAndFlags(
            call,
            result,
            flagFactory = { flags -> PackageManager.PackageInfoFlags.of(flags) },
            resultBuilder = { packageName, flags ->
                packageManager.getPackageInfo(packageName, flags).toMap()
            },
            api33ResultBuilder = { packageName, flags ->
                packageManager.getPackageInfo(packageName, flags).toMap()
            }
        )
    }

    private fun getPackagesForUid(call: MethodCall, result: Result) {
        val uid = call.argument<Int>("uid")
        if (uid == null) {
            result.success(null)
            return
        }
        result.success(
            packageManager.getPackagesForUid(uid)?.toList<String>()
        )
    }

    private fun getPackagesHoldingPermissions(call: MethodCall, result: Result) {
        val permissions = call.argument<List<String>>("permissions")?.toTypedArray()
        if (permissions == null || permissions.isEmpty()) {
            result.success(null)
            return
        }
        runWithFlags(
            call,
            result,
            flagFactory = { flags -> PackageManager.PackageInfoFlags.of(flags) },
            resultBuilder = { flags ->
                packageManager.getPackagesHoldingPermissions(permissions, flags).map {
                    it.toMap()
                }
            },
            api33ResultBuilder = { flags ->
                packageManager.getPackagesHoldingPermissions(permissions, flags).map {
                    it.toMap()
                }
            }
        )
    }

    private fun getPermissionGroupInfo(call: MethodCall, result: Result) {
        val groupName = call.argument<String>("groupName")
        if (groupName == null) {
            result.success(null)
            return
        }
        try {
            result.success(
                packageManager.getPermissionGroupInfo(groupName, PackageManager.GET_META_DATA).toMap()
            )
        } catch (ex: PackageManager.NameNotFoundException) {
            result.error(ex.javaClass.name, ex.message, null)
        }
    }

    private fun getPermissionInfo(call: MethodCall, result: Result) {
        val permName = call.argument<String>(permName)
        if (permName == null) {
            result.success(null)
            return
        }
        try {
            result.success(
                packageManager.getPermissionInfo(permName, PackageManager.GET_META_DATA)?.toMap()
            )
        } catch (ex: PackageManager.NameNotFoundException) {
            result.error(ex.javaClass.name, ex.message, null)
        }
    }

    private fun getProperty(call: MethodCall, result: Result) {
        if (!isAtLeastAndroid31()) {
            result.success(null)
            return
        }
        val propertyName = call.argument<String>("propertyName")
        if (propertyName == null) {
            result.success(null)
            return
        }
        providePackageName(call, result)?.let {
            try {
                packageManager.getProperty(propertyName, it).run {
                    result.success(this.toMap())
                }
            } catch (ex: PackageManager.NameNotFoundException) {
                result.error(ex.javaClass.name, ex.message, null)
            }
        }
    }

    private fun getProviderInfo(call: MethodCall, result: Result) {
        runWithComponentNameAndFlags(
            call,
            result,
            flagFactory = { flags -> PackageManager.ComponentInfoFlags.of(flags) },
            resultBuilder = { componentName, flags ->
                packageManager.getProviderInfo(componentName, flags).toMap()
            },
            api33ResultBuilder = { componentName, flags ->
                packageManager.getProviderInfo(componentName, flags).toMap()
            }
        )
    }

    private fun getReceiverInfo(call: MethodCall, result: Result) {
        runWithComponentNameAndFlags(
            call,
            result,
            flagFactory = { flags -> PackageManager.ComponentInfoFlags.of(flags) },
            resultBuilder = { componentName, flags ->
                packageManager.getReceiverInfo(componentName, flags).toMap()
            },
            api33ResultBuilder = { componentName, flags ->
                packageManager.getReceiverInfo(componentName, flags).toMap()
            },
        )
    }

    private fun getServiceInfo(call: MethodCall, result: Result) {
        runWithComponentNameAndFlags(
            call,
            result,
            flagFactory = { flags -> PackageManager.ComponentInfoFlags.of(flags) },
            resultBuilder = { componentName, flags ->
                packageManager.getServiceInfo(componentName, flags).toMap()
            },
            api33ResultBuilder = { componentName, flags ->
                packageManager.getServiceInfo(componentName, flags).toMap()
            },
        )
    }

    private fun getSuspendedPackageAppExtras(result: Result) {
        if (!isAtLeastAndroid28()) {
            result.success(null)
            return
        }
        result.success(
            packageManager.suspendedPackageAppExtras?.toMap()
        )
    }

    private fun getSyntheticAppDetailsActivityEnabled(call: MethodCall, result: Result) {
        if (!isAtLeastAndroid29()) {
            result.success(null)
            return
        }
        providePackageName(call, result)?.let {
            result.success(
                packageManager.getSyntheticAppDetailsActivityEnabled(it)
            )
        }
    }

    private fun getSystemAvailableFeatures(result: Result) {
        @Suppress("UNNECESSARY_SAFE_CALL")
        result.success(
            @Suppress("SAFE_CALL_WILL_CHANGE_NULLABILITY")
            packageManager.systemAvailableFeatures?.map {
                it.toMap()
            }
        )
    }

    private fun getSystemSharedLibraryNames(result: Result) {
        result.success(
            packageManager.systemSharedLibraryNames?.toList<String>()
        )
    }

    private fun getTargetSdkVersion(call: MethodCall, result: Result) {
        if (!isAtLeastAndroid31()) {
            result.success(null)
            return
        }
        providePackageName(call, result)?.let {
            try {
                result.success(packageManager.getTargetSdkVersion(it))
            } catch (ex: PackageManager.NameNotFoundException) {
                result.error(ex.javaClass.name, ex.message, null)
            }
        }
    }

    private fun getWhitelistedRestrictedPermissions(call: MethodCall, result: Result) {
        if (!isAtLeastAndroid29()) {
            result.success(null)
            return
        }
        providePackageName(call, result)?.let {
            provideFlags(call).run {
                result.success(
                    packageManager.getWhitelistedRestrictedPermissions(
                        it, this
                    ).toList<String>()
                )
            }
        }
    }

    private fun hasSigningCertificate(call: MethodCall, result: Result) {
        if (!isAtLeastAndroid28()) {
            result.success(null)
            return
        }
        providePackageName(call, result)?.let {
            val certificate = call.argument<ByteArray>("certificate")
            val type = call.argument<Int>("type")
            val validTypes = listOf(
                PackageManager.CERT_INPUT_RAW_X509,
                PackageManager.CERT_INPUT_SHA256
            )
            if (certificate == null || type == null || !validTypes.contains(type)) {
                result.success(false)
                return
            }
            result.success(
                packageManager.hasSigningCertificate(it, certificate, type)
            )
        }
    }

    private fun hasSigningCertificateWithUid(call: MethodCall, result: Result) {
        if (!isAtLeastAndroid28()) {
            result.success(null)
            return
        }
        val uid = call.argument<Int>("uid")
        val certificate = call.argument<ByteArray>("certificate")
        val type = call.argument<Int>("type")
        val validTypes = listOf(
                PackageManager.CERT_INPUT_RAW_X509,
                PackageManager.CERT_INPUT_SHA256
        )
        if (uid == null || certificate == null || type == null || !validTypes.contains(type)) {
            result.success(null)
            return
        }
        result.success(
                packageManager.hasSigningCertificate(uid, certificate, type)
        )
    }

    private fun hasSystemFeature(call: MethodCall, result: Result) {
        val featureName = call.argument<String>("featureName")
        if (featureName == null) {
            result.success(null)
            return
        }
        result.success(
            run {
                if (isAtLeastAndroid24()) {
                    call.argument<Int>("version")?.let {
                        packageManager.hasSystemFeature(featureName, it)
                    } ?: packageManager.hasSystemFeature(featureName)
                } else {
                    packageManager.hasSystemFeature(featureName)
                }
            }
        )
    }

    private fun isAutoRevokeWhitelisted(call: MethodCall, result: Result) {
        if (!isAtLeastAndroid30()) {
            result.success(null)
            return
        }
        result.success(
            run {
                providePackageName(call, result)?.let {
                    packageManager.isAutoRevokeWhitelisted(it)
                } ?: packageManager.isAutoRevokeWhitelisted
            }
        )
    }

    private fun isDefaultApplicationIcon(call: MethodCall, result: Result) {
        if (!isAtLeastAndroid30()) {
            result.success(null)
            return
        }
        provideDrawable(call, result)?.let {
            result.success(
                packageManager.isDefaultApplicationIcon(it)
            )
        }
    }

    private fun isDeviceUpgrading(result: Result) {
        if (!isAtLeastAndroid29()) {
            result.success(null)
            return
        }
        result.success(
            packageManager.isDeviceUpgrading
        )
    }

    private fun isInstantApp(call: MethodCall, result: Result) {
        if (!isAtLeastAndroid26()) {
            result.success(null)
            return
        }
        result.success(
            run {
                providePackageName(call, result)?.let {
                    packageManager.isInstantApp(it)
                } ?: packageManager.isInstantApp
            }
        )
    }

    private fun isPackageSuspended(call: MethodCall, result: Result) {
        if (!isAtLeastAndroid29()) {
            result.success(null)
            return
        }
        result.success(
            run {
                providePackageName(call, result)?.let {
                    packageManager.isPackageSuspended(it)
                } ?: packageManager.isPackageSuspended
            }
        )
    }

    private fun isPermissionRevokedByPolicy(call: MethodCall, result: Result) {
        if (!isAtLeastAndroid23()) {
            result.success(null)
            return
        }
        providePackageAndPermName(call, result)?.let { (packageName, permName) ->
            result.success(
                packageManager.isPermissionRevokedByPolicy(permName, packageName)
            )
        }
    }

    private fun isSafeMode(result: Result) {
        result.success(packageManager.isSafeMode)
    }

    private fun launchLeanback(call: MethodCall, result: Result) {
        providePackageName(call, result)?.let {
            packageManager.getLeanbackLaunchIntentForPackage(it)
        }.let {
            result.success(null)
            if (it != null) {
                activityContext.startActivity(it)
            }
        }
    }

    private fun openApp(call: MethodCall, result: Result) {
        providePackageName(call, result)?.let {
            packageManager.getLaunchIntentForPackage(it)
        }.let {
            result.success(null)
            if (it != null) {
                activityContext.startActivity(it)
            }
        }
    }

    private fun queryActivityProperty(call: MethodCall, result: Result) {
        if (!isAtLeastAndroid31()) {
            result.success(null)
            return
        }
        providePropertyName(call, result)?.let {
            result.success(
                packageManager.queryActivityProperty(it).map { prop ->
                    prop.toMap()
                }
            )
        }
    }

    private fun queryApplicationProperty(call: MethodCall, result: Result) {
        if (!isAtLeastAndroid31()) {
            result.success(null)
            return
        }
        providePropertyName(call, result)?.let {
            result.success(
                packageManager.queryApplicationProperty(it).map { prop ->
                    prop.toMap()
                }
            )
        }
    }

    @Suppress("SAFE_CALL_WILL_CHANGE_NULLABILITY", "UNNECESSARY_SAFE_CALL")
    private fun queryContentProviders(call: MethodCall, result: Result) {
        val processName = call.argument<String>("processName")
        val uid = call.argument<Int>("uid")
        if (uid == null) {
            result.success(null)
            return
        }
        runWithFlags(
            call,
            result,
            flagFactory = { flags -> PackageManager.ComponentInfoFlags.of(flags) },
            resultBuilder = { flags ->
                packageManager.queryContentProviders(processName, uid, flags)?.map {
                    it.toMap()
                }
            },
            api33ResultBuilder = { flags ->
                packageManager.queryContentProviders(processName, uid, flags)?.map {
                    it.toMap()
                }
            }
        )
    }

    private fun queryInstrumentation(call: MethodCall, result: Result) {
        val targetPackage = call.argument<String>("targetPackage")
        if (targetPackage == null) {
            result.success(null)
            return
        }
        result.success(
            packageManager.queryInstrumentation(targetPackage, PackageManager.GET_META_DATA).map {
                it.toMap()
            }
        )
    }

    private fun queryPermissionsByGroup(call: MethodCall, result: Result) {
        val permissionGroup = call.argument<String>("permissionGroup")
        result.success(
            packageManager.queryPermissionsByGroup(permissionGroup, PackageManager.GET_META_DATA).map {
                it.toMap()
            }
        )
    }

    private fun queryProviderProperty(call: MethodCall, result: Result) {
        if (!isAtLeastAndroid31()) {
            result.success(null)
            return
        }
        providePropertyName(call, result)?.let {
            result.success(
                packageManager.queryProviderProperty(it).map { prop ->
                    prop.toMap()
                }
            )
        }
    }

    private fun queryReceiverProperty(call: MethodCall, result: Result) {
        if (!isAtLeastAndroid31()) {
            result.success(null)
            return
        }
        providePropertyName(call, result)?.let {
            result.success(
                packageManager.queryReceiverProperty(it).map { prop ->
                    prop.toMap()
                }
            )
        }
    }

    private fun queryServiceProperty(call: MethodCall, result: Result) {
        if (!isAtLeastAndroid31()) {
            result.success(null)
            return
        }
        providePropertyName(call, result)?.let {
            result.success(
                packageManager.queryServiceProperty(it).map { prop ->
                    prop.toMap()
                }
            )
        }
    }

    private fun removePermission(call: MethodCall, result: Result) {
        providePermName(call, result)?.let {
            try {
                packageManager.removePermission(it)
                result.success(null)
            } catch (ex: SecurityException) {
                result.error(ex.javaClass.name, ex.message, null)
            }
        }
    }

    private fun removeWhitelistedRestrictedPermission(call: MethodCall, result: Result) {
        if (!isAtLeastAndroid29()) {
            result.success(null)
            return
        }
        providePackageAndPermName(call, result)?.let { (packageName, permName) ->
            provideFlags(call).run {
//            provideFlags(call, ::isValidWhitelistFlags, 0).run {
                try {
                    result.success(
                        packageManager.removeWhitelistedRestrictedPermission(
                            packageName, permName, this
                        )
                    )
                } catch (ex: SecurityException) {
                    result.error(ex.javaClass.name, ex.message, null)
                }
            }
        }
    }

    private fun requestChecksums(call: MethodCall, result: Result) {
        if (!isAtLeastAndroid31()) {
            result.success(null)
            return
        }
        providePackageName(call, result)?.let { packageName ->
            val includeSplits = call.argument<Boolean>("includeSplits") ?: false
            val required = call.argument<Int>("required")

            val checksumTypes = listOf(
                0,
                Checksum.TYPE_WHOLE_MERKLE_ROOT_4K_SHA256,
//                Checksum.TYPE_WHOLE_MD5,
//                Checksum.TYPE_WHOLE_SHA1,
//                Checksum.TYPE_WHOLE_SHA256,
//                Checksum.TYPE_WHOLE_SHA512,
                Checksum.TYPE_PARTIAL_MERKLE_ROOT_1M_SHA256,
                Checksum.TYPE_PARTIAL_MERKLE_ROOT_1M_SHA512
            )
            if (!checksumTypes.contains(required)) {
                result.success(null)
                return
            }

            val certBytes = call.argument<List<ByteArray>>("certBytes")
            val certType = call.argument<String>("certType") ?: "X.509"
            if (certBytes == null) {
                result.success(null)
                return
            }
            val trustedInstallers = certBytes.map { bytes ->
                ByteArrayInputStream(bytes).use {
                    CertificateFactory.getInstance(certType).generateCertificate(it)
                }
            }

            try {
                packageManager.requestChecksums(
                    packageName,
                    includeSplits,
                    required!!,
                    trustedInstallers
                ) { checksums ->
                    result.success(
                        checksums.map {
                            it.toMap()
                        }
                    )
                }
            } catch (ex: Exception) {
                result.error(ex.javaClass.name, ex.message, null)
            }
        }
    }

    private fun resolveContentProvider(call: MethodCall, result: Result) {
        val authority = call.argument<String>("authority")
        if (authority == null) {
            result.success(null)
            return
        }
        runWithFlags(
            call,
            result,
            flagFactory = { flags ->
                PackageManager.ComponentInfoFlags.of(flags)
            },
            resultBuilder = { flags ->
                packageManager.resolveContentProvider(authority, flags)?.toMap()
            },
            api33ResultBuilder = { flags ->
                packageManager.resolveContentProvider(authority, flags)?.toMap()
            }
        )
    }

    private fun setApplicationCategoryHint(call: MethodCall, result: Result) {
        if (!isAtLeastAndroid26()) {
            result.success(null)
            return
        }
        providePackageName(call, result)?.let { packageName ->
            call.argument<Int>("categoryHint").run {
                val availableHints = mutableListOf(
                    ApplicationInfo.CATEGORY_UNDEFINED,
                    ApplicationInfo.CATEGORY_GAME,
                    ApplicationInfo.CATEGORY_AUDIO,
                    ApplicationInfo.CATEGORY_VIDEO,
                    ApplicationInfo.CATEGORY_IMAGE,
                    ApplicationInfo.CATEGORY_SOCIAL,
                    ApplicationInfo.CATEGORY_NEWS,
                    ApplicationInfo.CATEGORY_MAPS,
                    ApplicationInfo.CATEGORY_PRODUCTIVITY,
                )
                if (isAtLeastAndroid31()) {
                    availableHints.add(ApplicationInfo.CATEGORY_ACCESSIBILITY)
                }

                if (availableHints.contains(this)) {
                    this
                } else {
                    result.success(null)
                    null
                }
            }?.let {
                packageManager.setApplicationCategoryHint(packageName, it)
                result.success(null)
            }
        }
    }

    private fun setApplicationEnabledSetting(call: MethodCall, result: Result) {
        providePackageName(call, result)?.let { packageName ->
            provideNewState(call, result)?.let { newState ->
                provideFlags(call).run {
                    packageManager.setApplicationEnabledSetting(packageName, newState, this)
                    result.success(null)
                }
            }
        }
    }

    private fun setAutoRevokeWhitelisted(call: MethodCall, result: Result) {
        if (!isAtLeastAndroid30()) {
            result.success(null)
            return
        }
        providePackageName(call, result)?.let { packageName ->
            val whitelisted = call.argument<Boolean>("whitelisted")
            if (whitelisted == null) {
                result.success(null)
                return
            }
            result.success(
                packageManager.setAutoRevokeWhitelisted(packageName, whitelisted)
            )
        }
    }

    private fun setComponentEnabledSetting(call: MethodCall, result: Result) {
        provideComponentName(call, result)?.let { componentName ->
            provideNewState(call, result)?.let { newState ->
                provideFlags(call).run {
                    packageManager.setComponentEnabledSetting(componentName, newState, this)
                    result.success(null)
                }
            }
        }
    }

    private fun setInstallerPackageName(call: MethodCall, result: Result) {
        call.argument<String>("targetPackage").run {
            if (this == null) {
                result.success(null)
            }
            this
        }?.let { targetPackage ->
            try {
                packageManager.setInstallerPackageName(
                    targetPackage,
                    call.argument<String>("installerPackageName")
                )
                result.success(null)
            } catch (ex: SecurityException) {
                result.error(ex.javaClass.name, ex.message, null)
            }
        }
    }

    private fun setMimeGroup(call: MethodCall, result: Result) {
        if (!isAtLeastAndroid30()) {
            result.success(null)
            return
        }
        val mimeGroup = call.argument<String>("mimeGroup")
        val mimeTypes = call.argument<List<String>>("mimeTypes")
        if (mimeGroup == null || mimeTypes == null) {
            result.success(null)
            return
        }
        try {
            packageManager.setMimeGroup(mimeGroup, mimeTypes.toSet())
            result.success(null)
        } catch (ex: java.lang.IllegalArgumentException) {
            result.error(ex.javaClass.name, ex.message, null)
        }
    }

    private fun updateInstantCookie(call: MethodCall, result: Result) {
        if (!isAtLeastAndroid26()) {
            result.success(null)
            return
        }
        val cookie = call.argument<ByteArray>("cookie")
        if (cookie == null) {
            result.success(null)
            return
        }
        try {
            packageManager.updateInstantAppCookie(cookie)
            result.success(null)
        } catch (ex: java.lang.IllegalArgumentException) {
            result.error(ex.javaClass.name, ex.message, null)
        }
    }

    private fun verifyPendingInstall(call: MethodCall, result: Result) {
        val packageId = call.argument<Int>("id")
        if (packageId == null) {
            result.success(null)
            return
        }
        call.argument<Int>("verificationCode").run {
            val isValidCode = listOf(
                PackageManager.VERIFICATION_ALLOW,
                PackageManager.VERIFICATION_REJECT
            ).contains(this)
            if (!isValidCode) {
                result.success(null)
            }
            this
        }?.let { verificationCode ->
            try {
                packageManager.verifyPendingInstall(packageId, verificationCode)
                result.success(null)
            } catch (ex: SecurityException) {
                result.error(ex.javaClass.name, ex.message, null)
            }
        }
    }

    private fun sendDrawableResult(
        drawable: Drawable?,
        quality: Int? = null,
        format: Int = 0,
        result: Result
    ) {
        var nFormat: Bitmap.CompressFormat
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val formats = Bitmap.CompressFormat.values()
            nFormat = formats[format.coerceIn(0..formats.size)]
            if (nFormat == Bitmap.CompressFormat.WEBP) {
                nFormat = Bitmap.CompressFormat.WEBP_LOSSLESS
            }
        } else {
            // List of formats available for devices with API < 30 (see https://developer.android.com/reference/android/graphics/Bitmap.CompressFormat)
            val formats = listOf(
                Bitmap.CompressFormat.JPEG,
                Bitmap.CompressFormat.PNG,
                Bitmap.CompressFormat.WEBP,
            )
            nFormat = formats[format.coerceIn(0..formats.size)]
        }
        result.success(
            drawable.run {
                (this as? Drawable)?.let {
                    val bitmap = Bitmap.createBitmap(
                        it.intrinsicWidth,
                        it.intrinsicHeight,
                        Bitmap.Config.ARGB_8888
                    )
                    val canvas = Canvas(bitmap)
                    it.setBounds(0, 0, canvas.width, canvas.height)
                    it.draw(canvas)
                    ByteArrayOutputStream().use { o ->
                        bitmap.compress(
                            nFormat, quality ?: 100, o
                        )
                        o.toByteArray()
                    }
                }
            }
        )
    }
}
