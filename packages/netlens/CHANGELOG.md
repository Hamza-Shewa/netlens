# 1.1.0

* Adds mocks: records calls as mock endpoints and replays them, so the app runs offline. Switch between off, record and replay on the new Mocks page, save one call from its details and see a Mock badge on mocked calls. Configure it with `NetLensConfiguration.mocks`.
* Adds `NetLensMockServer`, a local HTTP server which answers any client with mocks, and the `netlens_mock_server` command, which serves mock and HAR files from a computer.
* Imports mocks from NetLens mocks JSON files and HAR files, and keeps them after a restart with `NetLensFileMockRepository`.
* Needs Dart 3.11 and Flutter 3.41 or newer, and uses the latest versions of its dependencies.
* Works with flutter_local_notifications 22, sensors_plus 7, open_filex 5 and equatable 3.

# 1.0.0

* First release of NetLens, a fork of [Alice](https://github.com/jhomlala/alice) 1.0.0 under a new name.
* Hides sensitive headers, cookies, query parameters and body fields in the inspector and masks them in shared and saved calls. Configure it with `NetLensConfiguration.redaction`.
* Adds quick filters by status group, method and host, and searches headers, bodies, errors and GraphQL operation names.
* Adds edit and resend for adapters that implement `NetLensCallReplayer`.
* Adds a collapsible JSON viewer with search, copy value and copy path.
* Adds HAR 1.2 export for Chrome DevTools, Proxyman and Charles.
* Shows GraphQL operation types, names, batches and errors.
* Adds a timeline of calls and the slowest endpoints in statistics.
