import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

class NetworkChecker {
  static Future<bool> hasConnection() async {
    if (kIsWeb) return true;
    try {
      final result = await InternetAddress.lookup('connectivitycheck.gstatic.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
