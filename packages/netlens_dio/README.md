# NetLens for Dio

[![pub package](https://img.shields.io/pub/v/netlens_dio.svg)](https://pub.dev/packages/netlens_dio)

Connects [NetLens](https://pub.dev/packages/netlens), the in-app HTTP inspector
for Flutter, to Dio.

## Install

```yaml
dependencies:
  netlens: ^1.0.0
  netlens_dio: ^1.0.0
```

## Use

```dart
import 'package:dio/dio.dart';
import 'package:netlens/netlens.dart';
import 'package:netlens_dio/netlens_dio.dart';

final netLens = NetLens();
final adapter = NetLensDioAdapter();
netLens.addAdapter(adapter);

final dio = Dio()..interceptors.add(adapter);

// Optional: resend calls with this Dio, so they keep its options and interceptors.
adapter.replayClient = dio;
```

## Mocks

`NetLensDioMockAdapter` answers requests with mocks recorded by NetLens, so the
app can run offline:

```dart
NetLensDioMockAdapter.install(dio, netLens.mocks);
netLens.mocks.mode = NetLensMockMode.replay;
```

See [Mocks](https://github.com/Hamza-Shewa/alice/blob/master/docs/mocks.md).

## Documentation

You can find the documentation [here](https://github.com/Hamza-Shewa/alice/tree/master/docs).

## Credits

NetLens is a fork of [Alice](https://github.com/jhomlala/alice) by Jakub
Homlala and its contributors, licensed under the Apache License 2.0.
