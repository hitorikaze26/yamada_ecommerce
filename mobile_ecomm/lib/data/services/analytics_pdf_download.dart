import 'dart:io';
import 'dart:typed_data';

import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

/// Saves PDF bytes and opens with the system viewer.
Future<String> persistAndOpenAnalyticsPdf(Uint8List bytes, int days) async {
  if (bytes.length < 4 ||
      String.fromCharCodes(bytes.sublist(0, 4)) != '%PDF') {
    throw Exception('Invalid PDF received from server');
  }
  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/sales-report-${days}d.pdf';
  await File(path).writeAsBytes(bytes, flush: true);
  await OpenFile.open(path);
  return path;
}
