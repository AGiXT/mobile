import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';

@visibleForTesting
void debugLog(Object? data, {String? name,}) {
  if (kDebugMode) {
    scheduleMicrotask(
      () {
        log('$data', name: name ?? '',);
      },
    );
  }
}

@visibleForTesting
void debugPrint(Object? data,) {
  if (kDebugMode) {
    scheduleMicrotask(
      () {
        // ignore: avoid_print
        print(data,);
      },
    );
  }
}