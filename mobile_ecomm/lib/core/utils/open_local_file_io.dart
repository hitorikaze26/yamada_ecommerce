import 'package:open_file/open_file.dart';

/// Opens a local file with the platform default app (e.g. PDF viewer).
Future<OpenLocalFileOutcome> openLocalFile(String path) async {
  final result = await OpenFile.open(path);
  return OpenLocalFileOutcome(
    ok: result.type == ResultType.done,
    message: result.message,
  );
}

class OpenLocalFileOutcome {
  final bool ok;
  final String message;

  const OpenLocalFileOutcome({required this.ok, required this.message});
}
