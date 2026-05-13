class ApiConstants {
  static const String baseUrl = 'http://10.0.2.2:9090';
  static const String wsUrl = 'ws://10.0.2.2:9090/ws';
  static const String uploadUrl = '$baseUrl/api/upload';
  static const String staticUrl = '$baseUrl/uploads';

  // Windows uses localhost directly
  static const String baseUrlWindows = 'http://localhost:9090';
  static const String wsUrlWindows = 'ws://localhost:9090/ws';
}
