# NetLens for HttpClient from dart:io

[![pub package](https://img.shields.io/pub/v/netlens_http_client.svg)](https://pub.dev/packages/netlens_http_client)

Connects [NetLens](https://pub.dev/packages/netlens), the in-app HTTP inspector
for Flutter, to HttpClient from dart:io.

## Install

```yaml
dependencies:
  netlens: ^1.2.0
  netlens_http_client: ^1.0.0
```

## Use

```dart
import 'dart:io';
import 'package:netlens/netlens.dart';
import 'package:netlens_http_client/netlens_http_client.dart';

final netLens = NetLens();
final adapter = NetLensHttpClientAdapter();
netLens.addAdapter(adapter);

HttpClient()
    .getUrl(Uri.parse('https://api.example.com/users'))
    .interceptWithNetLens(adapter);
```

## Mocks

To replay mocks recorded by NetLens, start `NetLensMockServer` and point your
requests at its URL:

```dart
final server = NetLensMockServer(resolver: netLens.mocks);
final Uri baseUrl = await server.start();
```

See [Mocks](https://github.com/Hamza-Shewa/netlens/blob/master/docs/mocks.md).

## Documentation

You can find the documentation [here](https://github.com/Hamza-Shewa/netlens/tree/master/docs).

## Credits

NetLens is a fork of [Alice](https://github.com/jhomlala/alice) by Jakub
Homlala and its contributors, licensed under the Apache License 2.0.
