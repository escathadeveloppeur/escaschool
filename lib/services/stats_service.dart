// lib/services/stats_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'db_helper.dart';

class StatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DBHelper _dbHelper = DBHelper();

  // ==================== STATISTIQUES GLOBALES ====================

  Future<Map<String, dynamic>> getGlobalStats() async {
    final users = await _dbHelper.getAllUsers();
    final students = await _dbHelper.getAllStudents();
    final schools = await _dbHelper.getAllEtablissements();
    final payments = await _dbHelper.getAllPayments();
    final documents = await _dbHelper.getAllDocuments();
    
    return {
      'totalUsers': users.length,
      'totalStudents': students.length,
      'totalSchools': schools.length,
      'totalPayments': payments.length,
      'totalDocuments': documents.length,
      'activeSchools': schools.where((s) => s.isActive).length,
      'suspendedSchools': schools.where((s) => !s.isActive).length,
      'pendingPayments': payments.where((p) => p.paymentDate.isEmpty).length,
      'totalRevenue': payments.fold<double>(0, (sum, p) => sum + p.amount),
    };
  }

  Future<Map<String, dynamic>> getSchoolStats(int schoolId) async {
    final users = await _dbHelper.getAllUsers();
    final students = await _dbHelper.getAllStudents();
    final payments = await _dbHelper.getAllPayments();
    
    final schoolUsers = users.where((u) => u['schoolId'] == schoolId).toList();
    final schoolStudents = students.where((s) => s.schoolId == schoolId).toList();
    final schoolPayments = payments.where((p) => p.schoolId == schoolId).toList();
    
    return {
      'totalUsers': schoolUsers.length,
      'totalStudents': schoolStudents.length,
      'totalTeachers': schoolUsers.where((u) => u['role'] == 'teacher').length,
      'totalAdmins': schoolUsers.where((u) => u['role'] == 'admin').length,
      'totalStaff': schoolUsers.where((u) => u['role'] == 'staff').length,
      'totalPayments': schoolPayments.length,
      'totalRevenue': schoolPayments.fold<double>(0, (sum, p) => sum + p.amount),
      'pendingPayments': schoolPayments.where((p) => p.paymentDate.isEmpty).length,
    };
  }

  // ==================== LOGS SYSTÈME ====================

  Future<void> addSystemLog({
    required String action,
    required String description,
    required String level, // 'info', 'warning', 'error'
    String? schoolId,
    int? userId,
    Map<String, dynamic>? metadata,
  }) async {
    final log = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'action': action,
      'description': description,
      'level': level,
      'schoolId': schoolId,
      'userId': userId,
      'metadata': metadata,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    await _dbHelper.addSystemLog(log);
    
    // Synchronisation Firebase
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('system_logs').add({
        ...log,
        'createdBy': user.uid,
        'firestoreTimestamp': FieldValue.serverTimestamp(),
      });
    }
    
    print('📝 Log ajouté: $action - $description');
  }

  Future<List<Map<String, dynamic>>> getSystemLogs({
    String? level,
    int? schoolId,
    int? limit = 100,
  }) async {
    var logs = await _dbHelper.getSystemLogs();
    
    if (level != null) {
      logs = logs.where((l) => l['level'] == level).toList();
    }
    if (schoolId != null) {
      logs = logs.where((l) => l['schoolId'] == schoolId).toList();
    }
    
    logs.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
    
    if (limit != null && limit < logs.length) {
      logs = logs.sublist(0, limit);
    }
    
    return logs;
  }

  // ==================== GESTION DES PAIEMENTS DES ÉCOLES ====================

  Future<void> recordSchoolPayment({
    required String schoolId,
    required double amount,
    required String month,
    required int year,
    required String paymentMethod,
    String? reference,
  }) async {
    try {
      final payment = {
        'schoolId': schoolId,
        'amount': amount,
        'month': month,
        'year': year,
        'paymentMethod': paymentMethod,
        'reference': reference,
        'paymentDate': DateTime.now().toIso8601String(),
        'status': 'paid',
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      await _dbHelper.addSchoolPayment(payment);
      
      await addSystemLog(
        action: 'school_payment',
        description: 'Paiement enregistré pour l\'école ID $schoolId - $amount FCFA',
        level: 'info',
        schoolId: schoolId,
        metadata: payment,
      );
      
      // Synchronisation Firebase
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('school_payments').add({
          ...payment,
          'createdBy': user.uid,
          'firestoreTimestamp': FieldValue.serverTimestamp(),
        });
      }
      
    } catch (e) {
      print('Erreur enregistrement paiement: $e');
      throw e;
    }
  }

  Future<List<Map<String, dynamic>>> getSchoolPayments({
    int? schoolId,
    int? year,
    bool? isPaid,
  }) async {
    var payments = await _dbHelper.getSchoolPayments();
    
    if (schoolId != null) {
      payments = payments.where((p) => p['schoolId'] == schoolId).toList();
    }
    if (year != null) {
      payments = payments.where((p) => p['year'] == year).toList();
    }
    if (isPaid != null) {
      payments = payments.where((p) => (p['status'] == 'paid') == isPaid).toList();
    }
    
    payments.sort((a, b) => b['paymentDate'].compareTo(a['paymentDate']));
    
    return payments;
  }

  Future<Map<String, dynamic>> getSchoolPaymentSummary(int schoolId) async {
    final payments = await getSchoolPayments(schoolId: schoolId);
    final school = await _dbHelper.getEtablissementById(schoolId);
    
    final totalPaid = payments.fold<double>(0, (sum, p) => sum + (p['amount'] as double));
    final monthlyFee = 50000.0; // Frais mensuels par défaut (converti en double)
    final currentYear = DateTime.now().year;
    final currentMonth = DateTime.now().month;
    
    final expectedTotal = monthlyFee * currentMonth;
    final balance = expectedTotal - totalPaid; // Correction: enlever 'const'
    
    return {
      'schoolName': school?.nom ?? 'Inconnu',
      'schoolId': schoolId,
      'totalPaid': totalPaid,
      'expectedTotal': expectedTotal.toDouble(),
      'balance': balance,
      'monthlyFee': monthlyFee,
      'paymentsCount': payments.length,
      'lastPaymentDate': payments.isNotEmpty ? payments.first['paymentDate'] : null,
    };
  }
}