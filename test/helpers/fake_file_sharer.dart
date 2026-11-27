import 'package:spendly_android/features/export/data/file_sharer.dart';

class FakeFileSharer implements FileSharer {
  bool fail = false;
  final files = <({String fileName, String content, String mimeType})>[];

  @override
  Future<void> shareTextFile({
    required String fileName,
    required String content,
    required String mimeType,
    String? subject,
  }) async {
    if (fail) throw StateError('sharing failed');
    files.add((fileName: fileName, content: content, mimeType: mimeType));
  }
}