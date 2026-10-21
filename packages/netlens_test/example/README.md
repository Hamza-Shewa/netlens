# NetLens Test example

Mock the NetLens core and check the calls that your adapter adds to it.

```dart
import 'package:mocktail/mocktail.dart';
import 'package:netlens/core/netlens_core.dart';
import 'package:netlens/model/netlens_http_call.dart';
import 'package:netlens_test/netlens_test.dart';
import 'package:test/test.dart';

void main() {
  late NetLensCore netLensCore;

  setUp(() {
    registerFallbackValue(NetLensHttpCall(0));
    netLensCore = NetLensCoreMock();
    when(() => netLensCore.addCall(any())).thenAnswer((_) {});
  });

  test('adds the call to NetLens', () {
    // Make your adapter catch a GET request with netLensCore injected.

    verify(
      () => netLensCore.addCall(
        any(that: buildCallMatcher(checkTime: true, method: 'GET')),
      ),
    );
  });
}
```

The adapter tests in
[packages](https://github.com/Hamza-Shewa/netlens/tree/master/packages)
use these matchers, for example
[netlens_http](https://github.com/Hamza-Shewa/netlens/tree/master/packages/netlens_http/test).
