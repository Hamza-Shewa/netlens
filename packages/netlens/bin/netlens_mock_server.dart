import 'dart:io';

import 'package:netlens/netlens_mocks.dart';

const String _usage = '''
Serves mocks recorded by NetLens on a local HTTP server.

Usage: dart run netlens:netlens_mock_server [options] <file>...

Each file is a NetLens mocks JSON file or a HAR file.

Options:
  --port <port>     Port to listen on. Default: 8080.
  --host <address>  Address to listen on. Default: 127.0.0.1. Use 0.0.0.0 to
                    reach the server from a device or an emulator.
  --match-body      Compare request bodies too.
  --latency         Wait as long as the recorded calls took.
  -h, --help        Show this help.
''';

Future<void> main(List<String> arguments) async {
  final List<String> files = [];
  int port = 8080;
  String host = InternetAddress.loopbackIPv4.address;
  bool matchBody = false;
  bool latency = false;
  for (int index = 0; index < arguments.length; index++) {
    final String argument = arguments[index];
    switch (argument) {
      case '-h' || '--help':
        stdout.write(_usage);
        return;
      case '--port' when index + 1 < arguments.length:
        port = int.parse(arguments[++index]);
      case '--host' when index + 1 < arguments.length:
        host = arguments[++index];
      case '--match-body':
        matchBody = true;
      case '--latency':
        latency = true;
      default:
        if (argument.startsWith('-')) {
          stderr.write('Unknown option $argument\n\n$_usage');
          exitCode = 64;
          return;
        }
        files.add(argument);
    }
  }
  if (files.isEmpty) {
    stderr.write(_usage);
    exitCode = 64;
    return;
  }

  final NetLensMocks mocks = NetLensMocks(
    mode: NetLensMockMode.replay,
    matcher: NetLensDefaultMockMatcher(matchBody: matchBody),
    fallback: NetLensMockFallback.notFound,
    simulateLatency: latency,
  );
  for (final String path in files) {
    final List<NetLensMock> imported = await mocks.import(
      await File(path).readAsString(),
    );
    stdout.writeln('Loaded ${imported.length} mocks from $path');
  }

  final Uri uri = await NetLensMockServer(
    resolver: mocks,
  ).start(address: host, port: port);
  stdout.writeln('Serving ${mocks.mocks.length} mocks on $uri');
  for (final NetLensMock mock in mocks.mocks) {
    stdout.writeln(
      '  ${mock.method.padRight(7)} ${mock.url.path} -> '
      '${mock.response.status}',
    );
  }
}
