import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service for sending SMS messages
class SmsService {
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;
  SmsService._internal();

  /// Check if SMS permission is granted
  Future<bool> hasPermission() async {
    final status = await Permission.sms.status;
    return status.isGranted;
  }

  /// Request SMS permission
  Future<bool> requestPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  /// Send an SMS message
  ///
  /// This opens the default SMS app with the message pre-filled.
  /// For direct sending without user interaction, you would need
  /// additional native integration with telephony APIs.
  ///
  /// Returns true if the SMS app was successfully launched.
  Future<bool> sendSms({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      // Clean phone number - remove common formatting
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');

      debugPrint('SmsService: Sending SMS to $cleanNumber');
      debugPrint(
          'SmsService: Message: ${message.substring(0, message.length > 50 ? 50 : message.length)}...');

      // Use URL launcher to open SMS app
      // This is the most reliable cross-platform approach
      final uri = Uri(
        scheme: 'sms',
        path: cleanNumber,
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        debugPrint('SmsService: SMS app launched successfully');
        return true;
      }

      // Fallback: try without body parameter (some devices don't support it)
      final fallbackUri =
          Uri.parse('sms:$cleanNumber?body=${Uri.encodeComponent(message)}');
      if (await canLaunchUrl(fallbackUri)) {
        await launchUrl(fallbackUri);
        debugPrint('SmsService: SMS app launched with fallback URI');
        return true;
      }

      // Second fallback: just open SMS app with number
      final simpleUri = Uri.parse('sms:$cleanNumber');
      if (await canLaunchUrl(simpleUri)) {
        await launchUrl(simpleUri);
        debugPrint(
            'SmsService: SMS app launched with simple URI (message may not be pre-filled)');
        return true;
      }

      debugPrint('SmsService: Could not launch SMS app');
      return false;
    } catch (e) {
      debugPrint('SmsService: Error sending SMS: $e');
      return false;
    }
  }

  /// Send SMS directly using platform channels (if implemented)
  ///
  /// This would require native Android/iOS code to send SMS without
  /// opening the SMS app. This is more intrusive and requires
  /// SEND_SMS permission on Android.
  ///
  /// For now, this falls back to the URL launcher method.
  Future<bool> sendSmsDirect({
    required String phoneNumber,
    required String message,
  }) async {
    // For truly direct SMS sending without user interaction,
    // you would need to implement a MethodChannel to native code.
    //
    // Android would use SmsManager:
    // SmsManager smsManager = SmsManager.getDefault();
    // smsManager.sendTextMessage(phoneNumber, null, message, null, null);
    //
    // iOS doesn't allow direct SMS sending without user interaction
    // due to privacy restrictions.
    //
    // For MVP, we use the URL launcher approach which opens the SMS app.
    // The user still needs to tap "Send" but the message is pre-filled.

    debugPrint('SmsService: Direct SMS not implemented, using URL launcher');
    return sendSms(phoneNumber: phoneNumber, message: message);
  }
}
