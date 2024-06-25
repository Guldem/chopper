import 'package:chopper/src/devtools/models/request_info.dart';
import 'package:chopper/src/devtools/models/response_info.dart';

class CallInfo {
  final String callId;
  final RequestInfo request;
  final ResponseInfo responseInfo;
  final String callDuration;

  CallInfo({
    required this.callId,
    required this.request,
    required this.responseInfo,
    required this.callDuration,
  });

  factory CallInfo.fromJson(Map<String, dynamic> json) {
    return CallInfo(
      callId: json['callId'],
      request: RequestInfo.fromJson(json['request']),
      responseInfo: ResponseInfo.fromJson(json['responseInfo']),
      callDuration: json['callDuration'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'callId': callId,
      'request': request.toJson(),
      'responseInfo': responseInfo.toJson(),
      'callDuration': callDuration,
    };
  }
}
