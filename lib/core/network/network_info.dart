abstract class NetworkInfo {
  Future<bool> get isConnected;
}

class AlwaysOnlineNetworkInfo implements NetworkInfo {
  const AlwaysOnlineNetworkInfo();

  @override
  Future<bool> get isConnected async => true;
}
