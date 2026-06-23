import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class FileService {
  Future<File> downloadFile(String url, String fileName) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Не удалось скачать файл (${response.statusCode})');
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  Future<String> saveToDownloads(String sourcePath, String fileName) async {
    final downloadDir = await _getDownloadsDirectory();
    final destPath = '${downloadDir.path}/$fileName';
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  Future<Directory> _getDownloadsDirectory() async {
    if (Platform.isWindows) {
      return Directory('C:/Users/${Platform.environment['USERNAME']}/Downloads');
    }
    return getApplicationDocumentsDirectory();
  }
}
