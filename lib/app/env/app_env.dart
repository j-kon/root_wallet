abstract class AppEnv {
  const AppEnv();

  String get flavor;
  bool get isProduction;
  bool get enableLogging;
  Uri get apiBaseUri;
}
