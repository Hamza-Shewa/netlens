# NetLens ObjectBox example

```dart
import 'package:flutter/material.dart';
import 'package:netlens/model/netlens_configuration.dart';
import 'package:netlens/netlens.dart';
import 'package:netlens_objectbox/netlens_objectbox.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await NetLensObjectBoxStore.create();

  final netLens = NetLens(
    configuration: NetLensConfiguration(
      storage: NetLensObjectBox(store: store, maxCallsCount: 1000),
    ),
  );

  runApp(MaterialApp(navigatorKey: netLens.getNavigatorKey()));
}
```

A complete app is in
[examples/netlens_objectbox](https://github.com/Hamza-Shewa/netlens/tree/master/examples/netlens_objectbox).
