class AppConstants {
  static const String appName = 'PolyGlotDoc AI';
  static const String appTagline = 'Tradução e Reconstrução Editorial de Documentos com IA';
  
  // Backend API URL (configurable for dev/docker/prod)
  static String baseHttpUrl = 'http://localhost:8000';
  static String baseWsUrl = 'ws://localhost:8000';

  static String get uploadUrl => '$baseHttpUrl/api/v1/documents/upload';
  static String get tasksUrl => '$baseHttpUrl/api/v1/tasks';
  static String taskStatusUrl(String id) => '$baseHttpUrl/api/v1/tasks/$id/status';
  static String taskDownloadUrl(String id) => '$baseHttpUrl/api/v1/tasks/$id/download';
  static String taskPreviewUrl(String id) => '$baseHttpUrl/api/v1/tasks/$id/preview';
  static String taskRetryUrl(String id) => '$baseHttpUrl/api/v1/tasks/$id/retry';
  static String taskPageImageUrl(String id, int pageNum, String type) => 
      '$baseHttpUrl/api/v1/documents/tasks/$id/pages/$pageNum/image?type=$type';
  static String wsProgressUrl(String clientId) => '$baseWsUrl/ws/progress/$clientId';
  static String get settingsUrl => '$baseHttpUrl/api/v1/settings';
  static String get testConnectionUrl => '$baseHttpUrl/api/v1/settings/test-connection';
}
