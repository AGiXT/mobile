import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

/// Simplified contact model for AGiXT use
class SimpleContact {
  final String displayName;
  final List<String> phones;
  final List<String> emails;

  SimpleContact({
    required this.displayName,
    required this.phones,
    required this.emails,
  });

  Map<String, dynamic> toJson() => {
        'name': displayName,
        'phones': phones,
        'emails': emails,
      };
}

/// Service for accessing device contacts
class ContactsService {
  static final ContactsService _instance = ContactsService._internal();
  factory ContactsService() => _instance;
  ContactsService._internal();

  /// Check if contacts permission is granted
  Future<bool> hasPermission() async {
    final status = await Permission.contacts.status;
    return status.isGranted;
  }

  /// Request contacts permission
  Future<bool> requestPermission() async {
    final status = await Permission.contacts.request();
    return status.isGranted;
  }

  /// Get all contacts (limited)
  Future<List<SimpleContact>> getContacts({int limit = 50}) async {
    try {
      // Check and request permission
      if (!await hasPermission()) {
        final granted = await requestPermission();
        if (!granted) {
          debugPrint('ContactsService: Permission denied');
          return [];
        }
      }

      // Fetch contacts with phone numbers and emails
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      debugPrint('ContactsService: Found ${contacts.length} contacts');

      // Convert to simplified format and limit
      final result = contacts.take(limit).map((contact) {
        return SimpleContact(
          displayName: contact.displayName,
          phones: contact.phones.map((p) => p.number).toList(),
          emails: contact.emails.map((e) => e.address).toList(),
        );
      }).toList();

      return result;
    } catch (e) {
      debugPrint('ContactsService: Error getting contacts: $e');
      return [];
    }
  }

  /// Search contacts by name
  Future<List<SimpleContact>> searchContacts(String query) async {
    try {
      if (query.isEmpty) return [];

      // Check and request permission
      if (!await hasPermission()) {
        final granted = await requestPermission();
        if (!granted) {
          debugPrint('ContactsService: Permission denied');
          return [];
        }
      }

      // Fetch all contacts with properties
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      // Filter by name (case-insensitive)
      final queryLower = query.toLowerCase();
      final matches = contacts.where((contact) {
        final nameLower = contact.displayName.toLowerCase();
        // Check full name match
        if (nameLower.contains(queryLower)) return true;
        // Check first name
        if (contact.name.first.toLowerCase().contains(queryLower)) return true;
        // Check last name
        if (contact.name.last.toLowerCase().contains(queryLower)) return true;
        // Check nickname
        if (contact.name.nickname.toLowerCase().contains(queryLower)) {
          return true;
        }
        return false;
      }).toList();

      debugPrint(
          'ContactsService: Found ${matches.length} contacts matching "$query"');

      // Convert to simplified format
      return matches.map((contact) {
        return SimpleContact(
          displayName: contact.displayName,
          phones: contact.phones.map((p) => p.number).toList(),
          emails: contact.emails.map((e) => e.address).toList(),
        );
      }).toList();
    } catch (e) {
      debugPrint('ContactsService: Error searching contacts: $e');
      return [];
    }
  }

  /// Get a single contact by name (best match)
  Future<SimpleContact?> getContactByName(String name) async {
    final matches = await searchContacts(name);
    if (matches.isEmpty) return null;

    // Return exact match if found, otherwise first result
    final nameLower = name.toLowerCase();
    for (final contact in matches) {
      if (contact.displayName.toLowerCase() == nameLower) {
        return contact;
      }
    }
    return matches.first;
  }

  /// Get phone number for a contact by name
  Future<String?> getPhoneNumberForContact(String name) async {
    final contact = await getContactByName(name);
    if (contact == null || contact.phones.isEmpty) return null;
    return contact.phones.first;
  }
}
