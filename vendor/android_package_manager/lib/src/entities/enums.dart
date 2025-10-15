enum CheckPermissionStatus {
  granted,
  denied,
}

enum ComponentEnabledState {
  stateDefault,
  stateEnabled,
  stateDisabled,
  stateDisabledUser,
  stateDisabledUntilUsed,
}

enum ComponentType {
  unknown,
  activity,
  receiver,
  service,
  provider,
  application,
}

enum SignatureCheckResult {
  match,
  neitherSigned,
  firstNotSigned,
  secondNotSigned,
  noMatch,
  unknownPackage,
}

enum ActivityResourceType {
  banner,
  icon,
  logo,
}

enum ProtectionLevel {
  normal,
  dangerous,
  signature,
  signatureOrSystem,
  internal,
}

enum ConfigInputFeatures {
  hardKeyboard,
  fiveWayNav,
}

enum PreferredKeyboardType {
  undefined,
  noKeys,
  qwerty,
  twelveKey,
}

enum NavigationAvailability {
  undefined,
  dPad,
  trackball,
  wheel,
}

enum ConfigTouchScreen {
  noTouch,
  stylus,
  finger,
}

enum AndroidInstallLocation {
  unspecified,
  auto,
  internalOnly,
  preferExternal,
}

enum LaunchMode {
  multiple,
  singleTop,
  singleTask,
  singleInstance,
  singleInstancePerTask,
}

enum DocumentLaunchMode {
  none,
  intoExisting,
  always,
  never,
}

enum PersistableMode {
  rootOnly,
  never,
  acrossReboots,
}

enum ColorMode {
  defaultColor,
  wideColorGamut,
  hdr,
}

/// Begins at -2
enum ScreenOrientation {
  unset,
  unspecified,
  landscape,
  portrait,
  user,
  behind,
  sensor,
  noSensor,
  sensorLandscape,
  sensorPortrait,
  reverseLandscape,
  reversePortrait,
  fullSensor,
  userLandscape,
  userPortrait,
  fullUser,
  locked,
}

enum SoftInputState {
  unspecified,
  unchanged,
  hidden,
  alwaysHidden,
  visible,
  alwaysVisible,
}

/// Begins at -1
enum RotationAnimation {
  unspecified,
  rotate,
  crossfade,
  jumpcut,
  seamless,
}

enum VerificationCode {
  allow,
  reject,
}

/// Implementing the same order of compression formats as: https://developer.android.com/reference/android/graphics/Bitmap.CompressFormat
enum BitmapCompressFormat {
  jpeg,
  png,
  webp,
  webpLossy,
  webpLossless,
}

enum CertificateType {
  rawX509,
  sha256,
}