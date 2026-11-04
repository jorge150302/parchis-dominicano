import 'package:package_info_plus/package_info_plus.dart';

/// Identity of the installed app, loaded once at startup.
class AppInfo {
  /// Build number (the `+N` in pubspec `version`), sent to the server so it
  /// can ask outdated apps to update. 0 until [load] runs.
  static int build = 0;
  static String packageName = '';

  static Future<void> load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      build = int.tryParse(info.buildNumber) ?? 0;
      packageName = info.packageName;
    } catch (_) {
      // Unsupported platform (tests): keep the defaults.
    }
  }

  /// Store page for this app.
  static Uri get storeUri => Uri.parse(
        'https://play.google.com/store/apps/details?id=$packageName',
      );
}
