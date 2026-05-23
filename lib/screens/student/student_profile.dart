// lib/screens/student/student_profile.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  _StudentProfileScreenState createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? student;
  bool _isLoading = true;
  bool _isEditing = false;
  late AnimationController _animationController;
  
  // Contrôleurs pour l'édition
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _fatherNameController = TextEditingController();
  final TextEditingController _motherNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadStudentDataFromFirestore();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _fatherNameController.dispose();
    _motherNameController.dispose();
    super.dispose();
  }

  /// 🔥 Charger les données depuis Firestore
  Future<void> _loadStudentDataFromFirestore() async {
    setState(() => _isLoading = true);
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.id;
      final userEmail = authProvider.user?.email;
      
      if (userId != null || userEmail != null) {
        // Récupérer l'étudiant via son compte utilisateur
        Query studentQuery = FirebaseFirestore.instance.collection('students');
        
        if (userEmail != null) {
          studentQuery = studentQuery.where('userEmail', isEqualTo: userEmail);
        } else {
          studentQuery = studentQuery.where('userId', isEqualTo: userId);
        }
        
        final studentSnapshot = await studentQuery.limit(1).get();
        
        if (studentSnapshot.docs.isNotEmpty) {
          final doc = studentSnapshot.docs.first;
          final data = doc.data() as Map<String, dynamic>;
          
          student = {
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
          
          _phoneController.text = student!['parentPhone'] ?? '';
          _addressController.text = student!['address'] ?? '';
          _fatherNameController.text = student!['fatherName'] ?? '';
          _motherNameController.text = student!['motherName'] ?? '';
          
          print('✅ Profil étudiant chargé depuis Firestore');
        } else {
          print('⚠️ Aucun étudiant trouvé pour userId: $userId');
          student = null;
        }
      }
      
      _animationController.forward(from: 0);
    } catch (e) {
      print('❌ Erreur chargement: $e');
      _showSnackBar('Erreur de chargement: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 🔥 Mettre à jour le profil dans Firestore
  Future<void> _updateProfile() async {
    if (student == null) return;

    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      final updateData = {
        'fatherName': _fatherNameController.text.trim(),
        'motherName': _motherNameController.text.trim(),
        'parentPhone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      await FirebaseFirestore.instance
          .collection('students')
          .doc(student!['firestoreId'])
          .update(updateData);
      
      // Mettre à jour l'objet local
      student!['fatherName'] = _fatherNameController.text.trim();
      student!['motherName'] = _motherNameController.text.trim();
      student!['parentPhone'] = _phoneController.text.trim();
      student!['address'] = _addressController.text.trim();
      
      setState(() {
        _isEditing = false;
        _isLoading = false;
      });

      _showSnackBar('Profil mis à jour avec succès', Colors.green);
      
    } catch (e) {
      print('❌ Erreur mise à jour: $e');
      setState(() => _isLoading = false);
      _showSnackBar('Erreur lors de la mise à jour: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))),
            SizedBox(height: 16),
            Text('Chargement du profil...'),
          ],
        ),
      );
    }

    if (student == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text('Profil étudiant non trouvé', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadStudentDataFromFirestore,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Mon Profil',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit, color: Color(0xFF10B981)),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              tooltip: 'Modifier le profil',
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _phoneController.text = student!['parentPhone'] ?? '';
                  _addressController.text = student!['address'] ?? '';
                  _fatherNameController.text = student!['fatherName'] ?? '';
                  _motherNameController.text = student!['motherName'] ?? '';
                });
              },
              tooltip: 'Annuler',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (auth.currentSchoolId != null && !auth.isSuperAdmin)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
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
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF3B82F6)),
                    ),
                  ],
                ),
              ),

            // Photo et informations principales
            FadeTransition(
              opacity: _animationController,
              child: Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              (student!['fullName'] as String).isNotEmpty 
                                  ? (student!['fullName'] as String)[0].toUpperCase() 
                                  : 'E',
                              style: const TextStyle(
                                fontSize: 48,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        if (student!['documentsVerified'] == true)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.verified,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      student!['fullName'],
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        (student!['className'] as String).isNotEmpty ? student!['className'] : 'Classe non assignée',
                        style: TextStyle(
                          color: const Color(0xFF10B981),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Informations personnelles
            _buildSection(
              'Informations personnelles',
              Icons.person,
              const Color(0xFF3B82F6),
              _isEditing ? _buildEditableInfo() : _buildInfo(),
            ),
            
            const SizedBox(height: 16),
            
            // Informations familiales
            _buildSection(
              'Informations familiales',
              Icons.family_restroom,
              const Color(0xFF10B981),
              _isEditing ? _buildEditableFamily() : _buildFamily(),
            ),
            
            const SizedBox(height: 16),
            
            // Statut des documents
            _buildSection(
              'Documents',
              Icons.folder,
              const Color(0xFFF59E0B),
              [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: student!['documentsVerified'] == true
                          ? const Color(0xFF10B981).withOpacity(0.1)
                          : const Color(0xFFF59E0B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      student!['documentsVerified'] == true ? Icons.verified : Icons.pending,
                      color: student!['documentsVerified'] == true ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    ),
                  ),
                  title: const Text('Statut des documents'),
                  subtitle: Text(
                    student!['documentsVerified'] == true 
                        ? 'Documents vérifiés' 
                        : 'En attente de vérification',
                  ),
                  trailing: student!['documentsVerified'] == true
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Validé',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'En attente',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                ),
              ],
            ),

            if (_isEditing) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _updateProfile,
                      icon: const Icon(Icons.save),
                      label: const Text('Enregistrer les modifications'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Color color, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  List<Widget> _buildInfo() {
    return [
      _buildInfoRow('Date de naissance', student!['birthDate'] ?? 'Non renseigné'),
      _buildInfoRow('Lieu de naissance', student!['birthPlace'] ?? 'Non renseigné'),
      _buildInfoRow('Adresse', student!['address'] ?? 'Non renseigné'),
      _buildInfoRow('Téléphone', student!['parentPhone'] ?? 'Non renseigné'),
    ];
  }

  List<Widget> _buildEditableInfo() {
    return [
      _buildInfoRow('Date de naissance', student!['birthDate'] ?? 'Non renseigné'),
      _buildInfoRow('Lieu de naissance', student!['birthPlace'] ?? 'Non renseigné'),
      _buildEditableField('Adresse', _addressController, Icons.home, maxLines: 2),
      _buildEditableField('Téléphone', _phoneController, Icons.phone, keyboardType: TextInputType.phone),
    ];
  }

  List<Widget> _buildFamily() {
    return [
      _buildInfoRow('Père', student!['fatherName'] ?? 'Non renseigné'),
      _buildInfoRow('Mère', student!['motherName'] ?? 'Non renseigné'),
    ];
  }

  List<Widget> _buildEditableFamily() {
    return [
      _buildEditableField('Nom du père', _fatherNameController, Icons.man),
      _buildEditableField('Nom de la mère', _motherNameController, Icons.woman),
    ];
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Non renseigné' : value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18, color: const Color(0xFF10B981)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981), width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        keyboardType: keyboardType,
        maxLines: maxLines,
      ),
    );
  }
}