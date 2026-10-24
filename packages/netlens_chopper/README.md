# NetLens for Chopper

[![pub package](https://img.shields.io/pub/v/netlens_chopper.svg)](https://pub.dev/packages/netlens_chopper)

Connects [NetLens](https://pub.dev/packages/netlens), the in-app HTTP inspector
for Flutter, to Chopper.

## Install

```yaml
dependencies:
  netlens: ^1.2.0
  netlens_chopper: ^1.2.0
```

## Use

```dart
import 'package:chopper/chopper.dart';
import 'package:netlens/netlens.dart';
import 'package:netlens_chopper/netlens_chopper.dart';

final netLens = NetLens();
final adapter = NetLensChopperAdapter();
netLens.addAdapter(adapter);

final chopper = ChopperClient(interceptors: [adapter]);
```

## Mocks

To replay mocks recorded by NetLens, pass `NetLensHttpMockClient` from
[netlens_http](https://pub.dev/packages/netlens_http) as the client of Chopper:

```dart
final chopper = ChopperClient(
  client: NetLensHttpMockClient(resolver: netLens.mocks),
  interceptors: [adapter],
);
```

See [Mocks](https://github.com/Hamza-Shewa/netlens/blob/master/docs/mocks.md).

## Documentation

You can find the documentation [here](https://github.com/Hamza-Shewa/netlens/tree/master/docs).

## Credits

NetLens is a fork of [Alice](https://github.com/jhomlala/alice) by Jakub
Homlala and its contributors, licensed under the Apache License 2.0.
