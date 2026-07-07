// lib/widgets/drive_file_manager.dart

import 'package:flutter/material.dart';
import '../services/drive_storage_service.dart';
import '../utils/drive_url_utils.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ AJOUTER CET IMPORT// ✅ AJOUTER CET IMPORT

class DriveFileManager extends StatefulWidget {
  final String schoolId;
  final String? studentId;
  final String? classId;
  final String fileType; // 'all', 'image', 'pdf'

  const DriveFileManager({
    super.key,
    required this.schoolId,
    this.studentId,
    this.classId,
    this.fileType = 'all',
  });

  @override
  _DriveFileManagerState createState() => _DriveFileManagerState();
}

class _DriveFileManagerState extends State<DriveFileManager> {
  final DriveStorageService _driveService = DriveStorageService();
  List<Map<String, dynamic>> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _loading = true);
    
    try {
      List<Map<String, dynamic>> files;
      
      if (widget.studentId != null) {
        files = await _driveService.getStudentFiles(
          widget.schoolId, 
          widget.studentId!,
        );
      } else {
        files = await _driveService.getSchoolFiles(widget.schoolId);
      }
      
      // Filtrer par type
      if (widget.fileType != 'all') {
        files = files.where((f) => f['type'] == widget.fileType).toList();
      }
      
      setState(() {
        _files = files;
        _loading = false;
      });
    } catch (e) {
      print('❌ Erreur chargement fichiers: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête
        Row(
          children: [
            Text(
              '📁 Fichiers Drive (${_files.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () {
                // Ouvrir Drive
                _openDriveFolder();
              },
              icon: const Icon(Icons.drive_folder_upload),
              label: const Text('Ajouter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4285F4),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Liste des fichiers
        _loading
            ? const Center(child: CircularProgressIndicator())
            : _files.isEmpty
                ? Center(
                    child: Column(
                      children: [
                        Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun fichier disponible',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _files.length,
                    itemBuilder: (context, index) {
                      final file = _files[index];
                      return _buildFileCard(file);
                    },
                  ),
      ],
    );
  }

  Widget _buildFileCard(Map<String, dynamic> file) {
    final isImage = file['type'] == 'image';
    final isPDF = file['type'] == 'pdf';
    final fileUrl = file['fileUrl'] ?? '';
    final fileName = file['fileName'] ?? 'Fichier sans nom';
    
    // Extraire l'ID du fichier si c'est une URL Drive
    final fileId = DriveUrlUtils.extractFileId(fileUrl) ?? fileUrl;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isImage ? Colors.blue.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isImage ? Icons.image : (isPDF ? Icons.picture_as_pdf : Icons.insert_drive_file),
            color: isImage ? Colors.blue : Colors.red,
          ),
        ),
        title: Text(
          fileName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${_formatDate(file['uploadedAt'])} • ${file['type'] ?? 'document'}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility, color: Colors.blue),
              onPressed: () {
                _viewFile(fileId, isImage);
              },
              tooltip: 'Voir',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                _deleteFile(file['id']);
              },
              tooltip: 'Supprimer',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDriveFolder() async {
    final url = Uri.parse(
      'https://drive.google.com/drive/folders/${DriveStorageService.FOLDER_ID}'
    );
    try {
      await launchUrl(url);
    } catch (e) {
      print('❌ Erreur ouverture Drive: $e');
    }
  }

  void _viewFile(String fileId, bool isImage) {
    if (isImage) {
      // Afficher l'image
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.network(
                  DriveUrlUtils.getImageDisplayUrl(fileId),
                  height: 400,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Text('Erreur chargement image'),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fermer'),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Ouvrir le PDF dans le navigateur
      final url = Uri.parse(DriveUrlUtils.getPdfViewUrl(fileId));
      launchUrl(url);
    }
  }

  Future<void> _deleteFile(String fileId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Voulez-vous vraiment supprimer ce fichier ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        await _driveService.deleteFileReference(fileId);
        _loadFiles();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fichier supprimé'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Date inconnue';
    
    try {
      final date = (timestamp as Timestamp).toDate();
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Date inconnue';
    }
  }
}