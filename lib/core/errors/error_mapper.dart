import 'package:root_wallet/core/errors/app_exception.dart';
import 'package:root_wallet/core/errors/failure.dart';

enum ErrorContext { general, network, sync, send, broadcast }

String mapErrorToMessage(
  Object error, {
  ErrorContext context = ErrorContext.general,
  bool includeDebugDetails = false,
}) {
  final raw = error.toString();
  final normalized = raw.toLowerCase();

  String message;
  if (normalized.contains('invalid address')) {
    message = 'Invalid address.';
  } else if (normalized.contains('recovery phrase word count')) {
    message = 'Invalid recovery phrase. Enter 12, 18, or 24 words.';
  } else if (normalized.contains('mnemonic') ||
      normalized.contains('bip39') ||
      normalized.contains('invalid word') ||
      normalized.contains('checksum')) {
    message = 'Invalid recovery phrase. Check the words and order.';
  } else if (normalized.contains('mainnet address detected')) {
    message = 'Mainnet address detected. Use a Bitcoin testnet address.';
  } else if (normalized.contains('minimum spendable threshold') ||
      normalized.contains('below the minimum')) {
    message = 'Amount is too small to send.';
  } else if (normalized.contains('insufficient')) {
    message = 'Insufficient balance.';
  } else if (normalized.contains('broadcast')) {
    message = 'Transaction failed to send. Try again.';
  } else if (_isNetworkLike(normalized)) {
    message = switch (context) {
      ErrorContext.sync => 'Couldn\'t sync right now.',
      _ => 'Network issue. Try again.',
    };
  } else {
    message = switch (context) {
      ErrorContext.sync => 'Couldn\'t sync right now.',
      ErrorContext.broadcast => 'Transaction failed to send. Try again.',
      ErrorContext.send => 'Couldn\'t prepare transaction. Try again.',
      ErrorContext.network => 'Network issue. Try again.',
      ErrorContext.general => 'Something went wrong. Please try again.',
    };
  }

  if (includeDebugDetails) {
    return '$message\n\nDebug details: $raw';
  }

  return message;
}

Failure mapErrorToFailure(
  Object error, [
  StackTrace? stackTrace,
  ErrorContext context = ErrorContext.general,
]) {
  if (error is AppException) {
    return Failure(
      message: mapErrorToMessage(error.message, context: context),
      stackTrace: stackTrace,
    );
  }

  return Failure(
    message: mapErrorToMessage(error, context: context),
    stackTrace: stackTrace,
  );
}

bool _isNetworkLike(String normalizedError) {
  return normalizedError.contains('socket') ||
      normalizedError.contains('timeout') ||
      normalizedError.contains('network') ||
      normalizedError.contains('connection');
}
