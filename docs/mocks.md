## Mocks: record and replay

NetLens can save the calls of your app as mock endpoints and answer later
requests with them, so the app runs without the backend: offline, on a plane,
against a broken staging server or in tests.

1. **Record.** Switch mocks to Record and use the app. Every finished call is
   saved as a mock. You can also save one call with the mock button in its
   details, or all caught calls with Save caught calls on the Mocks page.
2. **Replay.** Switch mocks to Replay. Requests which match a mock get its
   recorded response, and the call shows a Mock badge in the inspector.
   Requests which match no mock go to the network, or get 404 when the fallback
   is `NetLensMockFallback.notFound`.

The Mocks page is in the menu of the calls list. It switches the mode, lists
the mocks, turns them on and off, deletes them, imports collections and exports
them as a NetLens mocks file or as a Postman collection.

### Save all requests

Turn on **Save all requests** in the NetLens settings to keep every finished
call as a mock, whatever the mode is. Unlike Record, it also works in Replay:
requests which no mock answered are saved, while calls answered by a mock
aren't saved again. Turn it on in code with
`NetLensMocks(saveAllCalls: true)`, or at any time with
`netLens.mocks.saveAllCalls = true`. The switch isn't remembered after a
restart; see below to keep the saved mocks.

### Share collections

Export from the Mocks page as:

- **NetLens mocks (JSON)**, which NetLens, `NetLensMocks.import` and the mock
  server read.
- **Postman collection** (v2.1), which Postman, Insomnia, Bruno and other API
  clients import. Each mock is a request, with its response saved as an
  example, grouped in a folder per host. Binary response bodies are left out.

Sensitive request headers, like `Authorization`, are masked in both exports
as configured by `NetLensConfiguration.redaction`. Bodies and URLs are kept, so
the mocks still match.

**Import** on the Mocks page reads one or more files with the system file
picker, or a collection pasted from the clipboard. NetLens mocks files, HAR
files and Postman collections are read, so a QA team can record a feature
each, share their collections and merge them on one device:

- Equal mocks are kept once, and requests which send other values are all
  kept.
- When requests of one endpoint (method and URL without query) send a JSON
  field as different types, for example `id` as a number in one collection
  and as a string in another, the merge page lays out each version with the
  types, an example body and the collections which have it. The user keeps one
  version. Fields which are missing or null never conflict.
- When the same request has different responses, the merge page shows each
  status and body, and the user keeps one.

Mocks already on the device take part in the merge as "This device" and win
the default choices. In code:

```dart
final plan = netLens.mocks.planMerge([
  NetLensMockSource(name: 'login.json', mocks: netLens.mocks.decode(login)),
  NetLensMockSource(name: 'cart.json', mocks: netLens.mocks.decode(cart)),
]);
for (final conflict in plan.inputConflicts) {
  print('${conflict.method} ${conflict.url}: '
      '${conflict.options.map((option) => option.inputTypes)}');
}
await netLens.mocks.replaceAll(plan.resolve({plan.inputConflicts.first: 1}));
```

### Set up

Mocks are answered by the HTTP client, below NetLens, so mocked calls are
caught by the inspector like real ones. Add the mock adapter of your client
next to the NetLens adapter:

```dart
final netLens = NetLens(
  configuration: NetLensConfiguration(
    mocks: NetLensMocks(mode: NetLensMockMode.replay),
  ),
);
```

**Dio**

```dart
final dio = Dio()..interceptors.add(dioAdapter);
NetLensDioMockAdapter.install(dio, netLens.mocks);
```

**http**

```dart
final client = NetLensHttpMockClient(resolver: netLens.mocks);
await client.get(url).interceptWithNetLens(httpAdapter);
```

**Chopper** sends its requests with a client of the http package, so it uses
`NetLensHttpMockClient` from `netlens_http`:

```dart
final chopper = ChopperClient(
  client: NetLensHttpMockClient(resolver: netLens.mocks),
  interceptors: [chopperAdapter],
);
```

**HttpClient from dart:io, or any other client**: start the local mock server
and point the base URL of the app at it. The host of the request is ignored, so
mocks recorded against any backend match.

```dart
final server = NetLensMockServer(resolver: netLens.mocks);
final Uri baseUrl = await server.start(port: 8080);
```

### Keep mocks after a restart

Mocks are kept in memory by default. `NetLensFileMockRepository` saves them to
a JSON file instead, so mocks recorded once are replayed after the app is
restarted:

```dart
final directory = await getApplicationDocumentsDirectory();
final repository = NetLensFileMockRepository(
  File('${directory.path}/netlens_mocks.json'),
);
await repository.load();

final mocks = NetLensMocks(repository: repository);
```

### Load mocks

`NetLensMocks.import` reads a NetLens mocks file, as exported from the Mocks
page, a HAR file, for example one exported by NetLens, Chrome DevTools,
Proxyman or Charles, or a Postman collection with saved examples. Mocks can be shipped with the app as an asset:

```dart
await netLens.mocks.import(
  await rootBundle.loadString('assets/mocks.json'),
);
netLens.mocks.mode = NetLensMockMode.replay;
```

A mocks file can be written by hand. Only `method`, `url` and
`response.status` are required, `*` matches any path segment and the body can
be JSON:

```json
{
  "netlensMocks": 1,
  "mocks": [
    {
      "method": "GET",
      "url": "https://api.example.com/users/*",
      "response": {
        "status": 200,
        "headers": {"content-type": "application/json"},
        "body": {"id": 1, "name": "Ada"}
      }
    }
  ]
}
```

### Serve mocks from your computer

The `netlens_mock_server` command serves mock and HAR files on your computer,
for example for an emulator or for tests of another app:

```bash
dart run netlens:netlens_mock_server --host 0.0.0.0 --port 8080 mocks.json
```

Run it with `--help` for all options.

### Matching

`NetLensDefaultMockMatcher` compares the method, host, path and query
parameters of the request, in any order. Its options:

| Option | Default | Description |
| --- | --- | --- |
| `matchHost` | `true` | Compare scheme, host and port. |
| `matchQuery` | `true` | Compare query parameters. |
| `matchBody` | `false` | Compare request bodies. JSON is compared by value. |
| `ignoredQueryParameters` | `{}` | Query parameters which are never compared, for example cache busters. |

Implement `NetLensMockMatcher` for other rules, `NetLensMockRepository` for
another storage and `NetLensMockResolver` to answer requests your own way.

`NetLensMocks(simulateLatency: true)` waits as long as the recorded call took
before it answers.

### Security

Mocks keep real request URLs, request headers, request bodies and responses,
which may contain tokens or personal data. Exports mask sensitive request
headers, but not bodies, URLs or responses. Keep mock files and collections out
of public repositories unless you removed such values.
