import 'package:url_launcher/url_launcher.dart';

abstract class UrlLauncherService {
  Future<bool> openExternalUrl(Uri uri);
}

class UrlLauncherServiceImpl implements UrlLauncherService {
  const UrlLauncherServiceImpl();

  @override
  Future<bool> openExternalUrl(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
