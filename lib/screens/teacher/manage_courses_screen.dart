// lib/screens/teacher/manage_courses_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import 'create_course_screen.dart';

class ManageCoursesScreen extends StatefulWidget {
  final String professorFirestoreId;
  final String professorName;
  
  const ManageCoursesScreen({
    super.key, 
    required this.professorFirestoreId, 
    required this.professorName,
  });

  @override
  _ManageCoursesScreenState createState() => _ManageCoursesScreenState();
}

class _ManageCoursesScreenState extends State<ManageCoursesScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _filteredCourses = [];
  bool _isLoading = true;
  String _searchQuery = '';
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _loadCoursesFromFirestore();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 🔥 Charger les cours depuis Firestore
  Future<void> _loadCoursesFromFirestore() async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      Query query = FirebaseFirestore.instance.collection('online_courses');
      query = query.where('professorFirestoreId', isEqualTo: widget.professorFirestoreId);
      
      if (schoolId != null && !auth.isSuperAdmin) {
        query = query.where('schoolId', isEqualTo: schoolId);
      }
      
      final snapshot = await query.get();
      
      _courses = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        _courses.add({
          'id': doc.id,
          'title': data['title'] ?? '',
          'description': data['description'] ?? '',
          'className': data['className'] ?? '',
          'subject': data['subject'] ?? '',
          'content': data['content'] ?? '',
          'videoUrl': data['videoUrl'] ?? '',
          'attachments': List<String>.from(data['attachments'] ?? []),
          'professorFirestoreId': data['professorFirestoreId'] ?? '',
          'professorName': data['professorName'] ?? '',
          'createdAt': data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
          'schoolId': data['schoolId'],
        });
      }
      
      _filterCourses();
    } catch (e) {
      print('❌ Erreur chargement cours: $e');
      _showSnackBar('Erreur de chargement', const Color(0xFFEF4444));
    } finally {
      setState(() => _isLoading = false);
      _animationController.forward(from: 0);
    }
  }

  void _filterCourses() {
    setState(() {
      _filteredCourses = _searchQuery.isEmpty 
          ? List.from(_courses) 
          : _courses.where((c) => 
              (c['title'] as String).toLowerCase().contains(_searchQuery.toLowerCase()) || 
              (c['subject'] as String).toLowerCase().contains(_searchQuery.toLowerCase()) || 
              (c['className'] as String).toLowerCase().contains(_searchQuery.toLowerCase())
            ).toList();
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

  /// 🔥 Supprimer un cours de Firestore
  Future<void> _deleteCourse(Map<String, dynamic> course) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmer', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Supprimer "${course['title']}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)), child: const Text('Supprimer')),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('online_courses')
            .doc(course['id'])
            .delete();
        
        await _loadCoursesFromFirestore();
        _showSnackBar('Cours supprimé', const Color(0xFF10B981));
      } catch (e) {
        _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
      }
    }
  }

  void _createCourse() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateCourseScreen(
          professorFirestoreId: widget.professorFirestoreId,
          professorName: widget.professorName,
        ),
      ),
    );
    if (result == true) {
      await _loadCoursesFromFirestore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Mes cours', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.add, color: Color(0xFF10B981)), onPressed: _createCourse),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadCoursesFromFirestore, style: IconButton.styleFrom(backgroundColor: Colors.grey[100])),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))))
          : Column(
              children: [
                if (auth.currentSchoolId != null && !auth.isSuperAdmin)
                  Container(
                    margin: const EdgeInsets.all(16), 
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), 
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), 
                    child: Row(
                      children: [
                        const Icon(Icons.business, size: 18, color: Colors.blue), 
                        const SizedBox(width: 8), 
                        Text('École : ${auth.schoolName ?? auth.currentSchoolId}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.blue)),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(16), 
                  color: Colors.white, 
                  child: TextField(
                    onChanged: (value) { 
                      _searchQuery = value; 
                      _filterCourses(); 
                    }, 
                    decoration: InputDecoration(
                      hintText: 'Rechercher...', 
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF10B981)), 
                      suffixIcon: _searchQuery.isNotEmpty 
                          ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () { _searchQuery = ''; _filterCourses(); }) 
                          : null, 
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)), 
                      filled: true, 
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                Flexible(
                  child: _filteredCourses.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center, 
                            children: [
                              Icon(Icons.menu_book, size: 64, color: Colors.grey[300]), 
                              const SizedBox(height: 16), 
                              Text(_searchQuery.isEmpty ? 'Aucun cours' : 'Aucun résultat', style: TextStyle(fontSize: 16, color: Colors.grey[500])), 
                              const SizedBox(height: 16), 
                              ElevatedButton.icon(
                                onPressed: _createCourse, 
                                icon: const Icon(Icons.add), 
                                label: const Text('Créer un cours'), 
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredCourses.length,
                          itemBuilder: (context, index) => FadeTransition(
                            opacity: _animationController,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white, 
                                borderRadius: BorderRadius.circular(16), 
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: Container(
                                  width: 50, height: 50, 
                                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF14B8A6)]), borderRadius: BorderRadius.circular(14)), 
                                  child: const Center(child: Icon(Icons.menu_book, color: Colors.white, size: 28)),
                                ),
                                title: Text(_filteredCourses[index]['title'], style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), 
                                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), 
                                      child: Text(_filteredCourses[index]['subject'], style: const TextStyle(fontSize: 11, color: Colors.blue)),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), 
                                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), 
                                      child: Text(_filteredCourses[index]['className'], style: const TextStyle(fontSize: 11, color: Colors.orange)),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min, 
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Color(0xFFEF4444), size: 20), 
                                      onPressed: () => _deleteCourse(_filteredCourses[index]),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}