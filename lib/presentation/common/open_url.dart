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

/// Opens a third-party website (a sponsor) in a new tab / the browser,
/// keeping the app open. Injectable for tests.
typedef OpenWebsite = Future<void> Function(Uri url);

/// Distinct type for Provider: [OpenUrl] has the same function signature.
class WebsiteOpener {
  const WebsiteOpener(this.open);

  final OpenWebsite open;
}

Future<void> openWebsiteInNewTab(Uri url) async {
  await launchUrl(
    url,
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );
}
