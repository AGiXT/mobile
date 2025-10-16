package lab.neruno.android_package_manager

import android.content.pm.*
import android.os.Build
import android.os.Bundle
import androidx.annotation.ChecksSdkIntAtLeast
import androidx.annotation.RequiresApi
import java.security.PublicKey
import java.security.cert.Certificate
import java.security.cert.CertificateEncodingException

fun ActivityInfo.toMap(): Map<String, Any?> {
    val componentInfo: ComponentInfo = this
    return componentInfo.toMap().let { cmpInfo ->
        val baseMap = mutableMapOf<String, Any?>(
            "theme" to theme,
            "launchMode" to launchMode,
            "documentLaunchMode" to documentLaunchMode,
            "persistableMode" to persistableMode,
            "maxRecents" to maxRecents,
            "permission" to permission,
            "taskAffinity" to taskAffinity,
            "targetActivity" to targetActivity,
            "flags" to flags,
            "screenOrientation" to screenOrientation,
            "configChanges" to configChanges,
            "softInputMode" to softInputMode,
            "uiOptions" to uiOptions,
            "parentActivityName" to parentActivityName,
            "themeResource" to themeResource,
        ).apply {
            putAll(cmpInfo)
        }
        if (isAtLeastAndroid24()) {
            baseMap["windowLayout"] = windowLayout?.toMap()
            if (isAtLeastAndroid26()) {
                baseMap["colorMode"] = colorMode
            }
        }
        baseMap.toMap()
    }
}

fun ApplicationInfo.toMap(): Map<String, Any?> {
    val packageItemInfo: PackageItemInfo = this
    return packageItemInfo.toBaseMap().let {
        val baseMap = mutableMapOf(
            "backupAgentName" to backupAgentName,
            "className" to className,
            "compatibleWidthLimitDp" to compatibleWidthLimitDp,
            "dataDir" to dataDir,
            "descriptionRes" to descriptionRes,
            "enabled" to enabled,
            "flags" to flags,
            "largestWidthLimitDp" to largestWidthLimitDp,
            "manageSpaceActivityName" to manageSpaceActivityName,
            "nativeLibraryDir" to nativeLibraryDir,
            "permission" to permission,
            "processName" to processName,
            "publicSourceDir" to publicSourceDir,
            "requiresSmallestWidthDp" to requiresSmallestWidthDp,
            "sharedLibraryFiles" to sharedLibraryFiles?.toList(),
            "sourceDir" to sourceDir,
            "splitPublicSourceDirs" to splitPublicSourceDirs?.toList(),
            "splitSourceDirs" to splitSourceDirs?.toList(),
            "targetSdkVersion" to targetSdkVersion,
            "taskAffinity" to taskAffinity,
            "theme" to theme,
            "uiOptions" to uiOptions,
            "uid" to uid
        ).apply {
            putAll(it)
        }

        if (isAtLeastAndroid24()) {
            baseMap += mapOf(
                "deviceProtectedDataDir" to deviceProtectedDataDir,
                "minSdkVersion" to minSdkVersion
            )

            if (isAtLeastAndroid26()) {
                baseMap += mapOf(
                    "category" to category,
                    "splitNames" to splitNames?.toList(),
                    "storageUuid" to storageUuid.toString()
                )

                if (isAtLeastAndroid27()) {
                    baseMap["isVirtualPreload"] = isVirtualPreload

                    if (isAtLeastAndroid28()) {
                        baseMap["appComponentFactory"] = appComponentFactory

                        if (isAtLeastAndroid29()) {
                            baseMap += mapOf(
                                "isProfileableByShell" to isProfileableByShell,
                                "isResourceOverlay" to isResourceOverlay
                            )

                            if (isAtLeastAndroid30()) {
                                baseMap["gwpAsanMode"] = gwpAsanMode

                                if (isAtLeastAndroid31()) {
                                    baseMap += mapOf(
                                        "compileSdkVersion" to compileSdkVersion,
                                        "compileSdkVersionCodename" to compileSdkVersionCodename,
                                        "isProfileable" to isProfileable,
                                        "memtagMode" to memtagMode,
                                        "nativeHeapZeroInitialized" to nativeHeapZeroInitialized,
                                        "requestRawExternalStorageAccess" to requestRawExternalStorageAccess,
                                        "areAttributionsUserVisible" to areAttributionsUserVisible()
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }

        baseMap.toMap()
    }
}

@RequiresApi(Build.VERSION_CODES.S)
fun ApkChecksum.toMap(): Map<String, Any?> = mapOf(
    "installerCertificate" to installerCertificate?.toMap(),
    "installerPackageName" to installerPackageName,
    "splitName" to splitName,
    "type" to type,
    "value" to value
)

@RequiresApi(Build.VERSION_CODES.S)
fun Attribution.toMap(): Map<String, Any?> = mapOf(
    "label" to label,
    "tag" to tag
)

fun Bundle.toMap(): Map<String, Any?> = this.keySet().map {
    val value = get(it).run {
        if (this is Array<*>) {
            this.toList()
        } else {
            this
        }
    }
    Pair<String, Any?>(it, value)
}.run {
    mapOf(*this.toTypedArray())
}

fun Certificate.toMap(): Map<String, Any?> = mapOf(
    "encoded" to try {
        encoded
    } catch (ex: CertificateEncodingException) {
        null
    },
    "publicKey" to publicKey?.toMap(),
    "type" to type
)

fun ComponentInfo.toMap(): Map<String, Any?> {
    val packageItemInfo: PackageItemInfo = this
    return packageItemInfo.toBaseMap().let { pkgItemInfo ->
        val baseMap = mutableMapOf(
            "applicationInfo" to applicationInfo.toMap(),
            "processName" to processName,
            "descriptionRes" to descriptionRes,
            "enabled" to enabled,
            "exported" to exported,
            "isEnabled" to isEnabled,
            "iconResource" to iconResource,
            "logoResource" to logoResource,
            "bannerResource" to bannerResource
        ).apply {
            putAll(pkgItemInfo)
        }

        if (isAtLeastAndroid24()) {
            baseMap["directBootAware"] = directBootAware
            if (isAtLeastAndroid26()) {
                baseMap["splitName"] = splitName
                if (isAtLeastAndroid31()) {
                    baseMap["attributionTags"] = attributionTags.toList()
                }
            }
        }
        baseMap.toMap()
    }
}

fun ConfigurationInfo.toMap(): Map<String, Any?> = mapOf(
    "glEsVersion" to glEsVersion,
    "reqGlEsVersion" to reqGlEsVersion,
    "reqInputFeatures" to reqInputFeatures,
    "reqKeyboardType" to reqKeyboardType,
    "reqNavigation" to reqNavigation,
    "reqTouchScreen" to reqTouchScreen
)

fun FeatureGroupInfo.toMap(): Map<String, Any?> = mapOf(
    "features" to features.map { it.toMap() }
)

fun FeatureInfo.toMap(): Map<String, Any?> = mapOf(
    "name" to name,
    "version" to if (isAtLeastAndroid24()) version else null,
    "reqGlEsVersion" to reqGlEsVersion,
    "flags" to flags,
    "glEsVersion" to glEsVersion,
)

@RequiresApi(Build.VERSION_CODES.R)
fun InstallSourceInfo.toMap(): Map<String, Any?> = mapOf(
    "initiatingPackageName" to initiatingPackageName,
    "installingPackageName" to installingPackageName,
    "originatingPackageName" to originatingPackageName,
    "initiatingPackageSigningInfo" to initiatingPackageSigningInfo?.toMap()
)

fun InstrumentationInfo.toMap(): Map<String, Any?> {
    val packageItemInfo: PackageItemInfo = this
    return packageItemInfo.toBaseMap().let {
        val baseMap = mutableMapOf(
            "targetPackage" to targetPackage,
            "sourceDir" to sourceDir,
            "publicSourceDir" to publicSourceDir,
            "splitSourceDirs" to splitSourceDirs?.toList<String>(),
            "splitPublicSourceDirs" to splitPublicSourceDirs?.toList<String>(),
            "dataDir" to dataDir,
            "handleProfiling" to handleProfiling,
            "functionalTest" to functionalTest,
        ).apply {
            putAll(it)
        }

        if (isAtLeastAndroid26()) {
            baseMap += mapOf(
                "splitNames" to splitNames?.toList<String>(),
                "targetProcesses" to targetProcesses
            )
        }
        baseMap.toMap()
    }
}

@RequiresApi(Build.VERSION_CODES.Q)
fun ModuleInfo.toMap(): Map<String, Any?> = mapOf(
    "isHidden" to isHidden,
    "name" to name.toString(),
    "packageName" to packageName
)

fun PackageInfo.toMap(): Map<String, Any?> {
    val baseMap = mutableMapOf(
        "packageName" to packageName,
        "splitNames" to splitNames?.toList<String>(),
        "versionName" to versionName,
        "versionCode" to versionCode,
        "sharedUserId" to sharedUserId,
        "sharedUserLabel" to sharedUserLabel,
        "applicationInfo" to applicationInfo?.toMap(),
        "firstInstallTime" to firstInstallTime,
        "lastUpdateTime" to lastUpdateTime,
        "gids" to gids?.toList(),
        "activities" to activities?.toList()?.map {
            it.toMap()
        },
        "receivers" to receivers?.map {
            it.toMap()
        },
        "services" to services?.map {
            it.toMap()
        },
        "providers" to providers?.map {
            it.toMap()
        },
        "instrumentation" to instrumentation?.map {
            it.toMap()
        },
        "permissions" to permissions?.map {
            it.toMap()
        },
        "requestedPermissions" to requestedPermissions?.toList(),
        "requestedPermissionsFlags" to requestedPermissionsFlags?.toList(),
        "configPreferences" to configPreferences?.map {
            it.toMap()
        },
        "reqFeatures" to reqFeatures?.map {
            it.toMap()
        },
        "featureGroups" to featureGroups?.toList()?.map {
            it.features.toList().map { info ->
                info.toMap()
            }
        },
        "installLocation" to installLocation,
    )

    if (isAtLeastAndroid22()) {
        baseMap += mapOf(
            "baseRevisionCode" to baseRevisionCode,
            "splitRevisionCodes" to splitRevisionCodes
        )

        if (isAtLeastAndroid28()) {
            baseMap += mapOf(
                "longVersionCode" to longVersionCode,
                "signingInfo" to signingInfo?.toMap()
            )

            if (isAtLeastAndroid29()) {
                baseMap["isApex"] = isApex

                if (isAtLeastAndroid31()) {
                    baseMap["attributions"] = attributions?.map {
                        Pair(it.label, it.tag)
                    }?.let {
                        mapOf(*it.toTypedArray())
                    }
                }
            }
        }
    }

    return baseMap.toMap()
}

fun PackageItemInfo.toBaseMap(): MutableMap<String, Any?> = mutableMapOf(
    "name" to name,
    "packageName" to packageName,
    "labelRes" to labelRes,
    "nonLocalizedLabel" to nonLocalizedLabel,
    "icon" to icon,
    "banner" to banner,
    "logo" to logo,
    "metaData" to metaData?.toMap(),
)

fun PermissionGroupInfo.toMap(): Map<String, Any?> {
    val packageItemInfo: PackageItemInfo = this
    return packageItemInfo.toBaseMap().let {
        mutableMapOf<String, Any?>(
            "descriptionRes" to descriptionRes,
            "flags" to flags,
            "priority" to priority,
            "packageItemInfo" to toBaseMap().toMap(),
        ).apply {
            putAll(it)
        }.toMap()
    }
}

fun PermissionInfo.toMap(): Map<String, Any?> {
    val packageItemInfo: PackageItemInfo = this
    return packageItemInfo.toBaseMap().let {
        val baseResult = mutableMapOf(
            "descriptionRes" to this.descriptionRes,
            "flags" to this.flags,
            "group" to this.group,
            "nonLocalizedDescription" to this.nonLocalizedDescription,
        ).apply {
            putAll(it)
        }

        if (isAtLeastAndroid28()) {
            baseResult += mapOf(
                "protection" to this.protection,
                "protectionFlags" to this.protectionFlags
            )
        }
        baseResult.toMap()
    }
}

@RequiresApi(Build.VERSION_CODES.S)
fun PackageManager.Property.toMap(): Map<String, Any?> = mapOf(
    "className" to className,
    "name" to name,
    "packageName" to packageName,
    "value" to when {
        isBoolean -> boolean
        isFloat -> float
        isInteger -> integer
        isResourceId -> resourceId
        isString -> string
        else -> null
    }
)

fun ProviderInfo.toMap(): Map<String, Any?> {
    val componentInfo: ComponentInfo = this
    return componentInfo.toMap().let {
        val baseMap = mutableMapOf<String, Any?>(
            "authority" to authority,
            "readPermission" to readPermission,
            "writePermission" to writePermission,
            "grantUriPermissions" to grantUriPermissions,
            "multiprocess" to multiprocess,
            "initOrder" to initOrder,
            "flags" to flags,
//            "pathPermissions" to pathPermissions,
//            "uriPermissionPatterns" to uriPermissionPatterns,
        ).apply { putAll(it) }
        if (isAtLeastAndroid29()) {
            baseMap["forceUriPermissions"] = forceUriPermissions
        }
        baseMap.toMap()
    }
}

fun PublicKey.toMap(): Map<String, Any?> = mapOf(
    "algorithm" to algorithm,
    "encoded" to encoded,
    "format" to format
)

fun ResolveInfo.toMap(): Map<String, Any?> {
    val baseMap = mutableMapOf(
        "activityInfo" to activityInfo?.toMap(),
        "filter" to null, // TODO: Handle IntentFilter
        "icon" to icon,
        "iconResource" to iconResource,
        "isDefault" to isDefault,
        "labelRes" to labelRes,
        "match" to match,
        "nonLocalizedLabel" to nonLocalizedLabel?.toString(),
        "preferredOrder" to preferredOrder,
        "priority" to priority,
        "providerInfo" to providerInfo?.toMap(),
        "resolvePackageName" to resolvePackageName,
        "serviceInfo" to serviceInfo?.toMap(),
        "specificIndex" to specificIndex
    )

    if (isAtLeastAndroid26()) {
        baseMap["isInstantAppAvailable"] = isInstantAppAvailable
        if (isAtLeastAndroid30()) {
            baseMap["isCrossProfileIntentForwarderActivity"] = isCrossProfileIntentForwarderActivity
        }
    }
    return baseMap.toMap()
}

fun ServiceInfo.toMap(): Map<String, Any?> {
    val componentInfo: ComponentInfo = this
    return componentInfo.toMap().let {
        mutableMapOf<String, Any?>(
            "permission" to permission,
            "flags" to flags,
            "foregroundServiceType" to if (isAtLeastAndroid29()) foregroundServiceType else null
        ).apply { putAll(it) }.toMap()
    }
}

@RequiresApi(Build.VERSION_CODES.O)
fun SharedLibraryInfo.toMap(): Map<String, Any?> {
    val baseMap = mutableMapOf<String, Any?>(
        "name" to name,
        "type" to type
    )
    if (isAtLeastAndroid28()) {
        baseMap += mapOf(
            "declaringPackage" to declaringPackage.toMap(),
            "dependentPackages" to dependentPackages.map {
                it.toMap()
            },
            "longVersion" to longVersion
        )
    }
    return baseMap
}

@RequiresApi(Build.VERSION_CODES.P)
fun SigningInfo.toMap(): Map<String, Any?> = mapOf(
    "signingCertificateHistory" to signingCertificateHistory?.map {
        it.toByteArray()
    },
    "apkContentsSigners" to apkContentsSigners?.map {
        it.toByteArray()
    },
    "hasPastSigningCertificates" to hasPastSigningCertificates(),
    "hasMultipleSigners" to hasMultipleSigners()
)

@RequiresApi(Build.VERSION_CODES.P)
fun VersionedPackage.toMap(): Map<String, Any?> = mapOf(
    "longVersionCode" to longVersionCode,
    "packageName" to packageName
)

@Suppress("SAFE_CALL_WILL_CHANGE_NULLABILITY", "UNNECESSARY_SAFE_CALL")
@RequiresApi(Build.VERSION_CODES.N)
fun ActivityInfo.WindowLayout.toMap(): Map<String, Any?> = mapOf(
    "gravity" to gravity,
    "height" to height,
    "heightFraction" to heightFraction?.toDouble(),
    "minHeight" to minHeight,
    "minWidth" to minWidth,
    "width" to width,
    "widthFraction" to widthFraction?.toDouble(),
)