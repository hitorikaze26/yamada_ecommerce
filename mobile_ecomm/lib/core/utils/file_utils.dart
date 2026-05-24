import 'package:path/path.dart' as p;

/// Basename for multipart uploads (works on Windows and POSIX).
String multipartFilename(String filePath) => p.basename(filePath);
