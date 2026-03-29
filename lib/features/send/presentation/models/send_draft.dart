import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/features/send/domain/entities/fee_rate.dart';

enum FeePreset { slow, standard, fast }

extension FeePresetX on FeePreset {
  String get label {
    return switch (this) {
      FeePreset.slow => 'Slow',
      FeePreset.standard => 'Standard',
      FeePreset.fast => 'Fast',
    };
  }

  String get etaLabel {
    return switch (this) {
      FeePreset.slow => 'Lower priority',
      FeePreset.standard => 'Balanced priority',
      FeePreset.fast => 'Higher priority',
    };
  }

  String get helperText {
    return switch (this) {
      FeePreset.slow =>
        'Use when timing is flexible and you want to save on fees.',
      FeePreset.standard =>
        'A balanced choice for most payments and normal network conditions.',
      FeePreset.fast =>
        'Pays more to improve confirmation speed during busier periods.',
    };
  }
}

class SendDraft {
  const SendDraft({
    required this.address,
    required this.amountBtcText,
    required this.feePreset,
    required this.feeRate,
  });

  factory SendDraft.initial() {
    return const SendDraft(
      address: '',
      amountBtcText: '',
      feePreset: FeePreset.standard,
      feeRate: FeeRate(satsPerVByte: 1),
    );
  }

  final String address;
  final String amountBtcText;
  final FeePreset feePreset;
  final FeeRate feeRate;

  SendDraft copyWith({
    String? address,
    String? amountBtcText,
    FeePreset? feePreset,
    FeeRate? feeRate,
  }) {
    return SendDraft(
      address: address ?? this.address,
      amountBtcText: amountBtcText ?? this.amountBtcText,
      feePreset: feePreset ?? this.feePreset,
      feeRate: feeRate ?? this.feeRate,
    );
  }

  double? get amountBtc => double.tryParse(amountBtcText.trim());

  int? get amountSats {
    final btc = amountBtc;
    if (btc == null || btc <= 0) {
      return null;
    }
    return (btc * AppConstants.satoshisPerBitcoin).round();
  }

  bool get hasValidAddress {
    final candidate = address.trim();
    if (candidate.isEmpty) {
      return false;
    }

    final normalized = candidate.toLowerCase();
    if (normalized.startsWith('tb1')) {
      return candidate.length >= 14;
    }

    final legacyPattern = RegExp(r'^[mn2][a-km-zA-HJ-NP-Z1-9]{25,34}$');
    return legacyPattern.hasMatch(candidate);
  }

  bool get canReview => hasValidAddress && amountSats != null;
}
