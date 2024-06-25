import 'package:chopper/src/base.dart';

class ClientInfo {
  const ClientInfo({
    required this.clientId,
    required this.baseUrl,
    required this.httpClient,
    this.converter,
    this.errorConverter,
    this.authenticator,
    this.interceptors = const [],
    this.services,
  });

  final String clientId;
  final String baseUrl;
  final String httpClient;
  final String? converter;
  final String? errorConverter;
  final String? authenticator;
  final List<String> interceptors;
  final List<String>? services;

  factory ClientInfo.fromJson(Map<String, dynamic> json) {
    return ClientInfo(
      clientId: json['clientId'],
      baseUrl: json['baseUrl'],
      httpClient: json['httpClient'],
      converter: json['converter'],
      errorConverter: json['errorConverter'],
      authenticator: json ['authenticator'],
      interceptors: List<String>.from(json['interceptors']),
      services: json['services'] != null ? List<String>.from(json['services']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'clientId': clientId,
      'baseUrl': baseUrl,
      'httpClient': httpClient,
      'converter': converter,
      'errorConverter': errorConverter,
      'authenticator': authenticator,
      'interceptors': interceptors,
      'services': services,
    };
  }
}
