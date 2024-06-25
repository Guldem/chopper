import 'package:chopper/src/request.dart';

class RequestInfo {
  final String method;
  final String url;
  final Map<String, String> headers;
  final String body;
  final String requestSize;

  RequestInfo({
    required this.method,
    required this.url,
    required this.headers,
    required this.body,
    required this.requestSize,
  });

  factory RequestInfo.fromRequest(Request request) {
    return RequestInfo(
      method: request.method,
      url: request.url.toString(),
      headers: request.headers,
      body: request.body,
      requestSize: request.contentLength.toString(),
    );
  }

  factory RequestInfo.fromJson(Map<String, dynamic> json) {
    return RequestInfo(
      method: json['method'],
      url: json['url'],
      headers: Map<String, String>.from(json['headers']),
      body: json['body'],
      requestSize: json['requestSize'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'method': method,
      'url': url,
      'headers': headers,
      'body': body,
      'requestSize': requestSize,
    };
  }
}
