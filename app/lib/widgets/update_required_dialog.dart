import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_info.dart';
import '../config/language_provider.dart';

/// Shown when the server answers UPDATE_REQUIRED: this app version is too old
/// to play online.
Future<void> showUpdateRequiredDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.translate('update_required_title', listen: false)),
      content: Text(ctx.translate('update_required_body', listen: false)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(ctx.translate('update_required_later', listen: false)),
        ),
        FilledButton(
          onPressed: () {
            launchUrl(AppInfo.storeUri, mode: LaunchMode.externalApplication);
            Navigator.of(ctx).pop();
          },
          child: Text(ctx.translate('update_required_action', listen: false)),
        ),
      ],
    ),
  );
}
