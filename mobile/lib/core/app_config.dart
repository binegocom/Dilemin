class AppConfig {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static Uri get baseUri {
    if (apiBaseUrl.isEmpty) {
      throw const FormatException('API_BASE_URL is required at build time.');
    }
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || uri.host.isEmpty || uri.scheme != 'https') {
      throw const FormatException('API_BASE_URL must be an HTTPS URL.');
    }
    return uri;
  }
}
