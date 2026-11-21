

import 'package:openreader/core/domain/error/failure.dart';
import 'package:openreader/core/domain/usecase/usecase.dart';
import 'package:openreader/core/presentation/utils/error_handler.dart';
import 'package:openreader/core/presentation/utils/logger.dart';
import 'package:dartz/dartz.dart';

/// A reusable generic function to handle potential exceptions in async tasks
/// and map them to the [Either] type matching [FutureEither<T>].
///
ResultFuture<T> runTask<T>(Future<T> Function() action) async {
  try {
    final result = await action();
    return right(result);
  } catch (error, stackTrace) {
    AppLogger.error('Task execution failed $error', [error, stackTrace]);
    final errorMessage = AppErrorHandler.format(error);

    // Depending on logic, map error strings/types to specific Failure variants
    return left(ServerFailure(errorMessage));
  }
}
