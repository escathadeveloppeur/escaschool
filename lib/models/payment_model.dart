// lib/models/payment_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:flutter/material.dart'; // ✅ AJOUTÉ pour Colors

part 'payment_model.g.dart'; // généré par build_runner

@HiveType(typeId: 3) // chaque modèle Hive doit avoir un typeId unique
class PaymentModel extends HiveObject {
  @HiveField(0)
  int studentKeyHive;

  @HiveField(1)
  int month;

  @HiveField(2)
  String feeType;

  @HiveField(3)
  double amount;

  @HiveField(4)
  String paymentDate;

  @HiveField(5)
  String fullName;

  @HiveField(6)
  String className;
  
  @HiveField(7)
  int year;
  
  @HiveField(8)
  int schoolId;

  @HiveField(9)
  String? firestoreId;

  @HiveField(10)
  String status;

  // ===============================================================
  // NOUVEAUX CHAMPS POUR LA STRUCTURE HIÉRARCHIQUE
  // ===============================================================
  
  @HiveField(11)
  String? schoolFirestoreId; // ID Firestore de l'école
  
  @HiveField(12)
  String? classId; // ID Firestore de la classe
  
  @HiveField(13)
  String? studentId; // ID Firestore de l'étudiant
  
  @HiveField(14)
  String? paymentFirestoreId; // ID Firestore du paiement (alias)
  
  @HiveField(15)
  String? localKey; // Clé locale pour la synchronisation
  
  @HiveField(16)
  String? paymentMethod; // Mode de paiement (cash, virement, etc.)
  
  @HiveField(17)
  String? transactionId; // ID de transaction
  

  PaymentModel({
    required this.studentKeyHive,
    required this.month,
    required this.feeType,
    required this.amount,
    required this.paymentDate,
    required this.fullName,
    required this.className,
    required this.year,
    required this.schoolId,
    this.firestoreId,
    this.status = 'pending',
    this.schoolFirestoreId,
    this.classId,
    this.studentId,
    this.paymentFirestoreId,
    this.localKey,
    this.paymentMethod,
    this.transactionId,
  });

  // ===============================================================
  // CONSTRUCTEUR DEPUIS FIRESTORE
  // ===============================================================

  /// Créer une instance depuis Firestore
  factory PaymentModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return PaymentModel(
      studentKeyHive: data['studentKeyHive'] ?? 0,
      month: data['month'] is int 
          ? data['month'] 
          : int.tryParse(data['month'].toString()) ?? 0,
      feeType: data['feeType'] ?? '',
      amount: data['amount'] is double 
          ? data['amount'] 
          : double.tryParse(data['amount'].toString()) ?? 0.0,
      paymentDate: data['paymentDate'] ?? DateTime.now().toIso8601String(),
      fullName: data['fullName'] ?? '',
      className: data['className'] ?? '',
      year: data['year'] is int 
          ? data['year'] 
          : int.tryParse(data['year'].toString()) ?? DateTime.now().year,
      schoolId: data['schoolId'] ?? 0,
      firestoreId: docId,
      status: data['status'] ?? 'pending',
      // Nouveaux champs
      schoolFirestoreId: data['schoolFirestoreId'],
      classId: data['classId'],
      studentId: data['studentId'],
      paymentFirestoreId: docId,
      localKey: data['localKey'] ?? data['studentKeyHive']?.toString(),
      paymentMethod: data['paymentMethod'],
      transactionId: data['transactionId'],
    );
  }

  // ===============================================================
  // CONVERSION POUR FIRESTORE
  // ===============================================================

  /// Convertir en Map pour Firestore
  Map<String, dynamic> toFirestoreMap() {
    return {
      'studentKeyHive': studentKeyHive,
      'month': month,
      'feeType': feeType,
      'amount': amount,
      'paymentDate': paymentDate,
      'fullName': fullName,
      'className': className,
      'classId': classId,
      'year': year,
      'schoolId': schoolId,
      'schoolFirestoreId': schoolFirestoreId,
      'studentId': studentId,
      'status': status,
      'localKey': localKey ?? studentKeyHive.toString(),
      'paymentMethod': paymentMethod,
      'transactionId': transactionId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // ===============================================================
  // CONVERSION POUR HIVE (LOCAL)
  // ===============================================================

  /// Convertir en Map pour Hive
  Map<String, dynamic> toMap() {
    return {
      'studentKeyHive': studentKeyHive,
      'month': month,
      'feeType': feeType,
      'amount': amount,
      'paymentDate': paymentDate,
      'fullName': fullName,
      'className': className,
      'year': year,
      'schoolId': schoolId,
      'firestoreId': firestoreId,
      'status': status,
      'schoolFirestoreId': schoolFirestoreId,
      'classId': classId,
      'studentId': studentId,
      'paymentFirestoreId': paymentFirestoreId,
      'localKey': localKey,
      'paymentMethod': paymentMethod,
      'transactionId': transactionId,
    };
  }

  /// Créer une instance depuis Hive
  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      studentKeyHive: map['studentKeyHive'] ?? 0,
      month: map['month'] ?? 0,
      feeType: map['feeType'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      paymentDate: map['paymentDate'] ?? '',
      fullName: map['fullName'] ?? '',
      className: map['className'] ?? '',
      year: map['year'] ?? DateTime.now().year,
      schoolId: map['schoolId'] ?? 0,
      firestoreId: map['firestoreId'],
      status: map['status'] ?? 'pending',
      schoolFirestoreId: map['schoolFirestoreId'],
      classId: map['classId'],
      studentId: map['studentId'],
      paymentFirestoreId: map['paymentFirestoreId'],
      localKey: map['localKey'],
      paymentMethod: map['paymentMethod'],
      transactionId: map['transactionId'],
    );
  }

  // ===============================================================
  // MÉTHODES UTILITAIRES
  // ===============================================================

  /// Vérifie si le paiement a un ID Firestore
  bool get hasFirestoreId => paymentFirestoreId != null && paymentFirestoreId!.isNotEmpty;
  
  /// Vérifie si le paiement est validé
  bool get isPaid => status == 'paid';
  
  /// Vérifie si le paiement est en attente
  bool get isPending => status == 'pending';
  
  /// Vérifie si le paiement est annulé
  bool get isCancelled => status == 'cancelled';
  
  /// Retourne le libellé du statut
  String get statusLabel {
    switch (status) {
      case 'paid': return '✅ Payé';
      case 'pending': return '⏳ En attente';
      case 'cancelled': return '❌ Annulé';
      default: return status;
    }
  }
  
  /// Retourne la couleur du statut
  Color get statusColor {
    switch (status) {
      case 'paid': return Colors.green;
      case 'pending': return Colors.orange;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  /// Retourne le libellé du mois en français
  String get monthLabel {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return month.toString();
  }

  /// Retourne le libellé du type de frais
  String get feeTypeLabel {
    switch (feeType) {
      case 'scolarite': return '🏫 Scolarité';
      case 'inscription': return '📝 Inscription';
      case 'transport': return '🚌 Transport';
      case 'cantine': return '🍽️ Cantine';
      case 'uniforme': return '👔 Uniforme';
      case 'livres': return '📚 Livres';
      case 'activite': return '🎯 Activités';
      default: return feeType;
    }
  }

  /// Retourne une copie avec des champs modifiés
  PaymentModel copyWith({
    int? studentKeyHive,
    int? month,
    String? feeType,
    double? amount,
    String? paymentDate,
    String? fullName,
    String? className,
    int? year,
    int? schoolId,
    String? firestoreId,
    String? status,
    String? schoolFirestoreId,
    String? classId,
    String? studentId,
    String? paymentFirestoreId,
    String? localKey,
    String? paymentMethod,
    String? transactionId,
  }) {
    return PaymentModel(
      studentKeyHive: studentKeyHive ?? this.studentKeyHive,
      month: month ?? this.month,
      feeType: feeType ?? this.feeType,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      fullName: fullName ?? this.fullName,
      className: className ?? this.className,
      year: year ?? this.year,
      schoolId: schoolId ?? this.schoolId,
      firestoreId: firestoreId ?? this.firestoreId,
      status: status ?? this.status,
      schoolFirestoreId: schoolFirestoreId ?? this.schoolFirestoreId,
      classId: classId ?? this.classId,
      studentId: studentId ?? this.studentId,
      paymentFirestoreId: paymentFirestoreId ?? this.paymentFirestoreId,
      localKey: localKey ?? this.localKey,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionId: transactionId ?? this.transactionId,
    );
  }
}

// ===============================================================
// EXTENSION POUR FACILITER LA MANIPULATION DES PAIEMENTS
// ===============================================================

extension PaymentModelExtension on List<PaymentModel> {
  /// Filtre les paiements par étudiant
  List<PaymentModel> filterByStudent(int studentKeyHive) {
    return where((p) => p.studentKeyHive == studentKeyHive).toList();
  }

  /// Filtre les paiements par étudiant Firestore ID
  List<PaymentModel> filterByStudentId(String studentId) {
    return where((p) => p.studentId == studentId).toList();
  }

  /// Filtre les paiements par classe
  List<PaymentModel> filterByClass(String classId) {
    return where((p) => p.classId == classId).toList();
  }

  /// Filtre les paiements par type de frais
  List<PaymentModel> filterByFeeType(String feeType) {
    return where((p) => p.feeType == feeType).toList();
  }

  /// Filtre les paiements par mois
  List<PaymentModel> filterByMonth(int month) {
    return where((p) => p.month == month).toList();
  }

  /// Filtre les paiements par année
  List<PaymentModel> filterByYear(int year) {
    return where((p) => p.year == year).toList();
  }

  /// Filtre les paiements par statut
  List<PaymentModel> filterByStatus(String status) {
    return where((p) => p.status == status).toList();
  }

  /// Filtre les paiements payés
  List<PaymentModel> getPaid() {
    return where((p) => p.isPaid).toList();
  }

  /// Filtre les paiements en attente
  List<PaymentModel> getPending() {
    return where((p) => p.isPending).toList();
  }

  /// Filtre les paiements annulés
  List<PaymentModel> getCancelled() {
    return where((p) => p.isCancelled).toList();
  }

  /// Filtre les paiements par école
  List<PaymentModel> filterBySchool(String schoolFirestoreId) {
    return where((p) => p.schoolFirestoreId == schoolFirestoreId).toList();
  }

  /// Filtre les paiements par nom d'étudiant
  List<PaymentModel> filterByStudentName(String query) {
    if (query.isEmpty) return this;
    return where((p) => 
      p.fullName.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }

  /// Groupe les paiements par type de frais
  Map<String, List<PaymentModel>> groupByFeeType() {
    final Map<String, List<PaymentModel>> result = {};
    for (var p in this) {
      if (!result.containsKey(p.feeType)) {
        result[p.feeType] = [];
      }
      result[p.feeType]!.add(p);
    }
    return result;
  }

  /// Groupe les paiements par mois
  Map<int, List<PaymentModel>> groupByMonth() {
    final Map<int, List<PaymentModel>> result = {};
    for (var p in this) {
      if (!result.containsKey(p.month)) {
        result[p.month] = [];
      }
      result[p.month]!.add(p);
    }
    return result;
  }

  /// Groupe les paiements par statut
  Map<String, List<PaymentModel>> groupByStatus() {
    return {
      'paid': getPaid(),
      'pending': getPending(),
      'cancelled': getCancelled(),
    };
  }

  /// Calcule le total des paiements
  double getTotal() {
    return fold(0.0, (sum, p) => sum + p.amount);
  }

  /// Calcule le total par type de frais
  Map<String, double> getTotalByFeeType() {
    final Map<String, double> result = {};
    for (var p in this) {
      result[p.feeType] = (result[p.feeType] ?? 0.0) + p.amount;
    }
    return result;
  }

  /// Calcule le total par mois
  Map<int, double> getTotalByMonth() {
    final Map<int, double> result = {};
    for (var p in this) {
      result[p.month] = (result[p.month] ?? 0.0) + p.amount;
    }
    return result;
  }

  /// Calcule le total par année
  Map<int, double> getTotalByYear() {
    final Map<int, double> result = {};
    for (var p in this) {
      result[p.year] = (result[p.year] ?? 0.0) + p.amount;
    }
    return result;
  }

  /// Récupère les statistiques des paiements
  Map<String, dynamic> getStatistics() {
    return {
      'total': length,
      'totalAmount': getTotal(),
      'paid': getPaid().length,
      'pending': getPending().length,
      'cancelled': getCancelled().length,
      'byFeeType': groupByFeeType().map((key, value) => MapEntry(key, value.length)),
      'byMonth': groupByMonth().map((key, value) => MapEntry(key, value.length)),
      'totalByFeeType': getTotalByFeeType(),
      'totalByMonth': getTotalByMonth(),
    };
  }

  /// Récupère les paiements non synchronisés
  List<PaymentModel> getUnsynced() {
    return where((p) => !p.hasFirestoreId).toList();
  }

  /// Trie les paiements par date (plus récents en premier)
  List<PaymentModel> sortedByDateDesc() {
    final list = [...this];
    list.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
    return list;
  }

  /// Trie les paiements par montant (plus élevé en premier)
  List<PaymentModel> sortedByAmountDesc() {
    final list = [...this];
    list.sort((a, b) => b.amount.compareTo(a.amount));
    return list;
  }

  /// Trie les paiements par nom d'étudiant
  List<PaymentModel> sortedByName() {
    final list = [...this];
    list.sort((a, b) => a.fullName.compareTo(b.fullName));
    return list;
  }
}