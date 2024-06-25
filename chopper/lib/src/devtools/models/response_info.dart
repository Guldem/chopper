import 'package:chopper/src/response.dart';

class ResponseInfo {
  final int statusCode;
  final Map<String, String> headers;
  final String body;
  final String? error;

  ResponseInfo({
    required this.statusCode,
    required this.headers,
    required this.body,
    required this.error,
  });

  factory ResponseInfo.fromJson(Response response) {
    return ResponseInfo(
      statusCode: response.statusCode,
      headers: response.headers,
      body: response.bodyString,
      error: response.error?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'statusCode': statusCode,
      'headers': headers,
      'body': body,
      'error': error,
    };
  }
}