// lib/screens/admin/professor_permissions.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/db_helper.dart';
import '../../models/class_model.dart';
import '../../providers/auth_provider.dart';

class ProfessorPermissionsScreen extends StatefulWidget {
  final String professorFirestoreId;
  final String professorName;

  const ProfessorPermissionsScreen({
    super.key,
    required this.professorFirestoreId,
    required this.professorName,
  });

  @override
  _ProfessorPermissionsScreenState createState() =>
      _ProfessorPermissionsScreenState();
}

class _ProfessorPermissionsScreenState extends State<ProfessorPermissionsScreen>
    with SingleTickerProviderStateMixin {
  final DBHelper db = DBHelper();
  List<Map<String, dynamic>> _allClasses = [];
  List<Map<String, dynamic>> _professorPermissions = [];
  bool _loading = true;

  late AnimationController _animationController;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredClasses = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadDataFromFirestore();
    _searchController.addListener(_filterClasses);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _filterClasses() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredClasses = List.from(_allClasses);
      } else {
        _filteredClasses = _allClasses.where((cls) {
          final className = (cls['className'] ?? '').toLowerCase();
          final level = (cls['level'] ?? '').toLowerCase();
          final year = (cls['year'] ?? '').toLowerCase();
          return className.contains(query) || level.contains(query) || year.contains(query);
        }).toList();
      }
    });
  }

  /// 🔥 Charger les classes et permissions depuis Firestore
  Future<void> _loadDataFromFirestore() async {
    setState(() => _loading = true);

    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║     CHARGEMENT DES PERMISSIONS PROFESSEUR                  ║');
    print('╚════════════════════════════════════════════════════════════╝\n');
    print('📌 Firestore ID Professeur: ${widget.professorFirestoreId}');
    print('📌 Nom Professeur: ${widget.professorName}\n');

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      final isSuperAdmin = auth.isSuperAdmin;

      // Charger les classes depuis Firestore
      print('🔍 [1/2] Chargement des classes...');
      Query classQuery = FirebaseFirestore.instance.collection('classes');
      if (!isSuperAdmin && schoolId != null) {
        classQuery = classQuery.where('schoolId', isEqualTo: schoolId);
        print('   → Filtre: schoolId == $schoolId');
      }
      
      final classesSnapshot = await classQuery.get();
      final List<Map<String, dynamic>> classesList = [];
      for (var doc in classesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        classesList.add({
          'firestoreId': doc.id,
          'className': data['className'] ?? '',
          'level': data['level'] ?? '',
          'year': data['year'] ?? '',
          'schoolId': data['schoolId'],
        });
        print('   📚 Classe: ${data['className']} (ID: ${doc.id})');
      }
      
      // Charger les permissions du professeur depuis Firestore
      print('\n🔍 [2/2] Chargement des permissions...');
      final permissionsSnapshot = await FirebaseFirestore.instance
          .collection('professor_permissions')
          .where('professorFirestoreId', isEqualTo: widget.professorFirestoreId)
          .get();
      
      final List<Map<String, dynamic>> permissionsList = [];
      for (var doc in permissionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        permissionsList.add({
          'firestoreId': doc.id,
          'classFirestoreId': data['classFirestoreId'] ?? '',
          'className': data['className'] ?? '',
          'permissionType': data['permissionType'] ?? 'view',
        });
        print('   🔐 Permission: ${data['className']} - ${data['permissionType']}');
      }

      setState(() {
        _allClasses = classesList;
        _filteredClasses = classesList;
        _professorPermissions = permissionsList;
        _loading = false;
      });
      _animationController.forward(from: 0);
      
      print('\n✅ ${classesList.length} classes, ${permissionsList.length} permissions chargées\n');
    } catch (e) {
      print('❌ Erreur chargement: $e');
      setState(() => _loading = false);
    }
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

  /// 🔥 Accorder une permission dans Firestore
  Future<void> _grantPermission(String classFirestoreId, String className, String permissionType) async {
    print('\n🔐 GRANT PERMISSION');
    print('   → Professeur ID: ${widget.professorFirestoreId}');
    print('   → Classe ID: $classFirestoreId');
    print('   → Classe: $className');
    print('   → Type: $permissionType');
    
    try {
      final permissionData = {
        'professorFirestoreId': widget.professorFirestoreId,
        'classFirestoreId': classFirestoreId,
        'className': className,
        'permissionType': permissionType,
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      final docRef = await FirebaseFirestore.instance.collection('professor_permissions').add(permissionData);
      await _loadDataFromFirestore();
      _showSnackBar('Accès accordé à $className ($permissionType)', const Color(0xFF10B981));
      print('✅ Permission créée avec ID: ${docRef.id}');
    } catch (e) {
      print('❌ Erreur: $e');
      _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
    }
  }

  /// 🔥 Retirer une permission de Firestore
  Future<void> _revokePermission(String permissionFirestoreId, String className) async {
    print('\n🔐 REVOKE PERMISSION');
    print('   → Permission ID: $permissionFirestoreId');
    print('   → Classe: $className');
    
    try {
      await FirebaseFirestore.instance
          .collection('professor_permissions')
          .doc(permissionFirestoreId)
          .delete();
      
      await _loadDataFromFirestore();
      _showSnackBar('Accès retiré de $className', const Color(0xFFF59E0B));
      print('✅ Permission supprimée');
    } catch (e) {
      print('❌ Erreur: $e');
      _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
    }
  }

  bool _hasPermission(String classFirestoreId) {
    return _professorPermissions.any((perm) => perm['classFirestoreId'] == classFirestoreId);
  }

  String _getPermissionType(String classFirestoreId) {
    final perm = _professorPermissions.firstWhere(
      (p) => p['classFirestoreId'] == classFirestoreId,
      orElse: () => {},
    );
    return perm['permissionType'] ?? 'view';
  }

  String? _getPermissionFirestoreId(String classFirestoreId) {
    final perm = _professorPermissions.firstWhere(
      (p) => p['classFirestoreId'] == classFirestoreId,
      orElse: () => {},
    );
    return perm['firestoreId'];
  }

  String _getPermissionLabel(String type) {
    switch (type) {
      case 'view': return 'Lecture';
      case 'edit': return 'Édition';
      case 'full': return 'Complet';
      default: return 'Inconnu';
    }
  }

  Color _getPermissionColor(String type) {
    switch (type) {
      case 'view': return const Color(0xFF3B82F6);
      case 'edit': return const Color(0xFF10B981);
      case 'full': return const Color(0xFF8B5CF6);
      default: return Colors.grey;
    }
  }

  void _showPermissionDialog(String classFirestoreId, String className, String currentPermission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.security, color: Color(0xFF3B82F6)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Permissions – $className', style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPermissionOption(
                title: 'Lecture seule',
                subtitle: 'Peut voir les informations mais pas modifier',
                type: 'view',
                currentPermission: currentPermission,
                onChanged: (value) {
                  Navigator.pop(context);
                  _grantPermission(classFirestoreId, className, 'view');
                },
              ),
              _buildPermissionOption(
                title: 'Édition',
                subtitle: 'Peut modifier les notes et présences',
                type: 'edit',
                currentPermission: currentPermission,
                onChanged: (value) {
                  Navigator.pop(context);
                  _grantPermission(classFirestoreId, className, 'edit');
                },
              ),
              _buildPermissionOption(
                title: 'Accès complet',
                subtitle: 'Toutes les permissions d\'édition',
                type: 'full',
                currentPermission: currentPermission,
                onChanged: (value) {
                  Navigator.pop(context);
                  _grantPermission(classFirestoreId, className, 'full');
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
          TextButton(
            onPressed: () {
              final permId = _getPermissionFirestoreId(classFirestoreId);
              if (permId != null) {
                Navigator.pop(context);
                _revokePermission(permId, className);
              }
            },
            child: const Text('Retirer accès', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionOption({
    required String title,
    required String subtitle,
    required String type,
    required String currentPermission,
    required Function(String?) onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      leading: Radio<String>(
        value: type,
        groupValue: currentPermission,
        onChanged: onChanged,
        activeColor: const Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isSuperAdmin = auth.isSuperAdmin;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Permissions – ${widget.professorName}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDataFromFirestore,
            style: IconButton.styleFrom(backgroundColor: Colors.grey[100]),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))))
          : Column(
              children: [
                if (!isSuperAdmin && _allClasses.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [const Icon(Icons.school, size: 18, color: Color(0xFF3B82F6)), const SizedBox(width: 8), const Text('Classes de votre école uniquement', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF3B82F6)))]),
                  ),

                FadeTransition(
                  opacity: _animationController,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _statItem('Classes', _filteredClasses.length.toString(), Icons.school, Colors.white),
                        _statItem('Accès', _professorPermissions.length.toString(), Icons.check_circle, const Color(0xFF10B981)),
                        _statItem('Sans accès', (_filteredClasses.length - _professorPermissions.length).toString(), Icons.block, const Color(0xFFEF4444)),
                      ],
                    ),
                  ),
                ),

                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher une classe...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF10B981)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () { _searchController.clear(); _filterClasses(); })
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
                      filled: true, fillColor: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Expanded(
                  child: _filteredClasses.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.class_, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(_searchController.text.isEmpty ? 'Aucune classe disponible' : 'Aucun résultat trouvé', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredClasses.length,
                          itemBuilder: (context, index) {
                            final cls = _filteredClasses[index];
                            final classFirestoreId = cls['firestoreId'];
                            final className = cls['className'] ?? '';
                            final level = cls['level'] ?? 'Niveau non défini';
                            final year = cls['year'] ?? 'Année non définie';
                            final hasPerm = _hasPermission(classFirestoreId);
                            final permType = _getPermissionType(classFirestoreId);
                            final permColor = _getPermissionColor(permType);

                            return FadeTransition(
                              opacity: _animationController,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: hasPerm ? permColor.withOpacity(0.05) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: Container(
                                    width: 48, height: 48,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: hasPerm ? [permColor, permColor.withOpacity(0.7)] : [Colors.grey[400]!, Colors.grey[500]!],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Center(child: Text(className.isNotEmpty ? className[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
                                  ),
                                  title: Text(className, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Text(level, style: const TextStyle(fontSize: 11, color: Color(0xFF3B82F6)))),
                                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Text(year, style: const TextStyle(fontSize: 11, color: Color(0xFFF59E0B)))),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: hasPerm
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            InkWell(
                                              onTap: () => _showPermissionDialog(classFirestoreId, className, permType),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(color: permColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                                                child: Text(_getPermissionLabel(permType), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: permColor)),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 22),
                                              onPressed: () {
                                                final permId = _getPermissionFirestoreId(classFirestoreId);
                                                if (permId != null) _revokePermission(permId, className);
                                              },
                                              tooltip: 'Retirer accès',
                                            ),
                                          ],
                                        )
                                      : ElevatedButton.icon(
                                          onPressed: () => _grantPermission(classFirestoreId, className, 'view'),
                                          icon: const Icon(Icons.add, size: 18),
                                          label: const Text('Accès'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF10B981),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        ),
                                  onTap: hasPerm ? () => _showPermissionDialog(classFirestoreId, className, permType) : null,
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

  Widget _statItem(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }
}