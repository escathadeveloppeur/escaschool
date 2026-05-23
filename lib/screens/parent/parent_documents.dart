// lib/screens/parent/parent_documents.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';

class ParentDocumentsScreen extends StatefulWidget {
  const ParentDocumentsScreen({super.key});

  @override
  _ParentDocumentsScreenState createState() => _ParentDocumentsScreenState();
}

class _ParentDocumentsScreenState extends State<ParentDocumentsScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> children = [];
  Map<String, dynamic>? selectedChild;
  List<Map<String, dynamic>> documents = [];
  List<Map<String, dynamic>> filteredDocuments = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadChildrenAndDocuments();
    _searchController.addListener(_filterDocuments);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// 🔥 Charger les enfants et documents depuis Firestore
  Future<void> _loadChildrenAndDocuments() async {
    setState(() => _isLoading = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.user?.id;
    final userEmail = auth.user?.email;
    final schoolId = auth.currentSchoolId;

    if (userId != null || userEmail != null) {
      try {
        // Récupérer les enfants via parent_student_links
        Query parentLinksQuery = FirebaseFirestore.instance
            .collection('parent_student_links');
        
        if (userEmail != null) {
          parentLinksQuery = parentLinksQuery.where('parentEmail', isEqualTo: userEmail);
        } else {
          parentLinksQuery = parentLinksQuery.where('parentUserId', isEqualTo: userId);
        }
        
        final linksSnapshot = await parentLinksQuery.get();
        
        final List<String> childNames = [];
        for (var linkDoc in linksSnapshot.docs) {
          final data = linkDoc.data() as Map<String, dynamic>;
          final childName = data['studentName'];
          if (childName != null) {
            childNames.add(childName);
          }
        }
        
        // Récupérer les étudiants
        if (childNames.isNotEmpty) {
          final studentsSnapshot = await FirebaseFirestore.instance
              .collection('students')
              .where('fullName', whereIn: childNames)
              .get();
          
          children = studentsSnapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'firestoreId': doc.id,
              'fullName': data['fullName'] ?? '',
              'className': data['className'] ?? '',
              'schoolId': data['schoolId'],
            };
          }).toList();
          
          if (schoolId != null) {
            children = children.where((s) => s['schoolId'] == schoolId).toList();
          }
        }

        if (children.isNotEmpty) {
          selectedChild = children.first;
          await _loadDocumentsFromFirestore(selectedChild!);
        }
      } catch (e) {
        print('❌ Erreur chargement: $e');
        _showSnackBar('Erreur de chargement', const Color(0xFFEF4444));
      }
    }

    setState(() => _isLoading = false);
    _animationController.forward(from: 0);
  }

  /// 🔥 Charger documents depuis Firestore
  Future<void> _loadDocumentsFromFirestore(Map<String, dynamic> child) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('documents')
        .where('fullName', isEqualTo: child['fullName'])
        .get();
    
    documents = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'fullName': data['fullName'] ?? '',
        'className': data['className'] ?? '',
        'docType': data['docType'] ?? '',
        'isValidated': data['isValidated'] ?? false,
        'fileUrl': data['fileUrl'] ?? '',
        'createdAt': data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
      };
    }).toList();
    
    // Trier par date (plus récent en premier)
    documents.sort((a, b) => b['createdAt'].compareTo(a['createdAt']));
    filteredDocuments = List.from(documents);
  }

  void _filterDocuments() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredDocuments = List.from(documents);
      } else {
        filteredDocuments = documents.where((doc) => (doc['docType'] as String).toLowerCase().contains(query)).toList();
      }
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
    );
  }

  Color _getDocTypeColor(String docType) {
    switch (docType) {
      case 'Bulletin': return const Color(0xFF10B981);
      case 'Certificat': return const Color(0xFF3B82F6);
      case 'Attestation': return const Color(0xFFF59E0B);
      case 'Relevé de notes': return const Color(0xFF8B5CF6);
      case 'Convocation': return const Color(0xFFEF4444);
      case 'Autorisation': return const Color(0xFF14B8A6);
      default: return Colors.grey;
    }
  }

  IconData _getDocTypeIcon(String docType) {
    switch (docType) {
      case 'Bulletin': return Icons.assignment_turned_in;
      case 'Certificat': return Icons.card_membership;
      case 'Attestation': return Icons.description;
      case 'Relevé de notes': return Icons.receipt;
      case 'Convocation': return Icons.event;
      case 'Autorisation': return Icons.check_circle;
      default: return Icons.insert_drive_file;
    }
  }

  void _showDocumentDialog(Map<String, dynamic> doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _getDocTypeColor(doc['docType']).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(_getDocTypeIcon(doc['docType']), color: _getDocTypeColor(doc['docType']))),
            const SizedBox(width: 12),
            Expanded(child: Text(doc['docType'], style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Élève', doc['fullName']),
              const SizedBox(height: 8),
              _buildDetailRow('Classe', doc['className']),
              const SizedBox(height: 8),
              _buildDetailRow('Statut', doc['isValidated'] ? 'Validé' : 'En attente', valueColor: doc['isValidated'] ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
              const SizedBox(height: 20),
              Center(
                child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.picture_as_pdf, size: 80, color: Color(0xFFEF4444))),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
          if (doc['isValidated'])
            ElevatedButton.icon(
              onPressed: () { 
                Navigator.pop(context); 
                _downloadDocument(doc); 
              }, 
              icon: const Icon(Icons.download), 
              label: const Text('Télécharger'), 
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 70, child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]))),
        Expanded(child: Text(value, style: TextStyle(fontSize: 14, color: valueColor ?? Colors.black87))),
      ],
    );
  }

  Future<void> _downloadDocument(Map<String, dynamic> doc) async {
    await Future.delayed(const Duration(seconds: 1));
    _showSnackBar('Téléchargement de ${doc['docType']} terminé', const Color(0xFF10B981));
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Documents', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)), 
        backgroundColor: Colors.white, 
        foregroundColor: Colors.grey[800], 
        elevation: 0, 
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadChildrenAndDocuments)],
      ),
      body: Column(
        children: [
          if (auth.currentSchoolId != null)
            Container(
              margin: const EdgeInsets.all(16), 
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), 
              decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), 
              child: Row(children: [const Icon(Icons.business, size: 18, color: Color(0xFF3B82F6)), const SizedBox(width: 8), Text(auth.schoolName ?? 'Établissement scolaire', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF3B82F6)))]),
            ),

          if (children.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, 
                  children: [
                    Icon(Icons.child_care, size: 64, color: Colors.grey[300]), 
                    const SizedBox(height: 16), 
                    Text('Aucun enfant associé', style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
              ),
            ),
          if (children.isNotEmpty)
            Expanded(
              child: Column(
                children: [
                  if (children.length > 1)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16), 
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), 
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]), 
                      child: DropdownButtonFormField<Map<String, dynamic>>(
                        value: selectedChild,
                        decoration: const InputDecoration(border: InputBorder.none, prefixIcon: Icon(Icons.child_care, color: Color(0xFF10B981)), labelText: 'Choisir un enfant'),
                        items: children.map((child) {
                          return DropdownMenuItem(
                            value: child,
                            child: Text(child['fullName']),
                          );
                        }).toList(),
                        onChanged: (value) async { 
                          setState(() => _isLoading = true); 
                          selectedChild = value; 
                          await _loadDocumentsFromFirestore(value!); 
                          setState(() => _isLoading = false); 
                        },
                      ),
                    ),
                  if (children.length > 1) const SizedBox(height: 8),
                  Container(
                    margin: const EdgeInsets.all(16), 
                    child: TextField(
                      controller: _searchController, 
                      decoration: InputDecoration(
                        hintText: 'Rechercher un document...', 
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF10B981)), 
                        suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () { _searchController.clear(); _filterDocuments(); }) : null, 
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)), 
                        filled: true, 
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16), 
                    child: Row(
                      children: [
                        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.description, size: 16, color: Color(0xFF3B82F6))), 
                        const SizedBox(width: 8), 
                        Text('${filteredDocuments.length} document(s)', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: selectedChild == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center, 
                              children: [
                                Icon(Icons.child_care, size: 64, color: Colors.grey[300]), 
                                const SizedBox(height: 16), 
                                Text('Sélectionnez un enfant', style: TextStyle(color: Colors.grey[500])),
                              ],
                            ),
                          )
                        : filteredDocuments.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center, 
                                  children: [
                                    Icon(Icons.folder_open, size: 64, color: Colors.grey[300]), 
                                    const SizedBox(height: 16), 
                                    Text('Aucun document disponible', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: filteredDocuments.length,
                                itemBuilder: (context, index) {
                                  final doc = filteredDocuments[index];
                                  final docColor = _getDocTypeColor(doc['docType']);
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      leading: Container(
                                        width: 48, height: 48, 
                                        decoration: BoxDecoration(gradient: LinearGradient(colors: [docColor, docColor.withOpacity(0.7)]), borderRadius: BorderRadius.circular(14)), 
                                        child: Center(child: Icon(_getDocTypeIcon(doc['docType']), color: Colors.white, size: 24)),
                                      ),
                                      title: Text(doc['docType'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), 
                                            decoration: BoxDecoration(color: doc['isValidated'] ? const Color(0xFF10B981).withOpacity(0.1) : const Color(0xFFF59E0B).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), 
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min, 
                                              children: [
                                                Icon(doc['isValidated'] ? Icons.verified : Icons.pending, size: 12, color: doc['isValidated'] ? const Color(0xFF10B981) : const Color(0xFFF59E0B)), 
                                                const SizedBox(width: 4), 
                                                Text(doc['isValidated'] ? 'Validé' : 'En attente', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: doc['isValidated'] ? const Color(0xFF10B981) : const Color(0xFFF59E0B))),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: Container(
                                        decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(10)), 
                                        child: IconButton(icon: const Icon(Icons.visibility, color: Color(0xFF3B82F6)), onPressed: () => _showDocumentDialog(doc)),
                                      ),
                                      onTap: () => _showDocumentDialog(doc),
                                    ),
                                  );
                                },
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