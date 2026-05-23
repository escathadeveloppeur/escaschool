// lib/screens/staff/admin_students.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import 'add_student.dart';
import 'student_permissions.dart';

class AdminStudents extends StatefulWidget {
  final VoidCallback? onChanged;
  const AdminStudents({super.key, this.onChanged});

  @override
  _AdminStudentsState createState() => _AdminStudentsState();
}

class _AdminStudentsState extends State<AdminStudents> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> filtered = [];
  TextEditingController searchController = TextEditingController();
  bool loading = true;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadStudentsFromFirestore();
    searchController.addListener(_filter);
  }

  @override
  void dispose() {
    searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// 🔥 Charger TOUS les étudiants depuis Firestore (sans filtre parent)
  Future<void> _loadStudentsFromFirestore() async {
    setState(() => loading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      Query query = FirebaseFirestore.instance.collection('students');
      
      // Filtrer par école si ce n'est pas super admin
      if (schoolId != null && !auth.isSuperAdmin) {
        query = query.where('schoolId', isEqualTo: schoolId);
      }
      
      final snapshot = await query.get();
      
      students = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'firestoreId': doc.id,
          'fullName': data['fullName'] ?? '',
          'className': data['className'] ?? '',
          'birthDate': data['birthDate'] ?? '',
          'birthPlace': data['birthPlace'] ?? '',
          'fatherName': data['fatherName'] ?? '',
          'motherName': data['motherName'] ?? '',
          'parentPhone': data['parentPhone'] ?? '',
          'address': data['address'] ?? '',
          'documentsVerified': data['documentsVerified'] ?? false,
          'userId': data['userId'],
          'parentUserId': data['parentUserId'],
          'parentRelation': data['parentRelation'] ?? '',
          'schoolId': data['schoolId'],
        };
      }).toList();
      
      filtered = List.from(students);
      _animationController.forward(from: 0);
      
      print('✅ ${students.length} étudiants chargés depuis Firestore');
    } catch (e) {
      debugPrint("❌ Erreur chargement étudiants: $e");
      _showSnackBar("Erreur chargement étudiants", const Color(0xFFEF4444));
    } finally {
      setState(() => loading = false);
    }
  }

  void _filter() {
    final q = searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        filtered = List.from(students);
      } else {
        filtered = students.where((s) =>
            (s['fullName'] as String).toLowerCase().contains(q) ||
            (s['className'] as String).toLowerCase().contains(q) ||
            (s['parentPhone'] as String).toLowerCase().contains(q)
        ).toList();
      }
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

  /// 🔥 Supprimer un étudiant de Firestore
  Future<void> _deleteStudent(String firestoreId) async {
    try {
      // Supprimer l'étudiant
      await FirebaseFirestore.instance
          .collection('students')
          .doc(firestoreId)
          .delete();
      
      // Supprimer aussi les liens parent-enfant associés
      final linksSnapshot = await FirebaseFirestore.instance
          .collection('parent_student_links')
          .where('studentId', isEqualTo: firestoreId)
          .get();
      
      for (var linkDoc in linksSnapshot.docs) {
        await linkDoc.reference.delete();
      }
      
      await _loadStudentsFromFirestore();
      widget.onChanged?.call();
      _showSnackBar("Étudiant supprimé", const Color(0xFF10B981));
    } catch (e) {
      debugPrint("❌ Erreur suppression: $e");
      _showSnackBar("Erreur lors de la suppression", const Color(0xFFEF4444));
    }
  }

  /// 🔥 Obtenir le statut de vérification des documents
  bool _isVerified(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Indicateur d'école
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

          // En-tête avec compteur
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
                  child: const Icon(Icons.school, color: Color(0xFF10B981), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Liste des étudiants (${filtered.length})",
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
                      MaterialPageRoute(builder: (_) => const AddStudentScreen()),
                    );
                    if (result == true) {
                      await _loadStudentsFromFirestore();
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
          
          // Barre de recherche
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: "Rechercher par nom, classe ou téléphone...",
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
          
          // Liste des étudiants
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
                            Icon(Icons.person_off, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              "Aucun étudiant",
                              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const AddStudentScreen()),
                                );
                                if (result == true) {
                                  await _loadStudentsFromFirestore();
                                  widget.onChanged?.call();
                                }
                              },
                              icon: const Icon(Icons.add),
                              label: const Text("Ajouter un étudiant"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final s = filtered[i];
                          final isVerified = _isVerified(s['documentsVerified']);
                          
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
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Text(
                                      (s['fullName'] as String).isNotEmpty ? (s['fullName'] as String)[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  s['fullName'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      "Classe: ${s['className']}",
                                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                    ),
                                    if (s['parentPhone'] != null && (s['parentPhone'] as String).isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          "📞 ${s['parentPhone']}",
                                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isVerified
                                            ? const Color(0xFF10B981).withOpacity(0.1)
                                            : const Color(0xFFF59E0B).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isVerified ? Icons.verified : Icons.pending,
                                            size: 12,
                                            color: isVerified
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFFF59E0B),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isVerified ? "Documents vérifiés" : "En attente",
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: isVerified
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFFF59E0B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8B5CF6).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.security, color: Color(0xFF8B5CF6), size: 20),
                                        onPressed: () => Navigator.push(
                                          context,
        MaterialPageRoute(
  builder: (context) => StudentPermissionsScreen(
    studentFirestoreId: s['firestoreId'],
    studentName: s['fullName'],
  ),
),
                                        ),
                                        tooltip: 'Permissions',
                                      ),
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
                                              builder: (_) => AddStudentScreen(
                                                student: s,
                                                firestoreId: s['firestoreId'],
                                              ),
                                            ),
                                          );
                                          if (result == true) {
                                            await _loadStudentsFromFirestore();
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
                                        onPressed: () => _confirmDeleteStudent(s['firestoreId']),
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

  void _confirmDeleteStudent(String firestoreId) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              "Confirmer la suppression",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text("Voulez-vous vraiment supprimer cet étudiant ?\n\nToutes ses données seront supprimées définitivement."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Annuler"),
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
        ) ??
        false;
    if (ok) _deleteStudent(firestoreId);
  }
}