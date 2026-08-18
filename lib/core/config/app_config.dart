class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.backendBaseUrl,
    required this.llmBaseUrl,
    required this.remoteBackendEnabled,
  });

  final String environment;
  final String apiBaseUrl;
  final String backendBaseUrl;
  final String llmBaseUrl;
  final bool remoteBackendEnabled;

  static AppConfig fromEnvironment() {
    const env = String.fromEnvironment('APP_ENV', defaultValue: 'development');
    const backendBase = String.fromEnvironment(
      'JOURNAL_API_BASE',
      defaultValue: 'http://127.0.0.1:8000',
    );
    const llmBase = String.fromEnvironment('LLM_BASE_URL', defaultValue: '');
    const remoteBackendEnabled = bool.fromEnvironment(
      'USE_REMOTE_BACKEND',
      defaultValue: true,
    );
    switch (env) {
      case 'production':
        return const AppConfig(
          environment: 'production',
          apiBaseUrl: 'https://api.mindwellclinic.com',
          backendBaseUrl: backendBase,
          llmBaseUrl: llmBase,
          remoteBackendEnabled: remoteBackendEnabled,
        );
      case 'staging':
        return const AppConfig(
          environment: 'staging',
          apiBaseUrl: 'https://staging-api.mindwellclinic.com',
          backendBaseUrl: backendBase,
          llmBaseUrl: llmBase,
          remoteBackendEnabled: remoteBackendEnabled,
        );
      default:
        return const AppConfig(
          environment: 'development',
          apiBaseUrl: 'https://dev-api.mindwellclinic.local',
          backendBaseUrl: backendBase,
          llmBaseUrl: llmBase,
          remoteBackendEnabled: remoteBackendEnabled,
        );
    }
  }
}
