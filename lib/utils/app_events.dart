import 'package:flutter/material.dart';

/// A simple event bus to allow communication between screens
class AppEvents {
  static final List<VoidCallback> _listeners = [];
  static final List<void Function(bool)> _locationListeners = [];

  /// Add a listener that will be called when data changes
  static void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// Remove a listener
  static void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners that data has changed
  static void notifyDataChanged() {
    for (final listener in _listeners) {
      listener();
    }
  }

  /// Add a listener for location settings changes
  static void addLocationListener(void Function(bool enabled) listener) {
    _locationListeners.add(listener);
  }

  /// Remove a location listener
  static void removeLocationListener(void Function(bool enabled) listener) {
    _locationListeners.remove(listener);
  }

  /// Notify all location listeners that location settings changed
  static void notifyLocationSettingsChanged(bool enabled) {
    for (final listener in _locationListeners) {
      listener(enabled);
    }
  }
}
