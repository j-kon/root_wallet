class BroadcastDatasource {
  Future<String> broadcast(String rawTx) async {
    return 'txid_${DateTime.now().millisecondsSinceEpoch}';
  }
}
