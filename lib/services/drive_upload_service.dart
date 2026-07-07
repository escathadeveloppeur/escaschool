// lib/utils/drive_upload_helper.dart

import 'package:url_launcher/url_launcher.dart';
import '../services/drive_config.dart';

class DriveUploadHelper {
  /// 📤 Ouvrir le dossier Drive dans le navigateur
  static Future<void> openDriveFolder() async {
    final url = DriveConfig.getFolderShareUrl(DriveConfig.folderId);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Impossible d\'ouvrir le dossier Drive');
    }
  }

  /// 📤 Ouvrir Drive avec un message d'instruction
  static Future<void> openDriveForUpload() async {
    // 1. Ouvrir le dossier Drive
    await openDriveFolder();
    
    // 2. Afficher un message d'instruction
    // (À gérer dans l'interface utilisateur)
  }
}