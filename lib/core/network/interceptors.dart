class ApiRequest {
  const ApiRequest({
    required this.path,
    this.headers = const <String, String>{},
    this.body,
  });

  final String path;
  final Map<String, String> headers;
  final Object? body;

  ApiRequest copyWith({
    String? path,
    Map<String, String>? headers,
    Object? body,
  }) {
    return ApiRequest(
      path: path ?? this.path,
      headers: headers ?? this.headers,
      body: body ?? this.body,
    );
  }
}

class ApiResponse<T> {
  const ApiResponse({required this.statusCode, required this.data});

  final int statusCode;
  final T data;
}

typedef RequestInterceptor = ApiRequest Function(ApiRequest request);
typedef ResponseInterceptor =
    ApiResponse<dynamic> Function(ApiResponse<dynamic> response);
