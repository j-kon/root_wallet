import 'package:root_wallet/core/logging/logger.dart';
import 'package:root_wallet/core/network/interceptors.dart';

class ApiClient {
  ApiClient({
    required this.baseUri,
    required this.logger,
    List<RequestInterceptor>? requestInterceptors,
    List<ResponseInterceptor>? responseInterceptors,
  }) : _requestInterceptors =
           requestInterceptors ?? const <RequestInterceptor>[],
       _responseInterceptors =
           responseInterceptors ?? const <ResponseInterceptor>[];

  final Uri baseUri;
  final AppLogger logger;
  final List<RequestInterceptor> _requestInterceptors;
  final List<ResponseInterceptor> _responseInterceptors;

  Future<ApiResponse<Map<String, dynamic>>> get(
    String path, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    var request = ApiRequest(path: path, headers: headers);

    for (final interceptor in _requestInterceptors) {
      request = interceptor(request);
    }

    logger.debug('GET ${baseUri.resolve(request.path)}');

    var response = ApiResponse<Map<String, dynamic>>(
      statusCode: 200,
      data: <String, dynamic>{'ok': true},
    );

    for (final interceptor in _responseInterceptors) {
      response = interceptor(response) as ApiResponse<Map<String, dynamic>>;
    }

    return response;
  }
}
