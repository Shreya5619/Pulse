class BackendConfig {
  BackendConfig._();

  /// Railway production backend host.
  /// Kept as host only (no scheme) so shared URL builders can derive HTTPS/WSS.
  static const String host = 'pulse-production-6637.up.railway.app';
}
