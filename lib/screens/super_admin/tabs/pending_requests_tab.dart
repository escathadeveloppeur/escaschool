// lib/screens/super_admin/tabs/pending_requests_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PendingRequestsTab extends StatefulWidget {
  const PendingRequestsTab({super.key});

  @override
  _PendingRequestsTabState createState() => _PendingRequestsTabState();
}

class _PendingRequestsTabState extends State<PendingRequestsTab> {
  String _filterRole = 'all';
  
  final List<String> _roles = ['all', 'admin', 'staff'];

  Future<void> _approveRequest(String requestId, String userId, String schoolId, String role, String schoolName) async {
    try {
      // 1. Mettre à jour l'utilisateur dans la collection 'users' avec schoolId
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'schoolId': schoolId,
        'schoolName': schoolName,
        'status': 'approved',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // 2. Mettre à jour users_info (si elle existe)
      final userInfoDoc = await FirebaseFirestore.instance.collection('users_info').doc(userId).get();
      if (userInfoDoc.exists) {
        await FirebaseFirestore.instance.collection('users_info').doc(userId).update({
          'schoolId': schoolId,
          'schoolName': schoolName,
          'status': 'approved',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Créer le document users_info s'il n'existe pas
        await FirebaseFirestore.instance.collection('users_info').doc(userId).set({
          'userId': userId,
          'schoolId': schoolId,
          'schoolName': schoolName,
          'status': 'approved',
          'role': role,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      // 3. Supprimer la demande
      await FirebaseFirestore.instance.collection('registration_requests').doc(requestId).delete();
      
      // 4. Ajouter un log
      await FirebaseFirestore.instance.collection('system_logs').add({
        'action': 'user_approved',
        'userId': userId,
        'role': role,
        'schoolId': schoolId,
        'schoolName': schoolName,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      _showSnackBar('✅ Compte $role approuvé et associé à $schoolName', Colors.green);
      
      // Rafraîchir la liste
      setState(() {});
    } catch (e) {
      print('❌ Erreur approbation: $e');
      _showSnackBar('❌ Erreur: $e', Colors.red);
    }
  }

  Future<void> _rejectRequest(String requestId, String userId) async {
    try {
      // 1. Supprimer la demande
      await FirebaseFirestore.instance.collection('registration_requests').doc(requestId).delete();
      
      // 2. Marquer l'utilisateur comme rejeté dans users_info
      final userInfoDoc = await FirebaseFirestore.instance.collection('users_info').doc(userId).get();
      if (userInfoDoc.exists) {
        await FirebaseFirestore.instance.collection('users_info').doc(userId).update({
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
        });
      }
      
      // 3. Optionnel: Désactiver le compte Firebase Auth
      // Note: Nécessite des privilèges admin, à faire via Cloud Function
      
      // 4. Ajouter un log
      await FirebaseFirestore.instance.collection('system_logs').add({
        'action': 'user_rejected',
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      _showSnackBar('✅ Demande rejetée', Colors.orange);
      
      // Rafraîchir la liste
      setState(() {});
    } catch (e) {
      print('❌ Erreur rejet: $e');
      _showSnackBar('❌ Erreur: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showAssignSchoolDialog(Map<String, dynamic> request, String requestId) {
    String? selectedSchoolId;
    String? selectedSchoolName;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Row(
            children: [
              Icon(request['role'] == 'admin' ? Icons.admin_panel_settings : Icons.work, 
                   color: request['role'] == 'admin' ? Colors.red : Colors.purple),
              const SizedBox(width: 10),
              Text('Associer à une école'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person, color: Colors.blue),
                      title: Text(
                        request['fullName'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(request['userEmail']),
                    ),
                    const Divider(),
                    ListTile(
                      leading: Icon(
                        request['role'] == 'admin' ? Icons.admin_panel_settings : Icons.work,
                        color: request['role'] == 'admin' ? Colors.red : Colors.purple,
                      ),
                      title: Text(request['roleLabel']),
                      subtitle: Text(request['position'] ?? 'Aucun poste spécifié'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('schools')
                    .where('isActive', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Erreur: ${snapshot.error}'));
                  }
                  
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final schools = snapshot.data!.docs;
                  
                  if (schools.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.warning, color: Colors.orange, size: 40),
                          SizedBox(height: 8),
                          Text(
                            'Aucune école disponible',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('Veuillez d\'abord créer une école.'),
                        ],
                      ),
                    );
                  }
                  
                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Sélectionner une école *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                    items: schools.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final schoolCode = data['schoolCode'] ?? '';
                      final schoolName = data['name'] ?? 'École sans nom';
                      return DropdownMenuItem(
                        value: doc.id,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              schoolName,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            if (schoolCode.isNotEmpty)
                              Text(
                                'Code: $schoolCode',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      final school = schools.firstWhere((doc) => doc.id == value);
                      final data = school.data() as Map<String, dynamic>;
                      setStateDialog(() {
                        selectedSchoolId = value;
                        selectedSchoolName = data['name'] ?? 'École';
                      });
                    },
                    validator: (value) => value == null ? 'Veuillez sélectionner une école' : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'L\'utilisateur sera associé à l\'école sélectionnée et pourra immédiatement se connecter.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: selectedSchoolId == null 
                ? null 
                : () {
                    Navigator.pop(context);
                    _approveRequest(
                      requestId, 
                      request['userId'], 
                      selectedSchoolId!, 
                      request['role'],
                      selectedSchoolName!,
                    );
                  },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
              ),
              child: const Text('Approuver'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filtres
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('Filtrer par rôle: '),
              const SizedBox(width: 8),
              ..._roles.map((role) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(role == 'all' ? 'Tous' : (role == 'admin' ? 'Admin' : 'Staff')),
                  selected: _filterRole == role,
                  onSelected: (selected) {
                    setState(() {
                      _filterRole = role;
                    });
                  },
                  backgroundColor: Colors.grey[200],
                  selectedColor: Colors.blue.withOpacity(0.2),
                ),
              )),
            ],
          ),
        ),
        
        // Liste des demandes
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('registration_requests')
                .where('status', isEqualTo: 'pending')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                );
              }
              
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              
              var requests = snapshot.data!.docs;
              
              if (_filterRole != 'all') {
                requests = requests.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['role'] == _filterRole;
                }).toList();
              }
              
              if (requests.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pending_actions, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune demande en attente',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Les nouvelles demandes apparaîtront ici',
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                );
              }
              
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final doc = requests[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final isAdmin = data['role'] == 'admin';
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isAdmin ? Colors.red.withOpacity(0.3) : Colors.purple.withOpacity(0.3),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundColor: isAdmin 
                              ? Colors.red.withOpacity(0.1) 
                              : Colors.purple.withOpacity(0.1),
                          child: Icon(
                            isAdmin 
                                ? Icons.admin_panel_settings 
                                : Icons.work,
                            size: 30,
                            color: isAdmin ? Colors.red : Colors.purple,
                          ),
                        ),
                        title: Text(
                          data['fullName'],
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              data['userEmail'],
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isAdmin 
                                        ? Colors.red.withOpacity(0.1) 
                                        : Colors.purple.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    data['roleLabel'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isAdmin ? Colors.red : Colors.purple,
                                    ),
                                  ),
                                ),
                                if (data['position'] != null && data['position'].isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '📌 ${data['position']}',
                                      style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '📅 ${(data['createdAt'] as Timestamp).toDate().toString().substring(0, 16)}',
                              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.check_circle, color: Colors.green),
                                onPressed: () => _showAssignSchoolDialog(data, doc.id),
                                tooltip: 'Approuver',
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.red),
                                onPressed: () => _rejectRequest(doc.id, data['userId']),
                                tooltip: 'Rejeter',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}