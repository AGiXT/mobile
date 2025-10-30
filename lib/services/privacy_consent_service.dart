import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Manages user consent for the current privacy policy version.
class PrivacyConsentService {
  PrivacyConsentService._();

  static const String _boxName = 'agixtAppPrefs';
  static const String policyVersion = '2025-10-29';
  static const String _acceptedKey = 'privacy_policy_${policyVersion}_accepted';
  static const String _acceptedAtKey =
      'privacy_policy_${policyVersion}_accepted_at';

  static Future<Box> _ensureBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      try {
        await Hive.openBox(_boxName);
      } catch (e) {
        debugPrint('Failed to open $_boxName: $e');
        rethrow;
      }
    }

    return Hive.box(_boxName);
  }

  static Future<bool> hasAcceptedLatestPolicy() async {
    final box = await _ensureBox();
    final value = box.get(_acceptedKey, defaultValue: false);
    return value is bool ? value : false;
  }

  static Future<DateTime?> acceptedAt() async {
    final box = await _ensureBox();
    final stored = box.get(_acceptedAtKey);
    if (stored is String) {
      return DateTime.tryParse(stored)?.toLocal();
    }
    return null;
  }

  static Future<void> recordAcceptance() async {
    final box = await _ensureBox();
    final now = DateTime.now().toUtc().toIso8601String();
    await box.put(_acceptedKey, true);
    await box.put(_acceptedAtKey, now);
  }

  static Future<void> clearAcceptance() async {
    final box = await _ensureBox();
    await box.delete(_acceptedKey);
    await box.delete(_acceptedAtKey);
  }
}
