# android_package_manager [![Pub](https://img.shields.io/pub/v/android_package_manager.svg)](https://pub.dartlang.org/packages/android_package_manager)

Provides access to Android's native PackageManager API to fetch various information, such as installed applications, packages, permissions, etc.

## About this Package
This plugin is purposed for Android use only. Allowing easier access to most commonly used methods of Android's [PackageManager](https://developer.android.com/reference/android/content/pm/PackageManager) API. Adapted a few methods from existing package [package_manager](https://pub.dev/packages/package_manager) which seems not to be maintained recently.

## Getting Started

Importing:
```dart
import package:android_package_manager/android_package_manager.dart;
```
Singleton access example:
```dart
final pm = AndroidPackageManager();
```

## Available Methods
Please see official documentation of [PackageManager](https://developer.android.com/reference/android/content/pm/PackageManager) API.  
**Disclaimer**: I have been trying to adapt most of the available methods. Done with some simple instrumentation tests.  
Tested methods can be found under `example/integration_test` directory.

Example Flutter app demonstrates the [getInstalledPackages](https://developer.android.com/reference/android/content/pm/PackageManager#getInstalledPackages(int)) method.

## Side Notes
Please take note of the `flags` optional argument on some of the methods. These will affect the 
output of the request to the APIs. For example, `PackageInfo` won't show any permissions info if 
the flag for `GET_PERMISSIONS` is not specified.

## Optional permissions
By default, the list of installed apps is limited on Android 11 (API level 30) and higher. Read more about it [here](https://developer.android.com/training/package-visibility). To access the full list of apps installed on a device, add the following permission to your `AndroidManifest.xml` file:
```xml
<uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" />
```

## TO-DOs
- Proper documentation
- DartDocs
- Adjusting some methods to be Android Tiramisu compatible (deprecating some methods)
- Documenting bitmask values
- Separating interfaces into a separate package (maybe)

## Issues
Feel free to file issues or any suggestions [here](https://github.com/nsNeruno/android_package_manager/issues)