// lib/screens/parent/parent_payments.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';

class ParentPaymentsScreen extends StatefulWidget {
  const ParentPaymentsScreen({super.key});

  @override
  _ParentPaymentsScreenState createState() => _ParentPaymentsScreenState();
}

class _ParentPaymentsScreenState extends State<ParentPaymentsScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> children = [];
  Map<String, dynamic>? selectedChild;
  List<Map<String, dynamic>> payments = [];
  List<Map<String, dynamic>> filteredPayments = [];
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
    _loadChildrenAndPayments();
    _searchController.addListener(_filterPayments);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// 🔥 Charger les enfants et paiements depuis Firestore
  Future<void> _loadChildrenAndPayments() async {
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
          await _loadPaymentsFromFirestore(selectedChild!);
        }
      } catch (e) {
        print('❌ Erreur chargement: $e');
        _showSnackBar('Erreur de chargement', const Color(0xFFEF4444));
      }
    }

    setState(() => _isLoading = false);
    _animationController.forward(from: 0);
  }

  /// 🔥 Charger paiements depuis Firestore
  Future<void> _loadPaymentsFromFirestore(Map<String, dynamic> child) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('payments')
        .where('fullName', isEqualTo: child['fullName'])
        .get();
    
    payments = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'fullName': data['fullName'] ?? '',
        'className': data['className'] ?? '',
        'month': data['month'] ?? 0,
        'year': data['year'] ?? DateTime.now().year,
        'amount': (data['amount'] as num?)?.toDouble() ?? 0.0,
        'status': data['status'] ?? 'pending',
        'paymentDate': data['paymentDate'] != null ? (data['paymentDate'] as Timestamp).toDate() : null,
        'paymentMethod': data['paymentMethod'] ?? 'Espèces',
      };
    }).toList();
    
    // Trier par date (plus récent en premier)
    payments.sort((a, b) {
      final dateA = a['paymentDate'] as DateTime?;
      final dateB = b['paymentDate'] as DateTime?;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });
    
    filteredPayments = List.from(payments);
  }

  void _filterPayments() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredPayments = List.from(payments);
      } else {
        filteredPayments = payments.where((p) => 
          (p['month'] as int).toString().contains(query) ||
          (p['year'] as int).toString().contains(query)
        ).toList();
      }
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
    );
  }

  double _getTotalPaid() {
    return payments.where((p) => p['status'] == 'paid').fold(0.0, (sum, p) => sum + (p['amount'] as double));
  }

  double _getTotalPending() {
    return payments.where((p) => p['status'] == 'pending').fold(0.0, (sum, p) => sum + (p['amount'] as double));
  }

  String _getMonthName(int month) {
    const months = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
    return months[month - 1];
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
        title: const Text('Paiements', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)), 
        backgroundColor: Colors.white, 
        foregroundColor: Colors.grey[800], 
        elevation: 0, 
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadChildrenAndPayments)],
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
                          await _loadPaymentsFromFirestore(value!); 
                          setState(() => _isLoading = false); 
                        },
                      ),
                    ),
                  if (children.length > 1) const SizedBox(height: 8),

                  // Résumé des paiements
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF14B8A6)]), borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSummaryItem('Payé', '${_getTotalPaid().toStringAsFixed(0)} FCFA', Icons.payment, Colors.white70),
                        _buildSummaryItem('En attente', '${_getTotalPending().toStringAsFixed(0)} FCFA', Icons.pending, const Color(0xFFF59E0B)),
                      ],
                    ),
                  ),

                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16), 
                    child: TextField(
                      controller: _searchController, 
                      decoration: InputDecoration(
                        hintText: 'Rechercher un paiement...', 
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF10B981)), 
                        suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () { _searchController.clear(); _filterPayments(); }) : null, 
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)), 
                        filled: true, 
                        fillColor: Colors.white,
                      ),
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
                        : filteredPayments.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center, 
                                  children: [
                                    Icon(Icons.payment, size: 64, color: Colors.grey[300]), 
                                    const SizedBox(height: 16), 
                                    Text('Aucun paiement enregistré', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: filteredPayments.length,
                                itemBuilder: (context, index) {
                                  final p = filteredPayments[index];
                                  final isPaid = p['status'] == 'paid';
                                  final monthName = _getMonthName(p['month']);
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      leading: Container(
                                        width: 48, height: 48, 
                                        decoration: BoxDecoration(color: isPaid ? const Color(0xFF10B981).withOpacity(0.1) : const Color(0xFFF59E0B).withOpacity(0.1), borderRadius: BorderRadius.circular(14)), 
                                        child: Icon(isPaid ? Icons.check_circle : Icons.pending, color: isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B), size: 24),
                                      ),
                                      title: Text('$monthName ${p['year']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                      subtitle: Text('${(p['amount'] as double).toStringAsFixed(0)} FCFA • ${p['paymentMethod']}', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
                                        decoration: BoxDecoration(color: isPaid ? const Color(0xFF10B981).withOpacity(0.1) : const Color(0xFFF59E0B).withOpacity(0.1), borderRadius: BorderRadius.circular(20)), 
                                        child: Text(isPaid ? 'Payé' : 'En attente', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B))),
                                      ),
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

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24), 
        const SizedBox(height: 4), 
        Text(value, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), 
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}