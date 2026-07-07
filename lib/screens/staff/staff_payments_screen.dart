// lib/screens/staff/staff_payments_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import 'add_staff_payment_screen.dart';
import '../admin/admin_announcements.dart';

// ===================== PALETTE / THEME HELPERS =====================
class _AppColors {
  static const Color primary = Color(0xFF1E3A8A);
  static const Color primaryLight = Color(0xFF3B5BDB);
  static const Color background = Color(0xFFF4F6FB);
  static const Color cardBorder = Color(0xFFE6E9F2);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
}

class StaffPaymentsScreen extends StatefulWidget {
  final Map<String, dynamic>? staff;

  const StaffPaymentsScreen({super.key, this.staff});

  @override
  _StaffPaymentsScreenState createState() => _StaffPaymentsScreenState();
}

class _StaffPaymentsScreenState extends State<StaffPaymentsScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _announcements = [];
  bool _isLoading = true;
  bool _isLoadingAnnouncements = true;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadPaymentsFromFirestore();
    _loadAnnouncementsFromFirestore();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentsFromFirestore() async {
    if (widget.staff == null) {
      setState(() => _isLoading = false);
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final staffFirestoreId = widget.staff!['firestoreId'];
      if (staffFirestoreId == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      final snapshot = await FirebaseFirestore.instance
          .collection('staff_payments')
          .where('staffFirestoreId', isEqualTo: staffFirestoreId)
          .get();
      
      _payments = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'month': data['month'] ?? '',
          'year': data['year'] ?? DateTime.now().year,
          'netSalary': (data['netSalary'] as num?)?.toDouble() ?? 0,
          'paymentMethod': data['paymentMethod'] ?? '',
          'paymentDate': data['paymentDate'] != null 
              ? (data['paymentDate'] as Timestamp).toDate().toIso8601String()
              : '',
          'bonus': (data['bonus'] as num?)?.toDouble() ?? 0,
          'deduction': (data['deduction'] as num?)?.toDouble() ?? 0,
          'baseSalary': (data['baseSalary'] as num?)?.toDouble() ?? 0,
        };
      }).toList();
      
      _payments.sort((a, b) => b['paymentDate'].compareTo(a['paymentDate']));
      
      _animationController.forward(from: 0);
      
      print('✅ ${_payments.length} paiements chargés');
    } catch (e) {
      print('❌ Erreur chargement paiements: $e');
      _showSnackBar("Erreur de chargement", _AppColors.danger);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAnnouncementsFromFirestore() async {
    setState(() => _isLoadingAnnouncements = true);
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      Query query = FirebaseFirestore.instance.collection('announcements');
      
      if (!auth.isSuperAdmin && schoolId != null) {
        query = query.where('schoolId', isEqualTo: schoolId);
      }
      
      final snapshot = await query.orderBy('date', descending: true).limit(5).get();
      
      _announcements = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'title': data['title'] ?? '',
          'content': data['content'] ?? '',
          'date': data['date'] != null 
              ? (data['date'] as Timestamp).toDate().toIso8601String()
              : DateTime.now().toIso8601String(),
        };
      }).toList();
      
      print('✅ ${_announcements.length} annonces chargées');
    } catch (e) {
      print('❌ Erreur chargement annonces: $e');
    } finally {
      setState(() => _isLoadingAnnouncements = false);
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

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return 'Non payé';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatAnnouncementDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays > 7) return DateFormat('dd/MM/yyyy').format(date);
      if (diff.inDays > 0) return 'il y a ${diff.inDays} j';
      if (diff.inHours > 0) return 'il y a ${diff.inHours} h';
      return 'maintenant';
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.staff == null) {
      return Scaffold(
        backgroundColor: _AppColors.background,
        appBar: AppBar(
          elevation: 0,
          title: const Text(
            'Paiements du personnel',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19, letterSpacing: 0.2),
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_AppColors.primary, _AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _AppColors.primary.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.payment_rounded, size: 56, color: _AppColors.primary.withOpacity(0.4)),
              ),
              const SizedBox(height: 20),
              Text(
                'Sélectionnez un employé',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _AppColors.textDark),
              ),
              const SizedBox(height: 8),
              Text(
                'pour voir ses paiements',
                style: TextStyle(fontSize: 13, color: _AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _AppColors.background,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Paiements - ${widget.staff!['fullName']}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 19, letterSpacing: 0.2),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_AppColors.primary, _AppColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Ajouter paiement',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddStaffPaymentScreen(staff: widget.staff!)),
              );
              if (result == true) await _loadPaymentsFromFirestore();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
            onPressed: () async {
              await _loadPaymentsFromFirestore();
              await _loadAnnouncementsFromFirestore();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 16),
            
            // Carte d'information du personnel
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        (widget.staff!['fullName'] as String).isNotEmpty 
                            ? (widget.staff!['fullName'] as String)[0].toUpperCase() 
                            : '?',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.staff!['fullName'],
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.staff!['position'] ?? 'Personnel',
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Salaire: ${(widget.staff!['salary'] ?? 0).toStringAsFixed(0)} USD/mois',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Section Annonces Admin
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _AppColors.danger,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Annonces récentes",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _AppColors.textDark),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminAnnouncements()),
                      );
                    },
                    style: TextButton.styleFrom(foregroundColor: _AppColors.primary),
                    child: const Text('Voir tout'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            if (_isLoadingAnnouncements)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_announcements.isEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _AppColors.cardBorder),
                ),
                child: Center(
                  child: Text(
                    'Aucune annonce récente',
                    style: TextStyle(color: _AppColors.textMuted, fontSize: 13),
                  ),
                ),
              )
            else
              ..._announcements.map((announcement) => Container(
                margin: const EdgeInsets.only(bottom: 10, left: 16, right: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _AppColors.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _AppColors.danger.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.campaign_rounded, color: _AppColors.danger, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            announcement['title'],
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: _AppColors.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            announcement['content'],
                            style: TextStyle(fontSize: 11, color: _AppColors.textMuted),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatAnnouncementDate(announcement['date']),
                      style: TextStyle(fontSize: 10, color: _AppColors.textMuted),
                    ),
                  ],
                ),
              )).toList(),

            const SizedBox(height: 20),

            // Section Paiements
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _AppColors.success,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Historique des paiements",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _AppColors.textDark),
                  ),
                  const Spacer(),
                  Text(
                    '${_payments.length} paiement(s)',
                    style: TextStyle(fontSize: 12, color: _AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Liste des paiements
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_payments.isEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _AppColors.cardBorder),
                ),
                child: Column(
                  children: [
                    Icon(Icons.payment_rounded, size: 48, color: _AppColors.textMuted.withOpacity(0.5)),
                    const SizedBox(height: 12),
                    Text(
                      'Aucun paiement enregistré',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _AppColors.textMuted),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => AddStaffPaymentScreen(staff: widget.staff!)),
                        );
                        if (result == true) await _loadPaymentsFromFirestore();
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Ajouter un paiement'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _AppColors.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _payments.length,
                itemBuilder: (context, index) {
                  final payment = _payments[index];
                  return FadeTransition(
                    opacity: _animationController,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _AppColors.cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: _AppColors.success.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.payment_rounded, color: _AppColors.success, size: 26),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${payment['month']} ${payment['year']}',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: _AppColors.textDark),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Net: ${(payment['netSalary'] as double).toStringAsFixed(0)} USD • ${payment['paymentMethod']}',
                                    style: TextStyle(fontSize: 12, color: _AppColors.textMuted),
                                  ),
                                  if ((payment['bonus'] as double) > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Row(
                                        children: [
                                          Icon(Icons.add_circle_rounded, size: 12, color: _AppColors.success),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Prime: +${(payment['bonus'] as double).toStringAsFixed(0)} USD',
                                            style: TextStyle(fontSize: 11, color: _AppColors.success),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if ((payment['deduction'] as double) > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Row(
                                        children: [
                                          Icon(Icons.remove_circle_rounded, size: 12, color: _AppColors.danger),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Déduction: -${(payment['deduction'] as double).toStringAsFixed(0)} USD',
                                            style: TextStyle(fontSize: 11, color: _AppColors.danger),
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today_rounded, size: 10, color: _AppColors.textMuted),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatDate(payment['paymentDate']),
                                        style: TextStyle(fontSize: 10, color: _AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _AppColors.success.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Payé',
                                style: TextStyle(color: _AppColors.success, fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}