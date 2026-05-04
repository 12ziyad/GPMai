class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'GPMAI_WORKER_BASE_URL',
    defaultValue: 'https://gpmai-api.gpmai.workers.dev',
  );
}
