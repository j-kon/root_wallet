import 'package:root_wallet/core/errors/app_exception.dart';
import 'package:root_wallet/core/errors/failure.dart';

Failure mapErrorToFailure(Object error, [StackTrace? stackTrace]) {
  if (error is AppException) {
    return Failure(message: error.message, stackTrace: stackTrace);
  }

  return Failure(message: 'Unexpected error: $error', stackTrace: stackTrace);
}
