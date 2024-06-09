import 'package:chopper_devtools_extension/client_list.dart';
import 'package:flutter/material.dart';
import 'package:devtools_extensions/devtools_extensions.dart';

void main() {
  runApp(const ChopperDevToolsExtensionApp());
}

class ChopperDevToolsExtensionApp extends StatelessWidget {
  const ChopperDevToolsExtensionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DevToolsExtension(child: ClientList());
  }
}
