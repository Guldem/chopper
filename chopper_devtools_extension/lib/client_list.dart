import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

class ClientList extends StatefulWidget {
  const ClientList({super.key});

  @override
  State<ClientList> createState() => _ClientListState();
}

class _ClientListState extends State<ClientList> {
  final clients = ValueNotifier<List<Map<String, dynamic>>>([]);

  @override
  void initState() {
    super.initState();
    refreshClients();
  }

  void refreshClients() async {
    final response = await serviceManager
        .callServiceExtensionOnMainIsolate('ext.chopper.getClients');

    final clientsResponse = response.json?['clients'] as List<dynamic>? ?? [];

    clients.value = clientsResponse.cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DevToolsButton(
            onPressed: refreshClients,
            label: 'Refresh clients',
            icon: Icons.refresh,
          ),
          ValueListenableBuilder(
              valueListenable: clients,
              builder: (context, clients, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: clients
                      .map((c) => FormattedJson(
                            json: c,
                          ))
                      .toList(),
                );
              }),
        ],
      ),
    );
  }
}
