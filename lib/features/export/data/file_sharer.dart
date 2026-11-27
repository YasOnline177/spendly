import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Hands a text file to the system share sheet.
abstract class FileSharer {
  Future<void> shareTextFile({
    required String fileName,
    required String content,
    required String mimeType,
    String? subject,
  });
}

class SharePlusFileSharer implements FileSharer {
  @override
  Future<void> shareTextFile({
    required String fileName,
    required String content,
    required String mimeType,
    String? subject,
  }) async {
    // A temporary file, overwritten by the next export.
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(content);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType)],
        subject: subject,
      ),
    );
  }
}