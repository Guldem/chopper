import 'dart:convert';
import 'dart:developer';

import 'package:chopper/src/devtools/models/call_info.dart';
import 'package:chopper/src/devtools/models/client_info.dart';

const debugMode = !bool.fromEnvironment('dart.vm.product') &&
    !bool.fromEnvironment('dart.vm.profile');

class ChopperDevTools {
  static ChopperDevTools? instance = debugMode ? null : ChopperDevTools._();

  late final Map<String, ClientInfo> clients = {};
  late final List<CallInfo> calls = [];

  ChopperDevTools._() {
    registerExtension('ext.chopper.getClients', (method, parameters) async {
      return ServiceExtensionResponse.result(
        json.encode(
          {'clients': clients.values.map((c) => c.toJson()).toList()},
        ),
      );
    });
  }

  void addClient(String id, ClientInfo client) {
    clients.putIfAbsent(id, () => client);
    postEvent('chopper:addClient', client.toJson());
  }

  void addCall(CallInfo call) {
    calls.add(call);
    postEvent('chopper:addCall', call.toJson());
  }
}
