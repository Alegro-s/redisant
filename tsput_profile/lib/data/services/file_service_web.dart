class FileService {
  Future<Never> downloadFile(String url, String fileName) async {
    throw UnsupportedError('Скачивание файла доступно в мобильной версии');
  }

  Future<String> saveToDownloads(String sourcePath, String fileName) async {
    return sourcePath;
  }
}
