import 'package:share_plus/share_plus.dart';

abstract class ShareService {
  Future<bool> shareText(String text, {String? subject});
}

class SharePlusService implements ShareService {
  const SharePlusService();

  @override
  Future<bool> shareText(String text, {String? subject}) async {
    final result = await Share.share(text, subject: subject);
    return result.status != ShareResultStatus.unavailable;
  }
}
