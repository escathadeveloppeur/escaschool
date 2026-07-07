// lib/config/drive_config.dart

class DriveConfig {
  // ================================================================
  // 🔑 CONFIGURATION DRIVE
  // ================================================================
  
  static const String apiKey = 'AIzaSyCJr_PmPQ9i7eID6REe-Irg80ngp9IsX8I';
  static const String folderId = '1WPmSnH_kiRnmDJywxaVwrRn-fH6Md6gR';
  
  // ✅ AJOUTER CETTE LIGNE
  static const String scriptUrl = 'https://script.google.com/macros/s/AKfycbzx6cXWNi9MX4cynszzy_K9OKLknUk5Xit5F-VPxTlQR0TLgOJanUfz9t5Pi-Cch1US/exec';

  // ================================================================
  // 🔗 URLS DE L'API GOOGLE DRIVE
  // ================================================================
  
  static String getListFilesUrl() {
    return 'https://www.googleapis.com/drive/v3/files'
        '?q="${folderId}" in parents'
        '&key=$apiKey'
        '&fields=files(id,name,mimeType,webContentLink,webViewLink,size,createdTime,modifiedTime)'
        '&pageSize=1000'
        '&orderBy=name%20asc';
  }

  static String getListFilesByTypeUrl(String mimeType) {
    return 'https://www.googleapis.com/drive/v3/files'
        '?q="${folderId}" in parents and mimeType="$mimeType"'
        '&key=$apiKey'
        '&fields=files(id,name,mimeType,webContentLink,webViewLink,size,createdTime)'
        '&pageSize=1000';
  }

  static String getListFilesBySearchUrl(String query) {
    return 'https://www.googleapis.com/drive/v3/files'
        '?q="${folderId}" in parents and name contains "$query"'
        '&key=$apiKey'
        '&fields=files(id,name,mimeType,webContentLink,webViewLink,size,createdTime)'
        '&pageSize=1000';
  }

  // ================================================================
  // 🖼️ URLS D'AFFICHAGE
  // ================================================================
  
  static String getImageUrl(String fileId) {
    return 'https://drive.google.com/uc?export=view&id=$fileId';
  }

  static String getPdfPreviewUrl(String fileId) {
    return 'https://drive.google.com/file/d/$fileId/preview';
  }

  static String getPdfFullscreenUrl(String fileId) {
    return 'https://drive.google.com/file/d/$fileId/preview?embedded=true';
  }

  static String getDownloadUrl(String fileId) {
    return 'https://drive.google.com/uc?export=download&id=$fileId';
  }

  static String getViewUrl(String fileId) {
    return 'https://drive.google.com/file/d/$fileId/view';
  }

  // ================================================================
  // 📁 URLS DE PARTAGE
  // ================================================================

  static String getFolderShareUrl(String folderId) {
    return 'https://drive.google.com/drive/folders/$folderId';
  }

  static String getFileShareUrl(String fileId) {
    return 'https://drive.google.com/file/d/$fileId/view';
  }

  // ================================================================
  // 🔍 URLS D'API POUR LES MÉTADONNÉES
  // ================================================================
  
  static String getFileMetadataUrl(String fileId) {
    return 'https://www.googleapis.com/drive/v3/files/$fileId'
        '?key=$apiKey'
        '&fields=id,name,mimeType,webContentLink,webViewLink,size,createdTime,modifiedTime,description';
  }

  static String getFileExportUrl(String fileId, String mimeType) {
    return 'https://www.googleapis.com/drive/v3/files/$fileId/export'
        '?key=$apiKey'
        '&mimeType=$mimeType';
  }

  // ================================================================
  // 📁 CONSTANTES DE TYPE MIME
  // ================================================================
  
  static const String mimeImage = 'image/';
  static const String mimePdf = 'application/pdf';
  static const String mimeDocument = 'application/vnd.google-apps.document';
  static const String mimeSpreadsheet = 'application/vnd.google-apps.spreadsheet';
  static const String mimePresentation = 'application/vnd.google-apps.presentation';
  static const String mimeFolder = 'application/vnd.google-apps.folder';
  static const String mimeVideo = 'video/';
  static const String mimeAudio = 'audio/';

  // ================================================================
  // 🔧 MÉTHODES UTILITAIRES
  // ================================================================
  
  static bool isValidDriveUrl(String url) {
    return url.isNotEmpty && url.contains('drive.google.com');
  }

  static bool isImage(String mimeType) {
    return mimeType.startsWith(mimeImage);
  }

  static bool isPdf(String mimeType) {
    return mimeType == mimePdf;
  }

  static bool isGoogleDocument(String mimeType) {
    return mimeType.startsWith('application/vnd.google-apps.');
  }

  static String getExtensionFromMime(String mimeType) {
    if (isImage(mimeType)) {
      switch (mimeType) {
        case 'image/jpeg': return '.jpg';
        case 'image/png': return '.png';
        case 'image/gif': return '.gif';
        case 'image/webp': return '.webp';
        case 'image/svg+xml': return '.svg';
        default: return '.img';
      }
    }
    if (isPdf(mimeType)) return '.pdf';
    return '';
  }
}