# 1.2.0

* Resends calls which sent form data, with their fields and uploaded files. The resend editor lists form fields, which can be changed, added and removed, and files, and warns about files whose content wasn't kept. `NetLensReplayRequest` has `formDataFields` and `formDataFiles`, and `NetLensFormDataFile` has the field `name` and a `read` function.
* Adds Save all requests to the settings, which keeps every finished call as a mock whatever the mode is. Set it in code with `NetLensMocks(saveAllCalls: true)`.
* Exports mocks as a Postman collection (v2.1), and imports Postman collections.
* Adds Import to the Mocks page: picks one or more NetLens mocks, HAR or Postman files, or pastes one from the clipboard, and merges them with the saved mocks. When collections send a field of an endpoint as different types, or answer the same request differently, the new merge page lays out the versions and the user keeps one. See `NetLensMocks.planMerge` and `NetLensMockMerger`.
* Mocks keep request headers, so exports can include them. Sensitive request headers are masked in exports.
* Depends on file_picker.
* Deprecates the `omitsFormData` parameter of `NetLensReplayRequest`. It's ignored, because `omitsFormData` is now computed from `formDataFiles`.

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
