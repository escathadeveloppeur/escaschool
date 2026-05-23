// lib/screens/admin/admin_classes.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/db_helper.dart';
import '../../models/class_model.dart';
import '../../providers/auth_provider.dart';
import 'add_class_screen.dart';

class AdminClasses extends StatefulWidget {
  final Function? onChanged;
  
  const AdminClasses({super.key, this.onChanged});

  @override
  _AdminClassesState createState() => _AdminClassesState();
}

class _AdminClassesState extends State<AdminClasses> with SingleTickerProviderStateMixin {
  final DBHelper db = DBHelper();
  List<ClassModel> _classes = [];
  List<ClassModel> _filteredClasses = [];
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
    _loadClassesFromFirestore();
    _searchController.addListener(_filterClasses);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// 🔥 Charger les classes depuis Firestore
  Future<void> _loadClassesFromFirestore() async {
    setState(() => _isLoading = true);
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      Query query = FirebaseFirestore.instance.collection('classes');
      
      if (!auth.isSuperAdmin && schoolId != null) {
        query = query.where('schoolId', isEqualTo: schoolId);
      }
      
      final snapshot = await query.get();
      
      final List<ClassModel> loadedClasses = [];
  for (var doc in snapshot.docs) {
  final data = doc.data() as Map<String, dynamic>;
  loadedClasses.add(ClassModel(
    className: data['className'] ?? '',
    level: data['level'] ?? '',
    year: data['year'] ?? '',
    subjects: List<Map<String, dynamic>>.from(data['subjects'] ?? []),
    schoolId: data['schoolId'],
  ));
}
      setState(() {
        _classes = loadedClasses;
        _filteredClasses = loadedClasses;
        _isLoading = false;
      });
      _animationController.forward(from: 0);
      
      print('✅ ${loadedClasses.length} classes chargées depuis Firestore');
    } catch (e) {
      print('❌ Erreur chargement classes: $e');
      // Fallback vers Hive
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      List<ClassModel> classes;
      if (auth.isSuperAdmin) {
        classes = await db.getAllClasses();
      } else if (schoolId != null) {
        classes = await db.getClassesBySchool(schoolId);
      } else {
        classes = [];
      }
      
      setState(() {
        _classes = classes;
        _filteredClasses = classes;
        _isLoading = false;
      });
    }
  }

  void _filterClasses() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredClasses = List.from(_classes);
      } else {
        _filteredClasses = _classes.where((cls) {
          final className = cls.className.toLowerCase();
          final level = cls.level?.toLowerCase() ?? '';
          return className.contains(query) || level.contains(query);
        }).toList();
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

  /// 🔥 Supprimer une classe de Firestore
  Future<void> _deleteClass(ClassModel classModel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmation', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Voulez-vous vraiment supprimer la classe ${classModel.className} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (classModel.firestoreId != null) {
          await FirebaseFirestore.instance
              .collection('classes')
              .doc(classModel.firestoreId)
              .delete();
        }
        
        if (classModel.key != null) {
          await db.deleteClass(classModel.key!);
        }
        
        await _loadClassesFromFirestore();
        widget.onChanged?.call();
        _showSnackBar('Classe supprimée avec succès', const Color(0xFF10B981));
      } catch (e) {
        _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Gestion des classes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadClassesFromFirestore,
              style: IconButton.styleFrom(backgroundColor: Colors.grey[100]),
            ),
          ),
          if (!auth.isSuperAdmin || auth.currentSchoolId != null)
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: IconButton(
                icon: const Icon(Icons.add),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddClassScreen()),
                  );
                  if (result == true) await _loadClassesFromFirestore();
                },
                style: IconButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher une classe...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF10B981)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () { _searchController.clear(); _filterClasses(); })
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.school, size: 16, color: Color(0xFF3B82F6)),
                      ),
                      const SizedBox(width: 8),
                      Text('${_filteredClasses.length} classe(s) sur ${_classes.length}', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
                
                Expanded(
                  child: _filteredClasses.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.class_, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(_searchController.text.isEmpty ? 'Aucune classe' : 'Aucun résultat trouvé'),
                              if (_searchController.text.isNotEmpty)
                                TextButton(onPressed: () { _searchController.clear(); _filterClasses(); }, child: const Text('Effacer la recherche')),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredClasses.length,
                          itemBuilder: (context, index) {
                            final classModel = _filteredClasses[index];
                            return FadeTransition(
                              opacity: _animationController,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
                                child: ExpansionTile(
                                  leading: Container(
                                    width: 48, height: 48,
                                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF14B8A6)]), shape: BoxShape.circle),
                                    child: Center(child: Text(classModel.className.isNotEmpty ? classModel.className[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
                                  ),
                                  title: Text(classModel.className, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                            child: Text(classModel.level ?? 'Niveau non défini', style: const TextStyle(fontSize: 11, color: Color(0xFF3B82F6))),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                            child: Text(classModel.year ?? 'Année non définie', style: const TextStyle(fontSize: 11, color: Color(0xFFF59E0B))),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                        child: IconButton(
                                          icon: const Icon(Icons.edit, color: Color(0xFFF59E0B), size: 20),
                                          onPressed: () async {
                                            final result = await Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => AddClassScreen(classToEdit: classModel, classFirestoreId: classModel.firestoreId)),
                                            );
                                            if (result == true) await _loadClassesFromFirestore();
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                        child: IconButton(
                                          icon: const Icon(Icons.delete, color: Color(0xFFEF4444), size: 20),
                                          onPressed: () => _deleteClass(classModel),
                                        ),
                                      ),
                                    ],
                                  ),
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16))),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.book, size: 16, color: Color(0xFF10B981))),
                                              const SizedBox(width: 8),
                                              const Text('Matières enseignées', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                              const Spacer(),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                                child: Text('${classModel.subjects.length} matière(s)', style: const TextStyle(fontSize: 11, color: Color(0xFF3B82F6))),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          if (classModel.subjects.isEmpty)
                                            Container(
                                              padding: const EdgeInsets.all(24),
                                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
                                              child: Center(child: Text('Aucune matière assignée', style: TextStyle(color: Colors.grey[500]))),
                                            )
                                          else
                                            ...classModel.subjects.map((subject) {
                                              return Container(
                                                margin: const EdgeInsets.only(bottom: 8),
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
                                                child: Row(
                                                  children: [
                                                    Container(width: 32, height: 32, decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Center(child: Icon(Icons.book, size: 16, color: Color(0xFF3B82F6)))),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(subject['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                                          Text('Coefficient: ${subject['coefficient']}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                                        ],
                                                      ),
                                                    ),
                                                    if (subject['professorName']?.isNotEmpty ?? false)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                                                        child: Row(
                                                          children: [
                                                            const Icon(Icons.person, size: 12, color: Color(0xFF10B981)),
                                                            const SizedBox(width: 4),
                                                            Text(subject['professorName'], style: const TextStyle(fontSize: 11, color: Color(0xFF10B981))),
                                                          ],
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              );
                                            }),
                                        ],
                                      ),
                                    ),
                                  ],
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
}