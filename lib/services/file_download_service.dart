// lib/services/file_download_service.dart

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class FileDownloadService {
  final Dio _dio = Dio();

  Future<String?> downloadFile(String url) async {
    try {
      // Obtenir le répertoire de téléchargement
      final directory = await getApplicationDocumentsDirectory();
      final fileName = url.split('/').last;
      final savePath = '${directory.path}/$fileName';
      
      // Télécharger le fichier
      await _dio.download(url, savePath);
      
      return savePath;
    } catch (e) {
      print('Erreur téléchargement: $e');
      return null;
    }
  }

  Future<String> getLocalFilePath(String url) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = url.split('/').last;
    return '${directory.path}/$fileName';
  }

  Future<bool> fileExists(String url) async {
    final filePath = await getLocalFilePath(url);
    final file = File(filePath);
    return await file.exists();
  }

  Future<void> deleteFile(String url) async {
    final filePath = await getLocalFilePath(url);
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}