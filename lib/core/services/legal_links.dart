import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

enum LegalPage {
  terms('Terms of Service', 'terms'),
  privacy('Privacy Policy', 'privacy');

  const LegalPage(this.label, this.path);
  final String label;
  final String path;
  Uri get uri => Uri.https('mydayflower.com', '/$path');
}

final legalLinkLauncherProvider = Provider<Future<bool> Function(Uri)>(
    (ref) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication));

Future<void> openLegalPage(
    BuildContext context, WidgetRef ref, LegalPage page) async {
  var opened = false;
  try {
    opened = await ref.read(legalLinkLauncherProvider)(page.uri);
  } catch (_) {
    // A failed browser launch must not look like a successful tap.
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Could not open ${page.label}. Please try again.'),
      action: SnackBarAction(
          label: 'Retry', onPressed: () => openLegalPage(context, ref, page)),
    ));
  }
}
