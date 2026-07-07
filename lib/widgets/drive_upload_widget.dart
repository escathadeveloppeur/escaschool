// lib/widgets/drive_upload_widget.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/drive_config.dart';
import '../utils/drive_url_utils.dart';

class DriveUploadWidget extends StatefulWidget {
  final Function(String fileId, String fileName) onFileSelected;
  
  const DriveUploadWidget({
    super.key,
    required this.onFileSelected,
  });

  @override
  _DriveUploadWidgetState createState() => _DriveUploadWidgetState();
}

class _DriveUploadWidgetState extends State<DriveUploadWidget> {
  final TextEditingController _fileIdController = TextEditingController();
  final TextEditingController _fileNameController = TextEditingController();
  bool _isLoading = false;

  void _openDriveInBrowser() async {
    final url = DriveConfig.getFolderShareUrl(DriveConfig.folderId);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _validateAndSubmit() {
    final fileId = _fileIdController.text.trim();
    final fileName = _fileNameController.text.trim();
    
    if (fileId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer l\'ID du fichier')),
      );
      return;
    }
    
    widget.onFileSelected(fileId, fileName.isNotEmpty ? fileName : 'Fichier Drive');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 📤 En-tête
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.drive_folder_upload,
                  color: Color(0xFF4285F4),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Uploader vers Drive',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 📋 Instructions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📋 Comment ajouter un fichier :',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '1. Cliquez sur "Ouvrir Drive"\n'
                  '2. Glissez-déposez votre fichier dans le dossier\n'
                  '3. Ouvrez le fichier sur Drive\n'
                  '4. Copiez l\'ID depuis l\'URL\n'
                  '5. Collez l\'ID ci-dessous',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Bouton Ouvrir Drive
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openDriveInBrowser,
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Ouvrir Drive dans le navigateur'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4285F4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Champ ID du fichier
          TextField(
            controller: _fileIdController,
            decoration: InputDecoration(
              labelText: 'ID du fichier Drive *',
              hintText: 'ex: 1ABC123DEF456',
              prefixIcon: const Icon(Icons.drive_file_rename_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.help_outline, color: Colors.grey),
                onPressed: _showHelpDialog,
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Champ Nom du fichier (optionnel)
          TextField(
            controller: _fileNameController,
            decoration: InputDecoration(
              labelText: 'Nom du fichier (optionnel)',
              hintText: 'ex: cours_maths.pdf',
              prefixIcon: const Icon(Icons.file_present),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Bouton Valider
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _validateAndSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Ajouter le fichier'),
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Comment trouver l\'ID ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '1. Ouvrez votre fichier sur Google Drive',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              '2. Regardez l\'URL dans le navigateur',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'https://drive.google.com/file/d/1ABC123DEF456/view\n\n🔑 ID = 1ABC123DEF456',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '3. Copiez l\'ID et collez-le dans l\'application',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}