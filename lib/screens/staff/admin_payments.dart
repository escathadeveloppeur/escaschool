// lib/screens/staff/admin_payments.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import 'add_payment.dart';

class AdminPayments extends StatefulWidget {
  final VoidCallback? onChanged;
  const AdminPayments({super.key, this.onChanged});

  @override
  _AdminPaymentsState createState() => _AdminPaymentsState();
}

class _AdminPaymentsState extends State<AdminPayments> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> payments = [];
  List<Map<String, dynamic>> filtered = [];
  TextEditingController searchController = TextEditingController();
  bool loading = true;
  late AnimationController _animationController;
  
  Map<String, List<String>> studentPaidMonths = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadPaymentsFromFirestore();
    searchController.addListener(_filter);
  }

  @override
  void dispose() {
    searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// 🔥 Charger les paiements depuis Firestore (sans orderBy pour éviter l'index)
  Future<void> _loadPaymentsFromFirestore() async {
    setState(() => loading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      Query query = FirebaseFirestore.instance.collection('payments');
      if (schoolId != null && !auth.isSuperAdmin) {
        query = query.where('schoolId', isEqualTo: schoolId);
      }
      
      // ⚠️ Temporairement sans orderBy pour éviter l'erreur d'index
      final snapshot = await query.get();
      
      payments = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'firestoreId': doc.id,
          'studentFirestoreId': data['studentFirestoreId'] ?? '',
          'fullName': data['fullName'] ?? '',
          'className': data['className'] ?? '',
          'month': data['month'] ?? 0,
          'monthName': data['monthName'] ?? '',
          'year': data['year'] ?? 0,
          'feeType': data['feeType'] ?? '',
          'amount': (data['amount'] as num?)?.toDouble() ?? 0.0,
          'paymentDate': data['paymentDate'] != null 
              ? (data['paymentDate'] as Timestamp).toDate().toIso8601String()
              : DateTime.now().toIso8601String(),
          'schoolId': data['schoolId'],
        };
      }).toList();
      
      // Trier manuellement par date (plus récent en premier)
      payments.sort((a, b) => b['paymentDate'].compareTo(a['paymentDate']));
      
      filtered = List.from(payments);
      _updateStudentPaidMonths();
      
      _animationController.forward(from: 0);
      
      print('✅ ${payments.length} paiements chargés depuis Firestore');
    } catch (e) {
      debugPrint("❌ Erreur chargement paiements: $e");
      _showSnackBar("Erreur chargement paiements", const Color(0xFFEF4444));
    } finally {
      setState(() => loading = false);
    }
  }

  void _updateStudentPaidMonths() {
    studentPaidMonths.clear();
    for (final payment in payments) {
      final studentId = payment['studentFirestoreId'] as String;
      if (studentId.isEmpty) continue;
      if (!studentPaidMonths.containsKey(studentId)) {
        studentPaidMonths[studentId] = [];
      }
      final monthYear = '${payment['month']}-${payment['year']}';
      if (!studentPaidMonths[studentId]!.contains(monthYear)) {
        studentPaidMonths[studentId]!.add(monthYear);
      }
    }
  }

  void _filter() {
    final q = searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        filtered = List.from(payments);
      } else {
        filtered = payments.where((p) {
          return (p['fullName'] as String).toLowerCase().contains(q) ||
                 (p['className'] as String).toLowerCase().contains(q) ||
                 (p['month'] as int).toString().contains(q) ||
                 (p['feeType'] as String).toLowerCase().contains(q);
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

  /// 🔥 Supprimer un paiement de Firestore
  Future<void> _deletePayment(String firestoreId) async {
    try {
      await FirebaseFirestore.instance
          .collection('payments')
          .doc(firestoreId)
          .delete();
      
      await _loadPaymentsFromFirestore();
      widget.onChanged?.call();
      _showSnackBar("Paiement supprimé", const Color(0xFF10B981));
    } catch (e) {
      debugPrint("❌ Erreur suppression: $e");
      _showSnackBar("Erreur lors de la suppression", const Color(0xFFEF4444));
    }
  }

  bool _hasStudentPaidForMonth(String studentId, int month, int year) {
    if (studentId.isEmpty) return false;
    if (!studentPaidMonths.containsKey(studentId)) return false;
    return studentPaidMonths[studentId]!.contains('$month-$year');
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    } catch (e) {
      return isoDate;
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return months[month - 1];
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
                  child: const Icon(Icons.payment, color: Color(0xFF10B981), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Paiements (${filtered.length})",
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
                      MaterialPageRoute(builder: (_) => const AddPaymentScreen()),
                    );
                    if (result == true) {
                      await _loadPaymentsFromFirestore();
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
                hintText: "Rechercher (nom, classe, mois...)",
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
                            Icon(Icons.payment, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              "Aucun paiement",
                              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final p = filtered[i];
                          final studentId = p['studentFirestoreId'] as String;
                          final month = p['month'] as int;
                          final year = p['year'] as int;
                          final isPaid = _hasStudentPaidForMonth(studentId, month, year);
                          final monthName = p['monthName'] as String? ?? _getMonthName(month);
                          
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
                                      colors: isPaid 
                                          ? [const Color(0xFF10B981), const Color(0xFF059669)]
                                          : [const Color(0xFF3B82F6), const Color(0xFF6366F1)],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      isPaid ? Icons.check_circle : Icons.payment,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  "${p['fullName']} — ${p['className']}",
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
                                      "$monthName $year • ${p['feeType']}",
                                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          "${(p['amount'] as double).toStringAsFixed(0)} FCFA",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatDate(p['paymentDate']),
                                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                        ),
                                      ],
                                    ),
                                    if (isPaid) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          "Payé",
                                          style: TextStyle(fontSize: 11, color: Color(0xFF10B981)),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
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
                                              builder: (_) => AddPaymentScreen(
                                                payment: p,
                                                firestoreId: p['firestoreId'],
                                              ),
                                            ),
                                          );
                                          if (result == true) {
                                            await _loadPaymentsFromFirestore();
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
                                        onPressed: () => _confirmDeletePayment(p),
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

  void _confirmDeletePayment(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Supprimer le paiement",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text("Supprimer le paiement de ${p['fullName']} (${p['monthName'] ?? _getMonthName(p['month'])} ${p['year']}) ?"),
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
    if (ok) _deletePayment(p['firestoreId']);
  }
}