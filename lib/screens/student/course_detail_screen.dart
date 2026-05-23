// lib/screens/student/course_detail_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/file_download_service.dart';
import '../../providers/auth_provider.dart';

class CourseDetailScreen extends StatefulWidget {
  final Map<String, dynamic> course;
  
  const CourseDetailScreen({super.key, required this.course});

  @override
  _CourseDetailScreenState createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> with SingleTickerProviderStateMixin {
  int _selectedTab = 0;
  Map<String, bool> _downloading = {};
  late AnimationController _animationController;
  final FileDownloadService _downloadService = FileDownloadService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openResource(Map<String, dynamic> resource) async {
    final url = resource['url'];
    final type = resource['type'];
    
    if (url == null || url.isEmpty) {
      _showSnackBar('URL non disponible', const Color(0xFFEF4444));
      return;
    }

    try {
      if (type == 'link') {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showSnackBar('Impossible d\'ouvrir le lien', const Color(0xFFEF4444));
        }
        return;
      }

      // Pour les fichiers (PDF, images, vidéos) - URL Firebase Storage
      setState(() {
        _downloading[url] = true;
      });
      
      final localPath = await _downloadService.getLocalFilePath(url);
      final file = File(localPath);
      
      if (await file.exists()) {
        setState(() {
          _downloading[url] = false;
        });
        await OpenFile.open(localPath);
      } else {
        final downloadedPath = await _downloadService.downloadFile(url);
        
        setState(() {
          _downloading[url] = false;
        });
        
        if (downloadedPath != null) {
          await OpenFile.open(downloadedPath);
          _showSnackBar('Fichier téléchargé avec succès', const Color(0xFF10B981));
        } else {
          _showSnackBar('Erreur lors du téléchargement', const Color(0xFFEF4444));
        }
      }
    } catch (e) {
      setState(() {
        _downloading[url] = false;
      });
      _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
    }
  }

  Future<void> _downloadResource(Map<String, dynamic> resource) async {
    final url = resource['url'];
    final title = resource['title'];
    
    if (url == null || url.isEmpty) {
      _showSnackBar('URL non disponible', const Color(0xFFEF4444));
      return;
    }

    setState(() {
      _downloading[url] = true;
    });

    try {
      final localPath = await _downloadService.downloadFile(url);
      
      setState(() {
        _downloading[url] = false;
      });
      
      if (localPath != null) {
        _showSnackBar('$title téléchargé avec succès', const Color(0xFF10B981));
      } else {
        _showSnackBar('Erreur lors du téléchargement', const Color(0xFFEF4444));
      }
    } catch (e) {
      setState(() {
        _downloading[url] = false;
      });
      _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
    }
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? const Color(0xFF10B981) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? const Color(0xFF10B981) : Colors.grey[600],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChaptersList() {
    final chapters = widget.course['chapters'] as List? ?? [];
    
    if (chapters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Aucun chapitre disponible',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final chapter = chapters[index] as Map<String, dynamic>;
        return FadeTransition(
          opacity: _animationController,
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: ExpansionTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              title: Text(
                chapter['title'] ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (chapter['content'] != null && (chapter['content'] as String).isNotEmpty)
                        Text(
                          chapter['content'],
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Colors.grey[700],
                          ),
                        ),
                      if (chapter['videoUrl'] != null && (chapter['videoUrl'] as String).isNotEmpty) ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final videoUrl = chapter['videoUrl'] as String;
                            if (videoUrl.isNotEmpty) {
                              final uri = Uri.parse(videoUrl);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else {
                                _showSnackBar('Impossible d\'ouvrir la vidéo', const Color(0xFFEF4444));
                              }
                            }
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Regarder la vidéo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResourcesList() {
    final resources = widget.course['resources'] as List? ?? [];
    
    if (resources.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.attach_file, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Aucune ressource disponible',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: resources.length,
      itemBuilder: (context, index) {
        final resource = resources[index] as Map<String, dynamic>;
        final isDownloading = _downloading[resource['url']] == true;
        final resourceColor = _getResourceColor(resource['type']);
        
        return FadeTransition(
          opacity: _animationController,
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: InkWell(
              onTap: () => _openResource(resource),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: resourceColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getResourceIcon(resource['type']),
                        color: resourceColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            resource['title'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          if (resource['description'] != null && (resource['description'] as String).isNotEmpty)
                            Text(
                              resource['description'],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.insert_drive_file,
                                size: 12,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                (resource['type']?.toUpperCase() ?? 'FICHIER'),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: isDownloading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                                  ),
                                )
                              : Icon(Icons.download, color: resourceColor),
                          onPressed: isDownloading ? null : () => _downloadResource(resource),
                          tooltip: 'Télécharger',
                        ),
                        IconButton(
                          icon: Icon(Icons.open_in_new, color: resourceColor),
                          onPressed: () => _openResource(resource),
                          tooltip: 'Ouvrir',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getResourceIcon(String? type) {
    switch (type) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'video': return Icons.video_library;
      case 'image': return Icons.image;
      case 'link': return Icons.link;
      default: return Icons.insert_drive_file;
    }
  }

  Color _getResourceColor(String? type) {
    switch (type) {
      case 'pdf': return const Color(0xFFEF4444);
      case 'video': return const Color(0xFF3B82F6);
      case 'image': return const Color(0xFF10B981);
      case 'link': return const Color(0xFF8B5CF6);
      default: return const Color(0xFF6366F1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final course = widget.course;
    final chapters = course['chapters'] as List? ?? [];
    final resources = course['resources'] as List? ?? [];
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          course['title'] ?? 'Cours',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Icon(Icons.menu_book, color: Colors.white, size: 28),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course['subject'] ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            course['className'] ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if ((course['description'] as String?)?.isNotEmpty ?? false)
                  Text(
                    course['description'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
              ],
            ),
          ),

          Container(
            color: Colors.white,
            child: Row(
              children: [
                _buildTab('Chapitres (${chapters.length})', 0),
                _buildTab('Ressources (${resources.length})', 1),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          Expanded(
            child: _selectedTab == 0
                ? _buildChaptersList()
                : _buildResourcesList(),
          ),
        ],
      ),
    );
  }
}