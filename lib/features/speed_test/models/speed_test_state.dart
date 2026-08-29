enum SpeedTestPhase {
  idle,
  ping,
  download,
  upload,
  completed,
  error,
}

enum SpeedTestLifecycle {
  idle,
  preparing,
  testing,
  stopping,
  completed,
  failed,
}

enum SpeedTestErrorKind {
  cancelled,
  networkChanged,
  timeout,
  noInternet,
  server,
  tlsHttp,
  unexpected,
}

class SpeedTestException implements Exception {
  final SpeedTestErrorKind kind;
  final String message;
  final Object? cause;

  const SpeedTestException(this.kind, this.message, {this.cause});

  @override
  String toString() => message;
}

class SpeedTestCancelledException extends SpeedTestException {
  const SpeedTestCancelledException()
      : super(SpeedTestErrorKind.cancelled, 'Speed test cancelled');
}

class SpeedTestNetworkChangedException extends SpeedTestException {
  const SpeedTestNetworkChangedException()
      : super(SpeedTestErrorKind.networkChanged, 'Network changed during test');
}

class SpeedTestTimeoutException extends SpeedTestException {
  const SpeedTestTimeoutException([String message = 'Network request timed out'])
      : super(SpeedTestErrorKind.timeout, message);
}

class SpeedTestNoInternetException extends SpeedTestException {
  const SpeedTestNoInternetException()
      : super(SpeedTestErrorKind.noInternet, 'No internet connection');
}

class SpeedTestServerException extends SpeedTestException {
  const SpeedTestServerException(String message, {super.cause})
      : super(SpeedTestErrorKind.server, message);
}

class SpeedTestTlsHttpException extends SpeedTestException {
  const SpeedTestTlsHttpException(String message, {super.cause})
      : super(SpeedTestErrorKind.tlsHttp, message);
}
