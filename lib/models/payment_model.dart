// lib/models/payment_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:hive/hive.dart';

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
  });
  
  // Constructeur depuis Firestore
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
    );
  }
  
  // Convertir en Map pour Firestore
  Map<String, dynamic> toFirestore() {
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
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Convertir en Map pour Hive
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
    };
  }

  // Constructeur depuis Map
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
    );
  }
}