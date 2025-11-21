import 'package:shared_preferences/shared_preferences.dart';

/// Tracks lightweight onboarding prompts so they are only shown once per device.
class OnboardingService {
  static const String _permissionsPromptKey =
      'onboarding_permissions_prompt_v1';
  static const String _glassesPromptKey = 'onboarding_glasses_prompt_v1';

  /// Returns true if the permission management screen still needs to appear
  /// before login on first app launch.
  static Future<bool> shouldShowPermissionManager() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_permissionsPromptKey) ?? false);
  }

  /// Persists that the permission management screen has been shown.
  static Future<void> markPermissionManagerShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_permissionsPromptKey, true);
  }

  /// Whether we should prompt the user to connect their Even Realities glasses
  /// after successfully logging in.
  static Future<bool> shouldShowGlassesPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_glassesPromptKey) ?? false);
  }

  /// Persists that the glasses connection prompt has been acknowledged so we
  /// do not show it again.
  static Future<void> markGlassesPromptCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_glassesPromptKey, true);
  }
}
