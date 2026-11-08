import 'package:url_launcher/url_launcher.dart';

/// Opens a provider page (Stripe Checkout, onboarding) in the same tab on
/// the web and in the browser on mobile. Injectable for tests.
typedef OpenUrl = Future<void> Function(Uri url);

Future<void> openExternalUrl(Uri url) async {
  await launchUrl(
    url,
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_self',
  );
}
