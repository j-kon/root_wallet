class PsbtInputItem {
  const PsbtInputItem({
    required this.outpoint,
    required this.txid,
    required this.vout,
    this.amountSats,
    this.isMine = false,
    this.sequence,
  });

  final String outpoint;
  final String txid;
  final int vout;
  final int? amountSats;
  final bool isMine;
  final int? sequence;
}

class PsbtOutputItem {
  const PsbtOutputItem({
    required this.amountSats,
    required this.scriptPubkeyHex,
    this.address,
    this.isMine = false,
    this.isChange = false,
  });

  final int amountSats;
  final String scriptPubkeyHex;
  final String? address;
  final bool isMine;
  final bool isChange;
}

class PsbtDetails {
  const PsbtDetails({
    required this.rawPsbtBase64,
    required this.txid,
    required this.inputs,
    required this.outputs,
    required this.totalOutputSats,
    this.totalInputSats,
    this.feeSats,
    this.feeRateSatPerVb,
    required this.isFinalized,
    required this.hasUnownedInputs,
    required this.canSign,
    this.network = 'testnet',
  });

  final String rawPsbtBase64;
  final String txid;
  final List<PsbtInputItem> inputs;
  final List<PsbtOutputItem> outputs;
  final int totalOutputSats;
  final int? totalInputSats;
  final int? feeSats;
  final double? feeRateSatPerVb;
  final bool isFinalized;
  final bool hasUnownedInputs;
  final bool canSign;
  final String network;
}
