// lib/screens/student_card_preview_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/student_card_service.dart';
import '../../models/student_card_model.dart';

class StudentCardPreviewScreen extends StatefulWidget {
  final StudentCardData cardData;

  const StudentCardPreviewScreen({Key? key, required this.cardData}) : super(key: key);

  @override
  State<StudentCardPreviewScreen> createState() => _StudentCardPreviewScreenState();
}

class _StudentCardPreviewScreenState extends State<StudentCardPreviewScreen> {
  Uint8List? _cardImage;
  bool _isLoading = true;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _generateCard();
  }

  Future<void> _generateCard() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final image = await StudentCardService.generateStudentCard(
        data: widget.cardData,
        width: 800,
        height: 550,
        pixelRatio: 2.0,
      );
      
      setState(() {
        _cardImage = image;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _saveCard() async {
    if (_cardImage == null) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      final filePath = await StudentCardService.saveCardToDevice(
        _cardImage!,
        widget.cardData.fullName,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Carte sauvegardée: $filePath'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Future<void> _shareCard() async {
    if (_cardImage == null) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      await StudentCardService.shareCard(
        _cardImage!,
        widget.cardData.fullName,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aperçu de la carte'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _generateCard,
          ),
        ],
      ),
      body: Column(
        children: [
          // Aperçu de la carte
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.grey[50]!,
                    Colors.grey[200]!,
                  ],
                ),
              ),
              child: Center(
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : _cardImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              _cardImage!,
                              fit: BoxFit.contain,
                            ),
                          )
                        : const Text('Erreur de génération'),
              ),
            ),
          ),
          
          // Boutons d'action
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading || _isGenerating ? null : _saveCard,
                        icon: const Icon(Icons.download),
                        label: const Text('Télécharger'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading || _isGenerating ? null : _shareCard,
                        icon: const Icon(Icons.share),
                        label: const Text('Partager'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Nom: ${widget.cardData.fullName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'École: ${widget.cardData.schoolName}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}