/// Definition of data holder of form data file.
class NetLensFormDataFile {
  const NetLensFormDataFile(
    this.fileName,
    this.contentType,
    this.length, {
    this.name,
    this.read,
  });

  final String? fileName;
  final String contentType;
  final int length;

  /// Name of the form field which holds the file. Null when the client
  /// didn't tell it.
  final String? name;

  /// Reads the content of the file again, so the request can be sent again.
  /// Null when NetLens didn't keep the content.
  final Stream<List<int>> Function()? read;

  /// Returns true when the content of the file can be sent again.
  bool get canRead => read != null;
}
