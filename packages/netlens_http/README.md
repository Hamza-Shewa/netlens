# NetLens for http

[![pub package](https://img.shields.io/pub/v/netlens_http.svg)](https://pub.dev/packages/netlens_http)

Connects [NetLens](https://pub.dev/packages/netlens), the in-app HTTP inspector
for Flutter, to http.

## Install

```yaml
dependencies:
  netlens: ^1.2.0
  netlens_http: ^1.2.0
```

## Use

```dart
import 'package:http/http.dart' as http;
import 'package:netlens/netlens.dart';
import 'package:netlens_http/netlens_http.dart';

final netLens = NetLens();
final adapter = NetLensHttpAdapter();
netLens.addAdapter(adapter);

http
    .get(Uri.parse('https://api.example.com/users'))
    .interceptWithNetLens(adapter);
```

## Mocks

`NetLensHttpMockClient` answers requests with mocks recorded by NetLens, so the
app can run offline:

```dart
final client = NetLensHttpMockClient(resolver: netLens.mocks);
netLens.mocks.mode = NetLensMockMode.replay;
await client.get(url).interceptWithNetLens(adapter);
```

See [Mocks](https://github.com/Hamza-Shewa/netlens/blob/master/docs/mocks.md).

## Documentation

You can find the documentation [here](https://github.com/Hamza-Shewa/netlens/tree/master/docs).

## Credits

NetLens is a fork of [Alice](https://github.com/jhomlala/alice) by Jakub
Homlala and its contributors, licensed under the Apache License 2.0.
