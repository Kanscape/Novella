abstract interface class TelemetrySink {
  void track(String name, {Map<String, Object?> properties = const {}});

  void trackScreenView(
    String screenName, {
    String? screenClass,
    Map<String, Object?> properties = const {},
  });

  void addBreadcrumb(String name, {Map<String, Object?> properties = const {}});

  void captureError(
    Object error, {
    StackTrace? stackTrace,
    Map<String, Object?> properties = const {},
  });

  Future<void> flush();
}

class NoopTelemetrySink implements TelemetrySink {
  const NoopTelemetrySink();

  @override
  void track(String name, {Map<String, Object?> properties = const {}}) {}

  @override
  void trackScreenView(
    String screenName, {
    String? screenClass,
    Map<String, Object?> properties = const {},
  }) {}

  @override
  void addBreadcrumb(
    String name, {
    Map<String, Object?> properties = const {},
  }) {}

  @override
  void captureError(
    Object error, {
    StackTrace? stackTrace,
    Map<String, Object?> properties = const {},
  }) {}

  @override
  Future<void> flush() async {}
}
