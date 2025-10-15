## 0.7.1

* Added `hasSigningCertificate` method (including the option to use UID)
* Added enum `CertificateType` in conjunction with the support for `hasSigningCertificate`
* Instance of `AndroidPackageManager` is now a `const`

## 0.7.0

* Raised Target SDK to 34
* Fixed casting error when running using flags on SDK INT >= 33
* Fixed parsing of `PackageInfo` and reading of permissions. Please see note under example or see [#12](https://github.com/nsNeruno/android_package_manager/issues/12)
* Fixed native parsing of various related Info entities
* Exposed more fields under `PackageInfo`, including `longVersionCode` (Issue [#10](https://github.com/nsNeruno/android_package_manager/issues/10))
* Updated example
* Updated instrumentation test for Installed Package listing
* Updated `README.md`

## 0.6.0

* Enabled support for latest stable Flutter versions (raised max SDK constraints to 4.0.0)
* \[PackageInfo\] Added [versionCode](https://developer.android.com/reference/android/content/pm/PackageInfo#versionCode) property (by [ImranR98](https://github.com/ImranR98) under [#11](https://github.com/nsNeruno/android_package_manager/pull/11))
* Updated `example`
* \[Native/Experimental\] Added possibility of using multiple source of `PackageManager` from different `Context`s if the plugin is being used under Isolates (by [ImranR98](https://github.com/ImranR98) under [#11](https://github.com/nsNeruno/android_package_manager/pull/11))
* Added [getApplicationLabel](https://developer.android.com/reference/android/content/pm/PackageManager#getApplicationLabel(android.content.pm.ApplicationInfo)) method (by [ImranR98](https://github.com/ImranR98) under [#11](https://github.com/nsNeruno/android_package_manager/pull/11))

## 0.5.4

* Added `getInstallSourceInfo` and access to deprecated `getInstallerPackageName` for devices running versions below `Android R` (*SDK Int* `30`)
* Separated some integration test files

## 0.5.3

* Added missing support for Android's 
[AdaptiveIconDrawable](https://developer.android.com/reference/android/graphics/drawable/AdaptiveIconDrawable) 
when fetching App Icons (credits to [PiotrZPL](https://github.com/PiotrZPL) via PR [#6](https://github.com/nsNeruno/android_package_manager/pull/6))

## 0.5.2+1

* Attribution of fixes on `0.5.2` to [PiotrZPL](https://github.com/PiotrZPL)
* Fixed warning of unused import on `ComponentInfo` class

## 0.5.2

* Fixed Image Format enum ordering per latest Android API Documentation
* Raised minimum Dart SDK version to `2.19.3`

## 0.5.0

* Added access to Activity Icon, Logo, and Application Icon by `packageName`
* Updated `example` & `integration_test` to showcase Application Icon rendering

## 0.4.0

* Fixed `ApplicationInfo` parsing failure from various `ComponentInfo`s when requesting for Installed Packages
* Fixed `requestedPermissions` parsing failure on querying `PackageInfo`
* Updated integration test for showing example of querying permissions from installed packages using `PackageInfoFlags`. Issue reference [here](https://github.com/nsNeruno/android_package_manager/issues/4)

## 0.3.2

* Fixed `ApplicationInfo` parsing failure due to possibly null directories and process name on *Android 13* (credits to [codercengiz](https://github.com/codercengiz))

## 0.3.0

* Raised Target SDK Version to `33` (Android 13 | Codename: `TIRAMISU`)
* Added access to `canPackageQuery` method which is exclusive to Android 13
* Added support for non-deprecated alternatives of some APIs on Android 13
* Raised plugin's Gradle version to `7.2.2`

## 0.2.0

* Fixed `getInstalledPackages` results having null `applicationInfo` (reported issue [here](https://github.com/nsNeruno/android_package_manager/issues/1) | credits to [@pablo8899](https://github.com/pablo8899))
* Optimized platform Map data parsing from Android to Dart
* Updated example's integration test to include check for `applicationInfo` existence after 
querying for packages
* Bumped minimum Dart SDK to `2.18.0`
* Updated target SDK of `example` app to `33`

## 0.1.0

* Initial Release
