// lib/screens/staff/admin_documents.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import 'add_document.dart';

class AdminDocuments extends StatefulWidget {
  final VoidCallback? onChanged;
  const AdminDocuments({super.key, this.onChanged});

  @override
  _AdminDocumentsState createState() => _AdminDocumentsState();
}

class _AdminDocumentsState extends State<AdminDocuments> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> docs = [];
  List<Map<String, dynamic>> filtered = [];
  TextEditingController searchController = TextEditingController();
  bool loading = true;
  late AnimationController _animationController;
  String _selectedCycle = 'all'; // 'all', 'primaire', 'secondaire'

  final List<Map<String, dynamic>> _cycles = [
    {'id': 'all', 'name': 'Tous', 'icon': Icons.all_inclusive, 'color': Color(0xFF6366F1)},
    {'id': 'primaire', 'name': 'Primaire', 'icon': Icons.abc, 'color': Color(0xFF10B981)},
    {'id': 'secondaire', 'name': 'Secondaire', 'icon': Icons.school, 'color': Color(0xFF8B5CF6)},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadDocumentsFromFirestore();
    searchController.addListener(_filter);
  }

  @override
  void dispose() {
    searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// 🔥 Charger les documents depuis Firestore
  Future<void> _loadDocumentsFromFirestore() async {
    setState(() => loading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      Query query = FirebaseFirestore.instance.collection('documents');
      if (schoolId != null && !auth.isSuperAdmin) {
        query = query.where('schoolId', isEqualTo: schoolId);
      }
      
      final snapshot = await query.get();
      
      docs = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'firestoreId': doc.id,
          'studentFirestoreId': data['studentFirestoreId'] ?? '',
          'fullName': data['fullName'] ?? '',
          'classFirestoreId': data['classFirestoreId'] ?? '',
          'className': data['className'] ?? '',
          'classCycleType': data['classCycleType'] ?? 'primaire',
          'sectionName': data['sectionName'],
          'docType': data['docType'] ?? '',
          'isValidated': data['isValidated'] ?? false,
          'schoolId': data['schoolId'],
          'createdAt': data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
        };
      }).toList();
      
      // Trier par date (plus récent en premier)
      docs.sort((a, b) => b['createdAt'].compareTo(a['createdAt']));
      
      _filter();
      _animationController.forward(from: 0);
      
      print('✅ ${docs.length} documents chargés depuis Firestore');
    } catch (e) {
      debugPrint("❌ Erreur chargement documents: $e");
      _showSnackBar("Erreur chargement documents", const Color(0xFFEF4444));
    } finally {
      setState(() => loading = false);
    }
  }

  void _filter() {
    final searchQuery = searchController.text.trim().toLowerCase();
    
    setState(() {
      filtered = docs.where((doc) {
        // Filtrer par cycle
        if (_selectedCycle != 'all') {
          final docCycle = doc['classCycleType'] ?? 'primaire';
          if (docCycle != _selectedCycle) return false;
        }
        
        // Filtrer par recherche
        if (searchQuery.isNotEmpty) {
          final fullName = (doc['fullName'] as String).toLowerCase();
          final className = (doc['className'] as String).toLowerCase();
          final docType = (doc['docType'] as String).toLowerCase();
          if (!fullName.contains(searchQuery) && 
              !className.contains(searchQuery) && 
              !docType.contains(searchQuery)) {
            return false;
          }
        }
        
        return true;
      }).toList();
    });
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

  /// 🔥 Mettre à jour la validation dans Firestore
  Future<void> _toggleValidation(Map<String, dynamic> doc) async {
    final newStatus = !(doc['isValidated'] as bool);
    
    try {
      await FirebaseFirestore.instance
          .collection('documents')
          .doc(doc['firestoreId'])
          .update({
        'isValidated': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      await _loadDocumentsFromFirestore();
      widget.onChanged?.call();
      _showSnackBar(
        newStatus ? "Document validé" : "Document non validé",
        const Color(0xFF10B981),
      );
    } catch (e) {
      _showSnackBar("Erreur: $e", const Color(0xFFEF4444));
    }
  }

  /// 🔥 Supprimer un document de Firestore
  Future<void> _deleteDocument(String firestoreId) async {
    try {
      await FirebaseFirestore.instance
          .collection('documents')
          .doc(firestoreId)
          .delete();
      
      await _loadDocumentsFromFirestore();
      widget.onChanged?.call();
      _showSnackBar("Document supprimé", const Color(0xFF10B981));
    } catch (e) {
      _showSnackBar("Erreur: $e", const Color(0xFFEF4444));
    }
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  Widget _buildCycleSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: _cycles.map((cycle) {
          final isSelected = _selectedCycle == cycle['id'];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCycle = cycle['id'];
                  _filter();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isSelected ? cycle['color'] : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(cycle['icon'], color: isSelected ? Colors.white : cycle['color'], size: 18),
                    const SizedBox(width: 8),
                    Text(
                      cycle['name'],
                      style: TextStyle(
                        color: isSelected ? Colors.white : cycle['color'],
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          if (auth.currentSchoolId != null && !auth.isSuperAdmin)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.business, size: 18, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  Text(
                    'École : ${auth.schoolName ?? auth.currentSchoolId}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
            ),

          // Sélecteur de cycle
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _buildCycleSelector(),
          ),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.folder, color: Color(0xFF10B981), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Documents (${filtered.length})",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddDocumentScreen()),
                    );
                    if (result == true) {
                      await _loadDocumentsFromFirestore();
                      widget.onChanged?.call();
                    }
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text("Ajouter"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: "Rechercher (nom, classe, type...)",
                prefixIcon: const Icon(Icons.search, color: Color(0xFF10B981)),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          searchController.clear();
                          _filter();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    ),
                  )
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              "Aucun document",
                              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                            ),
                            const SizedBox(height: 8),
                            if (_selectedCycle != 'all')
                              Text(
                                "pour le ${_selectedCycle == 'primaire' ? 'primaire' : 'secondaire'}",
                                style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final d = filtered[i];
                          final docColor = (d['isValidated'] as bool)
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF59E0B);
                          final isSecondary = d['classCycleType'] == 'secondaire';
                          
                          return FadeTransition(
                            opacity: _animationController,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [docColor, docColor.withOpacity(0.7)],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.description,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        d['fullName'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isSecondary 
                                            ? const Color(0xFF8B5CF6).withOpacity(0.1)
                                            : const Color(0xFF10B981).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isSecondary ? Icons.school : Icons.abc,
                                            size: 10,
                                            color: isSecondary ? const Color(0xFF8B5CF6) : const Color(0xFF10B981),
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            isSecondary ? "Secondaire" : "Primaire",
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w500,
                                              color: isSecondary ? const Color(0xFF8B5CF6) : const Color(0xFF10B981),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.class_,
                                          size: 12,
                                          color: Colors.grey[500],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Classe: ${d['className']}",
                                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                    if (isSecondary && d['sectionName'] != null && d['sectionName'].isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.school,
                                              size: 12,
                                              color: Colors.purple[400],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              "Section: ${d['sectionName']}",
                                              style: TextStyle(fontSize: 11, color: Colors.purple[600]),
                                            ),
                                          ],
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      d['docType'],
                                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: docColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                (d['isValidated'] as bool) ? Icons.verified : Icons.pending,
                                                size: 12,
                                                color: docColor,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                (d['isValidated'] as bool) ? "Validé" : "Non validé",
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: docColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatDate(d['createdAt']),
                                          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch(
                                      value: d['isValidated'] as bool,
                                      onChanged: (_) => _toggleValidation(d),
                                      activeColor: const Color(0xFF10B981),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.edit, color: Color(0xFFF59E0B), size: 20),
                                        onPressed: () async {
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => AddDocumentScreen(
                                                document: d,
                                                firestoreId: d['firestoreId'],
                                              ),
                                            ),
                                          );
                                          if (result == true) {
                                            await _loadDocumentsFromFirestore();
                                            widget.onChanged?.call();
                                          }
                                        },
                                        tooltip: 'Modifier',
                                      ),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.delete, color: Color(0xFFEF4444), size: 20),
                                        onPressed: () => _confirmDeleteDocument(d),
                                        tooltip: 'Supprimer',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteDocument(Map<String, dynamic> d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Supprimer le document",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text("Supprimer le document de ${d['fullName']} (${d['docType']}) ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text("Annuler")
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Supprimer"),
          ),
        ],
      ),
    ) ?? false;
    if (ok) _deleteDocument(d['firestoreId']);
  }
}