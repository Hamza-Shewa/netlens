# 1.2.0

* Records the fields and files of `MultipartRequest` calls and resends them as form data. Files of a call made by the app can't be read again, so they are left out; files of a resent call are kept.
* Depends on http_parser.

# 1.1.0

* Adds `NetLensHttpMockClient`, which answers requests of the http package and Chopper with NetLens mocks.
* Needs Dart 3.11 and Flutter 3.41 or newer, and uses the latest versions of its dependencies.

# 1.0.0

* First release of NetLens, a fork of [Alice](https://github.com/jhomlala/alice) 1.0.0 under a new name.
* Resends calls from the inspector, with an optional `replayClient`.
