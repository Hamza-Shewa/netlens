# How to use

## Dio

```dart
/// Create NetLens instance
NetLens netLens = NetLens();

/// Create NetLens Dio Adapter
NetLensDioAdapter netLensDioAdapter = NetLensDioAdapter();

/// Add adapter to NetLens
netLens.addAdapter(netLensDioAdapter);

/// Create Dio instance
Dio dio = Dio();

/// Add interceptor to Dio
dio.interceptors.add(netLensDioAdapter);

/// Optional: resend calls from NetLens with this Dio, so they use its base
/// options, interceptors and HTTP client adapter. Without it, a plain Dio is
/// used.
netLensDioAdapter.replayClient = dio;

```

## Chopper
```dart
/// Create NetLens instance
NetLens netLens = NetLens();

/// Create NetLens Chopper Adapter
NetLensChopperAdapter netLensChopperAdapter = NetLensChopperAdapter();

///Add adapter to NetLens
netLens.addAdapter(netLensChopperAdapter);

/// Create chopper client
ChopperClient chopperClient = ChopperClient(
    interceptors: [netLensChopperAdapter],
);

```


## HTTP
```dart
/// Create NetLens instance
NetLens netLens = NetLens();

/// Create NetLens Http Adapter
NetLensHttpAdapter netLensHttpAdapter = NetLensHttpAdapter();

///Add adapter to NetLens
netLens.addAdapter(netLensHttpAdapter);
```

Use extension to intercept HTTP call:
```dart
http
    .post(Uri.tryParse('https://api.com')!, body: body)
    .interceptWithNetLens(netLensHttpAdapter, body: body);
```

Use adapter to handle HTTP call:
```dart
http
    .put(Uri.tryParse('https://api.com')!, body: body)
    .then((response) {
      netLensHttpAdapter.onResponse(response, body: body);
    });
```

## HTTP Client
```dart
/// Create NetLens instance
NetLens netLens = NetLens();

/// Create NetLens Http Adapter
NetLensHttpClientAdapter netLensHttpClientAdapter = NetLensHttpClientAdapter();

///Add adapter to NetLens
netLens.addAdapter(netLensHttpClientAdapter);

/// Http Client instance
HttpClient httpClient = HttpClient();
```

Use extension to intercept HTTP call:
```dart
httpClient
    .getUrl(Uri.parse('https://api.com'))
    .interceptWithNetLens(netLensHttpClientAdapter);
```

Use adapter to handle HTTP call:
```dart
httpClient
    .getUrl(Uri.parse('https://api.com'))
    .then((request) async {
      netLensHttpClientAdapter.onRequest(request);
      var httpResponse = await request.close();
      var responseBody = await utf8.decoder.bind(httpResponse).join();
      netLensHttpClientAdapter.onResponse(httpResponse, request, body: responseBody);
});
```

## Edit and resend

Calls made by Dio, the http package and `HttpClient` can be sent again from
the call details: the resend button opens an editor with the method, URL,
headers and body of the call. The new call is caught by NetLens like any other.
The editor starts from the real values, also when the inspector hides
sensitive ones.

Calls which sent form data are resent as form data. The editor lists the form
fields, which can be changed, added and removed, and the uploaded files, which
can be removed. The client sets a new multipart boundary, so the original
`Content-Type` header isn't copied.

- **Dio** keeps a way to read every uploaded file again: a file made from a
  path is read from the path again, a file made from bytes keeps its bytes in
  memory while its call is kept. Pass `NetLensDioAdapter(keepFormDataFiles:
  false)` when the app uploads large files from memory; files are then left
  out of resent calls.
- **http** records the fields and files of a `MultipartRequest`. Its file
  streams can be read only once, so the files of a call made by the app are
  left out when it is resent. Files of a resent call are kept, so it can be
  resent again.

The editor warns about files whose content wasn't kept.

`NetLensHttpAdapter` and `NetLensHttpClientAdapter` take an optional
`replayClient`, when calls must be resent with a configured client.

An adapter of another client can support it by implementing
`NetLensCallReplayer`:

```dart
class MyAdapter with NetLensAdapter implements NetLensCallReplayer {
  @override
  bool canReplay(NetLensHttpCall call) => call.client == 'MyClient';

  @override
  Future<void> replay(NetLensReplayRequest request) async {
    // Send request.method, request.url, request.headers and request.body
    // with your client, and report the call to NetLens as usual. When
    // request.isFormData is true, send request.formDataFields and the
    // request.formDataFiles whose read() isn't null as multipart form data.
  }
}
```

## ObjectBox

Setting up ObjectBox with NetLens is simple, however, there are a few crucial steps which need to be followed.

```dart
Future<void> main() async {
  /// This is required so ObjectBox can get the application directory
  /// to store the database in.
  WidgetsFlutterBinding.ensureInitialized();

  /// Initialize [NetLensObjectBoxStore] before running the app.
  final NetLensObjectBoxStore store =
      await NetLensObjectBoxStore.create(persistent: false);

  /// Pass [NetLensObjectBoxStore] to the app
  runApp(MyApp(store: store));
}

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    required this.store,
  });

  final NetLensObjectBoxStore store;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final NetLens _netLens = NetLens(
    configuration: NetLensConfiguration(
      showNotification: true,
      showInspectorOnShake: true,
      /// Pass [NetLensObjectBox] as the storage of [NetLens]
      storage: NetLensObjectBox(
        store: widget.store,
        maxCallsCount: 1000,
      ),
    ),
  );

  // your custom stuff...
}
```
