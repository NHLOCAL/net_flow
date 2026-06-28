import 'dart:io';

import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';

class DownloadService {
  const DownloadService();

  Future<String?> enqueue({
    required String url,
    String? fileName,
    Map<String, String> headers = const <String, String>{},
  }) async {
    final directory = await _resolveDownloadDirectory();
    return FlutterDownloader.enqueue(
      url: url,
      headers: headers,
      savedDir: directory.path,
      fileName: fileName,
      showNotification: true,
      openFileFromNotification: true,
      saveInPublicStorage: Platform.isAndroid,
    );
  }

  Future<Directory> _resolveDownloadDirectory() async {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) {
      return downloads;
    }

    final external = await getExternalStorageDirectory();
    if (external != null) {
      return external;
    }

    return getApplicationDocumentsDirectory();
  }
}
