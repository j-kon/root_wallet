import 'package:root_wallet/features/wallet/data/dtos/tx_dto.dart';
import 'package:root_wallet/features/wallet/domain/entities/tx_item.dart';

class TxMapper {
  const TxMapper();

  TxItem fromDto(TxDto dto) {
    return TxItem(
      txId: dto.txId,
      amountSats: dto.amountSats,
      timestamp: dto.timestamp,
      isIncoming: dto.direction == TxDirection.incoming,
      status: dto.status == TxStatus.pending
          ? TxItemStatus.pending
          : TxItemStatus.confirmed,
      feeSats: dto.feeSats,
      confirmations: dto.confirmations,
    );
  }
}
