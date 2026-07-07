// lib/services/payment_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'db_helper.dart';
import '../models/payment_model.dart';

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DBHelper _dbHelper = DBHelper();

  // ==================== CRUD PAIEMENTS ====================

  /// ✅ Créer un paiement dans Firestore (sous-collection de l'école)
  Future<String> createPayment(PaymentModel payment, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      // 🔥 Utiliser une sous-collection de l'école
      final docRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('payments')
          .doc();

      // 🔥 Utiliser toFirestoreMap() du modèle
      final paymentData = payment.toFirestoreMap();
      
      // Ajouter les champs spécifiques au service
      paymentData.addAll({
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isSynced': true,
      });

      await docRef.set(paymentData);
      
      // Mettre à jour l'ID Firestore dans le modèle
      payment.paymentFirestoreId = docRef.id;
      
      print('✅ Paiement créé dans Firestore: ${docRef.id}');
      return docRef.id;
      
    } catch (e) {
      print('❌ Erreur création paiement Firestore: $e');
      throw e;
    }
  }

  /// ✅ Mettre à jour un paiement dans Firestore
  Future<void> updatePayment(String schoolId, String paymentId, PaymentModel payment) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      // 🔥 Utiliser toFirestoreMap() du modèle
      final updateData = payment.toFirestoreMap();
      
      // Ajouter les champs de mise à jour
      updateData.addAll({
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      });
      
      // Retirer les champs qui ne doivent pas être mis à jour
      updateData.remove('createdAt');
      updateData.remove('createdBy');

      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('payments')
          .doc(paymentId)
          .update(updateData);
          
      print('✅ Paiement mis à jour dans Firestore: $paymentId');
      
    } catch (e) {
      print('❌ Erreur mise à jour paiement Firestore: $e');
      throw e;
    }
  }

  /// ✅ Supprimer un paiement de Firestore
  Future<void> deletePayment(String schoolId, String paymentId) async {
    try {
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('payments')
          .doc(paymentId)
          .delete();
          
      print('🗑️ Paiement supprimé de Firestore: $paymentId');
      
    } catch (e) {
      print('❌ Erreur suppression paiement Firestore: $e');
      throw e;
    }
  }

  /// ✅ Supprimer tous les paiements d'une école
  Future<void> deleteAllPayments(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('payments')
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('🗑️ Tous les paiements supprimés pour l\'école: $schoolId');
      
    } catch (e) {
      print('❌ Erreur suppression tous les paiements: $e');
      throw e;
    }
  }

  /// ✅ Supprimer les paiements d'un étudiant
  Future<void> deletePaymentsByStudent(String schoolId, String studentId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('payments')
          .where('studentKeyHive', isEqualTo: studentId)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('🗑️ Paiements supprimés pour l\'étudiant: $studentId');
      
    } catch (e) {
      print('❌ Erreur suppression paiements par étudiant: $e');
      throw e;
    }
  }

  /// ✅ Supprimer les paiements d'une classe
  Future<void> deletePaymentsByClass(String schoolId, String classId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('payments')
          .where('classId', isEqualTo: classId)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('🗑️ Paiements supprimés pour la classe: $classId');
      
    } catch (e) {
      print('❌ Erreur suppression paiements par classe: $e');
      throw e;
    }
  }

  // ==================== RÉCUPÉRATION DES PAIEMENTS ====================

  /// ✅ Récupérer tous les paiements d'une école
  Future<List<PaymentModel>> getPaymentsBySchool(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('payments')
          .orderBy('paymentDate', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return PaymentModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération paiements par école: $e');
      return [];
    }
  }

  /// ✅ Récupérer les paiements d'un étudiant
  Future<List<PaymentModel>> getPaymentsByStudent(String schoolId, int studentKeyHive) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('payments')
          .where('studentKeyHive', isEqualTo: studentKeyHive)
          .orderBy('paymentDate', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return PaymentModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération paiements par étudiant: $e');
      return [];
    }
  }

  /// ✅ Récupérer les paiements d'une classe
  Future<List<PaymentModel>> getPaymentsByClass(String schoolId, String classId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('payments')
          .where('classId', isEqualTo: classId)
          .orderBy('paymentDate', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return PaymentModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération paiements par classe: $e');
      return [];
    }
  }

  /// ✅ Récupérer les paiements par type de frais
  Future<List<PaymentModel>> getPaymentsByFeeType(String schoolId, String feeType) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('payments')
          .where('feeType', isEqualTo: feeType)
          .orderBy('paymentDate', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return PaymentModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération paiements par type: $e');
      return [];
    }
  }

  /// ✅ Récupérer les paiements par mois
  Future<List<PaymentModel>> getPaymentsByMonth(String schoolId, String month) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('payments')
          .where('month', isEqualTo: month)
          .orderBy('paymentDate', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return PaymentModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération paiements par mois: $e');
      return [];
    }
  }

  /// ✅ Récupérer les paiements par année
  Future<List<PaymentModel>> getPaymentsByYear(String schoolId, int year) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('payments')
          .where('year', isEqualTo: year)
          .orderBy('paymentDate', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return PaymentModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération paiements par année: $e');
      return [];
    }
  }

  /// ✅ Récupérer un paiement par ID
  Future<PaymentModel?> getPaymentById(String schoolId, String paymentId) async {
    try {
      final doc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('payments')
          .doc(paymentId)
          .get();
      
      if (!doc.exists) return null;
      
      return PaymentModel.fromFirestore(doc.data()!, doc.id);
      
    } catch (e) {
      print('❌ Erreur récupération paiement par ID: $e');
      return null;
    }
  }

  // ==================== ÉCOUTE EN TEMPS RÉEL ====================

  /// ✅ Écouter tous les paiements d'une école en temps réel
  Stream<List<PaymentModel>> listenToPayments(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('payments')
        .orderBy('paymentDate', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return PaymentModel.fromFirestore(doc.data(), doc.id);
          }).toList();
        });
  }

  /// ✅ Écouter les paiements d'un étudiant en temps réel
  Stream<List<PaymentModel>> listenToPaymentsByStudent(String schoolId, int studentKeyHive) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('payments')
        .where('studentKeyHive', isEqualTo: studentKeyHive)
        .orderBy('paymentDate', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return PaymentModel.fromFirestore(doc.data(), doc.id);
          }).toList();
        });
  }

  /// ✅ Écouter les paiements par type en temps réel
  Stream<List<PaymentModel>> listenToPaymentsByFeeType(String schoolId, String feeType) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('payments')
        .where('feeType', isEqualTo: feeType)
        .orderBy('paymentDate', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return PaymentModel.fromFirestore(doc.data(), doc.id);
          }).toList();
        });
  }

  // ==================== SYNCHRONISATION ====================

  /// ✅ Synchroniser tous les paiements locaux vers Firestore
  Future<void> syncAllPaymentsToFirestore(String schoolId) async {
    try {
      print('🔄 Synchronisation des paiements vers Firestore...');
      final payments = await _dbHelper.getAllPayments();
      
      if (payments.isEmpty) {
        print('📭 Aucun paiement à synchroniser');
        return;
      }
      
      int syncedCount = 0;
      
      for (var payment in payments) {
        try {
          final existing = await _firestore
              .collection('schools')
              .doc(schoolId)
              .collection('payments')
              .where('localKey', isEqualTo: payment.key)
              .get();

          if (existing.docs.isEmpty) {
            await createPayment(payment, schoolId);
            syncedCount++;
          } else {
            // Mettre à jour si nécessaire
            final docId = existing.docs.first.id;
            payment.paymentFirestoreId = docId;
            await updatePayment(schoolId, docId, payment);
            syncedCount++;
          }
        } catch (e) {
          print('❌ Erreur synchronisation paiement ${payment.key}: $e');
        }
      }

      print('✅ Synchronisation terminée: $syncedCount/${payments.length} paiements');

    } catch (e) {
      print('❌ Erreur synchronisation paiements: $e');
      throw e;
    }
  }

  /// ✅ Synchroniser les paiements depuis Firestore vers local
  Future<void> syncPaymentsFromFirestore(String schoolId) async {
    try {
      print('📥 Synchronisation des paiements depuis Firestore...');
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('payments')
          .get();

      if (snapshot.docs.isEmpty) {
        print('📭 Aucun paiement à synchroniser depuis Firestore');
        return;
      }

      int addedCount = 0;
      int updatedCount = 0;

      for (var doc in snapshot.docs) {
        try {
          final payment = PaymentModel.fromFirestore(doc.data(), doc.id);
          
          final existing = await _dbHelper.getPaymentByKey(payment.key);
          
          if (existing == null) {
            await _dbHelper.addPayment(payment);
            addedCount++;
          } else {
            // Mettre à jour : supprimer l'ancien et ajouter le nouveau
            await _dbHelper.deletePaymentByKey(payment.key);
            await _dbHelper.addPayment(payment);
            updatedCount++;
          }
        } catch (e) {
          print('  ⚠️ Erreur traitement paiement ${doc.id}: $e');
        }
      }

      print('✅ Synchronisation terminée: +$addedCount ajoutés, $updatedCount mis à jour');

    } catch (e) {
      print('❌ Erreur synchronisation paiements depuis Firestore: $e');
      throw e;
    }
  }

  /// ✅ Synchronisation complète (bidirectionnelle)
  Future<void> syncAllPaymentData(String schoolId) async {
    try {
      print('🔄 Synchronisation complète des paiements...');
      await syncAllPaymentsToFirestore(schoolId);
      await syncPaymentsFromFirestore(schoolId);
      print('✅ Synchronisation complète des paiements terminée');
    } catch (e) {
      print('❌ Erreur synchronisation complète: $e');
      throw e;
    }
  }

  // ==================== STATISTIQUES ====================

  /// ✅ Calculer le total des paiements par type
  Future<Map<String, double>> getTotalByFeeType(String schoolId) async {
    try {
      final Map<String, double> totals = {};
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('payments')
          .get();
      
      for (var doc in snapshot.docs) {
        final feeType = doc['feeType'] ?? 'other';
        final amount = (doc['amount'] ?? 0.0).toDouble();
        totals[feeType] = (totals[feeType] ?? 0.0) + amount;
      }
      
      return totals;
      
    } catch (e) {
      print('❌ Erreur calcul total par type: $e');
      return {};
    }
  }

  /// ✅ Calculer le total des paiements par mois
  Future<Map<String, double>> getTotalByMonth(String schoolId) async {
    try {
      final Map<String, double> totals = {};
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('payments')
          .get();
      
      for (var doc in snapshot.docs) {
        final month = doc['month'] ?? 'unknown';
        final amount = (doc['amount'] ?? 0.0).toDouble();
        totals[month] = (totals[month] ?? 0.0) + amount;
      }
      
      return totals;
      
    } catch (e) {
      print('❌ Erreur calcul total par mois: $e');
      return {};
    }
  }

  /// ✅ Calculer le total des paiements par année
  Future<Map<int, double>> getTotalByYear(String schoolId) async {
    try {
      final Map<int, double> totals = {};
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('payments')
          .get();
      
      for (var doc in snapshot.docs) {
        final year = doc['year'] ?? 0;
        final amount = (doc['amount'] ?? 0.0).toDouble();
        totals[year] = (totals[year] ?? 0.0) + amount;
      }
      
      return totals;
      
    } catch (e) {
      print('❌ Erreur calcul total par année: $e');
      return {};
    }
  }

  /// ✅ Compter les paiements par type
  Future<Map<String, int>> countPaymentsByFeeType(String schoolId) async {
    try {
      final Map<String, int> counts = {};
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('payments')
          .get();
      
      for (var doc in snapshot.docs) {
        final feeType = doc['feeType'] ?? 'other';
        counts[feeType] = (counts[feeType] ?? 0) + 1;
      }
      
      return counts;
      
    } catch (e) {
      print('❌ Erreur comptage paiements par type: $e');
      return {};
    }
  }

  /// ✅ Obtenir les statistiques complètes
  Future<Map<String, dynamic>> getPaymentStats(String schoolId) async {
    try {
      final byFeeType = await getTotalByFeeType(schoolId);
      final byMonth = await getTotalByMonth(schoolId);
      final byYear = await getTotalByYear(schoolId);
      final countByFeeType = await countPaymentsByFeeType(schoolId);
      
      double totalGeneral = 0;
      byFeeType.forEach((key, value) => totalGeneral += value);
      
      // Compter le nombre total de paiements
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('payments')
          .get();
      
      return {
        'totalAmount': totalGeneral,
        'totalPayments': snapshot.docs.length,
        'byFeeType': byFeeType,
        'byMonth': byMonth,
        'byYear': byYear,
        'countByFeeType': countByFeeType,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      
    } catch (e) {
      print('❌ Erreur statistiques paiements: $e');
      return {};
    }
  }

  /// ✅ Écouter les statistiques en temps réel
  Stream<Map<String, dynamic>> listenToPaymentStats(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('payments')
        .snapshots()
        .map((snapshot) {
          final Map<String, double> byFeeType = {};
          final Map<String, double> byMonth = {};
          final Map<String, int> countByFeeType = {};
          
          double totalGeneral = 0;
          
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final feeType = data['feeType'] ?? 'other';
            final month = data['month'] ?? 'unknown';
            final amount = (data['amount'] ?? 0.0).toDouble();
            
            totalGeneral += amount;
            byFeeType[feeType] = (byFeeType[feeType] ?? 0.0) + amount;
            byMonth[month] = (byMonth[month] ?? 0.0) + amount;
            countByFeeType[feeType] = (countByFeeType[feeType] ?? 0) + 1;
          }
          
          return {
            'totalAmount': totalGeneral,
            'totalPayments': snapshot.docs.length,
            'byFeeType': byFeeType,
            'byMonth': byMonth,
            'countByFeeType': countByFeeType,
            'lastUpdated': DateTime.now().toIso8601String(),
          };
        });
  }

  // ==================== RECHERCHE ====================

  /// ✅ Rechercher des paiements par nom d'étudiant
  Future<List<PaymentModel>> searchPaymentsByStudentName(String schoolId, String query) async {
    try {
      if (query.isEmpty) return [];
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('payments')
          .where('fullName', isGreaterThanOrEqualTo: query)
          .where('fullName', isLessThanOrEqualTo: query + '\uf8ff')
          .orderBy('paymentDate', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return PaymentModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur recherche paiements: $e');
      return [];
    }
  }

  /// ✅ Vérifier si un paiement existe pour un étudiant
  Future<bool> paymentExistsForStudent(String schoolId, int studentKeyHive, String month) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('payments')
          .where('studentKeyHive', isEqualTo: studentKeyHive)
          .where('month', isEqualTo: month)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;

    } catch (e) {
      print('❌ Erreur vérification paiement: $e');
      return false;
    }
  }
}