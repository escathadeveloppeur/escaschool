// lib/utils/drive_url_utils.dart

import 'package:flutter/material.dart';
import '../services/drive_config.dart';

class DriveUrlUtils {
  // ================================================================
  // 🔗 CONSTRUCTION D'URLS
  // ================================================================

  /// 🔗 URL de téléchargement direct
  static String getDirectDownloadUrl(String fileId) {
    return 'https://drive.google.com/uc?export=download&id=$fileId';
  }

  /// 🔗 URL de visualisation dans le navigateur
  static String getViewUrl(String fileId) {
    return 'https://drive.google.com/file/d/$fileId/view';
  }

  /// 🔗 URL de prévisualisation (pour les PDF)
  static String getPreviewUrl(String fileId) {
    return 'https://drive.google.com/file/d/$fileId/preview';
  }

  /// 🖼️ URL d'affichage d'image (export view)
  static String getImageUrl(String fileId) {
    return DriveConfig.getImageUrl(fileId);
  }

  /// 📄 URL d'affichage de PDF (prévisualisation)
  static String getPdfUrl(String fileId) {
    return DriveConfig.getPdfPreviewUrl(fileId);
  }

  /// 📄 URL d'affichage de PDF avec zoom
  static String getPdfZoomUrl(String fileId) {
    return 'https://drive.google.com/file/d/$fileId/preview?zoom=1';
  }

  /// 📤 URL de téléchargement
  static String getDownloadUrl(String fileId) {
    return DriveConfig.getDownloadUrl(fileId);
  }

  /// 🔗 URL d'API pour récupérer les métadonnées
  static String getApiUrl(String fileId) {
    return 'https://www.googleapis.com/drive/v3/files/$fileId'
        '?key=${DriveConfig.apiKey}'
        '&fields=webContentLink,name,mimeType,size,createdTime,modifiedTime,description';
  }

  /// 🔗 URL pour lister les fichiers d'un dossier
  static String getListFilesUrl() {
    return DriveConfig.getListFilesUrl();
  }

  /// 🔗 URL pour lister les fichiers avec filtrage
  static String getListFilesUrlWithFilter({String? mimeType, String? query}) {
    String url = DriveConfig.getListFilesUrl();
    
    if (mimeType != null && mimeType.isNotEmpty) {
      url += '&q=mimeType="$mimeType"';
    }
    
    if (query != null && query.isNotEmpty) {
      url += '&q=name contains "$query"';
    }
    
    return url;
  }
// lib/utils/drive_url_utils.dart

// Ajoutez ces méthodes à la classe DriveUrlUtils

/// 🖼️ URL d'affichage d'image (ancien nom pour compatibilité)
static String getImageDisplayUrl(String fileId) {
  return getImageUrl(fileId);
}

/// 📄 URL d'affichage de PDF (ancien nom pour compatibilité)
static String getPdfViewUrl(String fileId) {
  return getPdfUrl(fileId);
}
  // ================================================================
  // 🔍 EXTRACTION D'ID
  // ================================================================

  /// 🔗 Extraire l'ID du fichier depuis une URL Drive
  static String? extractFileId(String driveUrl) {
    if (driveUrl.isEmpty) return null;
    
    // Pattern 1: https://drive.google.com/file/d/1ABC123DEF456/view
    RegExp regExp1 = RegExp(r'/d/([^/]+)/');
    final match1 = regExp1.firstMatch(driveUrl);
    if (match1 != null) return match1.group(1);
    
    // Pattern 2: https://drive.google.com/uc?export=view&id=1ABC123DEF456
    RegExp regExp2 = RegExp(r'[?&]id=([^&]+)');
    final match2 = regExp2.firstMatch(driveUrl);
    if (match2 != null) return match2.group(1);
    
    // Pattern 3: https://drive.google.com/open?id=1ABC123DEF456
    RegExp regExp3 = RegExp(r'open\?id=([^&]+)');
    final match3 = regExp3.firstMatch(driveUrl);
    if (match3 != null) return match3.group(1);
    
    // Pattern 4: Direct ID (si l'URL est déjà l'ID)
    if (driveUrl.length == 33 && !driveUrl.contains('/')) {
      return driveUrl;
    }
    
    return null;
  }

  /// 🔗 Extraire l'ID du dossier depuis une URL Drive
  static String? extractFolderId(String driveUrl) {
    if (driveUrl.isEmpty) return null;
    
    // Pattern: https://drive.google.com/drive/folders/1ABC123DEF456
    final match = RegExp(r'/folders/([^/?]+)').firstMatch(driveUrl);
    return match?.group(1);
  }

  /// 🔗 Vérifier si l'URL est une URL Drive valide
  static bool isValidDriveUrl(String url) {
    if (url.isEmpty) return false;
    return url.contains('drive.google.com');
  }

  /// 🔗 Vérifier si le fichier est accessible publiquement
  static bool isPubliclyAccessible(String url) {
    if (url.isEmpty) return false;
    return url.contains('drive.google.com') && !url.contains('?usp=drive_link');
  }

  // ================================================================
  // 📁 DÉTECTION DE TYPE
  // ================================================================

  /// 📁 Déterminer le type de fichier à partir du MIME type
  static String getFileTypeFromMime(String mimeType) {
    if (mimeType.startsWith('image/')) return 'image';
    if (mimeType == 'application/pdf') return 'pdf';
    if (mimeType.startsWith('video/')) return 'video';
    if (mimeType.startsWith('audio/')) return 'audio';
    if (mimeType == 'application/vnd.google-apps.document') return 'document';
    if (mimeType == 'application/vnd.google-apps.spreadsheet') return 'spreadsheet';
    if (mimeType == 'application/vnd.google-apps.presentation') return 'presentation';
    if (mimeType == 'application/vnd.google-apps.folder') return 'folder';
    return 'document';
  }

  /// 📁 Déterminer le type de fichier à partir de l'extension
  static String getFileTypeFromExtension(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    
    switch (ext) {
      case 'jpg': case 'jpeg': case 'png': case 'gif': case 'webp': case 'svg':
        return 'image';
      case 'pdf':
        return 'pdf';
      case 'mp4': case 'avi': case 'mov': case 'mkv': case 'webm':
        return 'video';
      case 'mp3': case 'wav': case 'aac': case 'flac': case 'ogg':
        return 'audio';
      case 'doc': case 'docx':
        return 'document';
      case 'xls': case 'xlsx': case 'csv':
        return 'spreadsheet';
      case 'ppt': case 'pptx':
        return 'presentation';
      default:
        return 'document';
    }
  }

  /// 📁 Obtenir l'extension du fichier
  static String getFileExtension(String fileName) {
    final parts = fileName.split('.');
    if (parts.length > 1) {
      return parts.last.toLowerCase();
    }
    return '';
  }

  /// 📁 Obtenir le nom du fichier sans extension
  static String getFileNameWithoutExtension(String fileName) {
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot > 0) {
      return fileName.substring(0, lastDot);
    }
    return fileName;
  }

  /// 📁 Obtenir l'icône pour un type de fichier
  static IconData getFileIcon(String type) {
    switch (type) {
      case 'image': return Icons.image;
      case 'pdf': return Icons.picture_as_pdf;
      case 'video': return Icons.video_library;
      case 'audio': return Icons.audiotrack;
      case 'spreadsheet': return Icons.table_chart;
      case 'presentation': return Icons.slideshow;
      case 'folder': return Icons.folder;
      case 'document': 
      default: return Icons.insert_drive_file;
    }
  }

  /// 📁 Obtenir la couleur pour un type de fichier
  static Color getFileColor(String type) {
    switch (type) {
      case 'image': return Colors.blue;
      case 'pdf': return Colors.red;
      case 'video': return Colors.purple;
      case 'audio': return Colors.orange;
      case 'spreadsheet': return Colors.green;
      case 'presentation': return Colors.deepOrange;
      case 'folder': return Colors.amber;
      case 'document': 
      default: return Colors.grey;
    }
  }

  /// 📁 Obtenir le libellé du type de fichier en français
  static String getFileTypeLabel(String type) {
    switch (type) {
      case 'image': return 'Image';
      case 'pdf': return 'PDF';
      case 'video': return 'Vidéo';
      case 'audio': return 'Audio';
      case 'spreadsheet': return 'Tableur';
      case 'presentation': return 'Présentation';
      case 'folder': return 'Dossier';
      case 'document': 
      default: return 'Document';
    }
  }

  // ================================================================
  // 🔗 URL DE PARTAGE
  // ================================================================

  /// 🔗 URL de partage d'un fichier
  static String getShareUrl(String fileId) {
    return 'https://drive.google.com/file/d/$fileId/view';
  }

  /// 🔗 URL de partage d'un dossier
  static String getFolderShareUrl(String folderId) {
    return 'https://drive.google.com/drive/folders/$folderId';
  }

  /// 🔗 URL de partage avec lien direct
  static String getDirectShareUrl(String fileId) {
    return 'https://drive.google.com/uc?export=download&id=$fileId';
  }

  // ================================================================
  // 🖼️ EMBEDDING
  // ================================================================

  /// 🖼️ URL pour intégrer une image dans un <img> tag
  static String getEmbedImageUrl(String fileId) {
    return 'https://drive.google.com/uc?export=view&id=$fileId';
  }

  /// 📄 URL pour intégrer un PDF dans un <iframe>
  static String getEmbedPdfUrl(String fileId) {
    return 'https://drive.google.com/file/d/$fileId/preview?embed=true';
  }

  // ================================================================
  // 🔧 MÉTHODES UTILITAIRES
  // ================================================================

  /// 🔗 Nettoyer une URL (supprimer les paramètres inutiles)
  static String cleanUrl(String url) {
    if (url.isEmpty) return url;
    
    // Supprimer les paramètres de partage
    final cleaned = url.replaceAll('?usp=drive_link', '');
    return cleaned;
  }

  /// 📁 Obtenir le nom de fichier à partir d'une URL
  static String getFileNameFromUrl(String url) {
    if (url.isEmpty) return '';
    
    final cleaned = url.split('?').first;
    final parts = cleaned.split('/');
    return parts.last;
  }

  /// 📁 Formater la taille du fichier
  static String formatFileSize(int? sizeInBytes) {
    if (sizeInBytes == null) return 'Taille inconnue';
    
    const units = ['o', 'Ko', 'Mo', 'Go', 'To'];
    double size = sizeInBytes.toDouble();
    int unitIndex = 0;
    
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    
    return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
  }

  /// 📁 Formater la date
  static String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// 📁 Formater la date courte
  static String formatDateShort(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// 📁 Récupérer l'icône et la couleur en un seul appel
  static Map<String, dynamic> getFileIconAndColor(String type) {
    return {
      'icon': getFileIcon(type),
      'color': getFileColor(type),
    };
  }

  /// 📁 Vérifier si le fichier est une image
  static bool isImageType(String type) {
    return type == 'image';
  }

  /// 📁 Vérifier si le fichier est un PDF
  static bool isPdfType(String type) {
    return type == 'pdf';
  }

  /// 📁 Vérifier si le fichier est une vidéo
  static bool isVideoType(String type) {
    return type == 'video';
  }

  /// 📁 Vérifier si le fichier est un audio
  static bool isAudioType(String type) {
    return type == 'audio';
  }

  /// 📁 Vérifier si le fichier est un document
  static bool isDocumentType(String type) {
    return type == 'document' || type == 'spreadsheet' || type == 'presentation';
  }
}