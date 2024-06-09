import 'dart:convert';
import 'dart:developer';

const debugMode = !bool.fromEnvironment('dart.vm.product') &&
    !bool.fromEnvironment('dart.vm.profile');

class ChopperDevTools {
  late final List<ClientInfo> clients = [];

  ChopperDevTools() {
    if (!debugMode) return;

    registerExtension('ext.chopper.getClients', (method, parameters) async {
      return ServiceExtensionResponse.result(
        json.encode(
          {'clients': clients.map((c) => c.toJson()).toList()},
        ),
      );
    });
  }

  void addClient(ClientInfo client) {
    if (!debugMode) return;
    clients.add(client);
    postEvent('chopper:addClient', client.toJson());
  }
}

class ClientInfo {
  const ClientInfo({
    required this.baseUrl,
    required this.httpClient,
    this.converter,
    this.errorConverter,
    this.authenticator,
    this.interceptors = const [],
    this.services,
  });

  final String baseUrl;
  final String httpClient;
  final String? converter;
  final String? errorConverter;
  final String? authenticator;
  final List<String> interceptors;
  final List<String>? services;

  Map<String, dynamic> toJson() {
    return {
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
