class ApiResponse {
  final String message;
  final bool success;
  final dynamic data;

  ApiResponse({
    required this.message,
    required this.success,
    required this.data,
  });
}
