// lib/services/payment_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'db_helper.dart';
import '../models/payment_model.dart';

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DBHelper _dbHelper = DBHelper();

  Future<String> createPayment(PaymentModel payment, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final docRef = _firestore.collection('payments').doc();
      final paymentData = {
        'studentKeyHive': payment.studentKeyHive,
        'month': payment.month,
        'feeType': payment.feeType,
        'amount': payment.amount,
        'paymentDate': payment.paymentDate,
        'fullName': payment.fullName,
        'className': payment.className,
        'year': payment.year,
        'schoolId': schoolId,
        'localKey': payment.key,
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(paymentData);
      print('✅ Paiement créé dans Firestore: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Erreur création paiement Firestore: $e');
      throw e;
    }
  }

  Future<void> syncAllPaymentsToFirestore(String schoolId) async {
    try {
      print('🔄 Synchronisation des paiements vers Firestore...');
      final payments = await _dbHelper.getAllPayments();
      
      for (var payment in payments) {
        final existing = await _firestore
            .collection('payments')
            .where('localKey', isEqualTo: payment.key)
            .get();

        if (existing.docs.isEmpty) {
          await createPayment(payment, schoolId);
        }
      }

      print('✅ Synchronisation des paiements terminée: ${payments.length}');
    } catch (e) {
      print('❌ Erreur synchronisation paiements: $e');
      throw e;
    }
  }

  Future<void> syncPaymentsFromFirestore(String schoolId) async {
    try {
      print('📥 Synchronisation des paiements depuis Firestore...');
      final snapshot = await _firestore
          .collection('payments')
          .where('schoolId', isEqualTo: schoolId)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final payment = PaymentModel(
          studentKeyHive: data['studentKeyHive'] ?? 0,
          month: data['month'] ?? '',
          feeType: data['feeType'] ?? '',
          amount: (data['amount'] ?? 0).toDouble(),
          paymentDate: data['paymentDate'] ?? '',
          fullName: data['fullName'] ?? '',
          className: data['className'] ?? '',
          year: data['year'] ?? 0,
          schoolId: data['schoolId'] ?? 0,
        );
        
        final existing = await _dbHelper.getPaymentByKey(payment.key);
        if (existing == null) {
          await _dbHelper.addPayment(payment);
        }
      }

      print('✅ Synchronisation des paiements depuis Firestore terminée: ${snapshot.docs.length}');
    } catch (e) {
      print('❌ Erreur synchronisation paiements depuis Firestore: $e');
    }
  }
}