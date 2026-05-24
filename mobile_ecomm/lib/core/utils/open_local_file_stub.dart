/// Web: opening arbitrary paths is not supported; downloads use the browser.
Future<OpenLocalFileOutcome> openLocalFile(String path) async {
  return const OpenLocalFileOutcome(ok: true, message: '');
}

class OpenLocalFileOutcome {
  final bool ok;
  final String message;

  const OpenLocalFileOutcome({required this.ok, required this.message});
}
