// lib/models/receipt_model.dart

import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

@HiveType(typeId: 95)
class ReceiptModel {
  @HiveField(0)
  String? id;
  
  @HiveField(1)
  String receiptNumber; // Numéro unique du reçu
  
  @HiveField(2)
  String paymentId; // ID du paiement associé
  
  @HiveField(3)
  String studentName;
  
  @HiveField(4)
  String className;
  
  @HiveField(5)
  String? sectionName;
  
  @HiveField(6)
  String feeType;
  
  @HiveField(7)
  String period; // Mois ou semestre
  
  @HiveField(8)
  int year;
  
  @HiveField(9)
  double amount;
  
  @HiveField(10)
  DateTime paymentDate;
  
  @HiveField(11)
  String schoolName;
  
  @HiveField(12)
  String? schoolAddress;
  
  @HiveField(13)
  String? schoolPhone;
  
  @HiveField(14)
  String? schoolEmail;
  
  @HiveField(15)
  String schoolId;
  
  @HiveField(16)
  String? firestoreId;
  
  @HiveField(17)
  DateTime? generatedAt;

  ReceiptModel({
    this.id,
    required this.receiptNumber,
    required this.paymentId,
    required this.studentName,
    required this.className,
    this.sectionName,
    required this.feeType,
    required this.period,
    required this.year,
    required this.amount,
    required this.paymentDate,
    required this.schoolName,
    this.schoolAddress,
    this.schoolPhone,
    this.schoolEmail,
    required this.schoolId,
    this.firestoreId,
    this.generatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'receiptNumber': receiptNumber,
      'paymentId': paymentId,
      'studentName': studentName,
      'className': className,
      'sectionName': sectionName,
      'feeType': feeType,
      'period': period,
      'year': year,
      'amount': amount,
      'paymentDate': paymentDate.toIso8601String(),
      'schoolName': schoolName,
      'schoolAddress': schoolAddress,
      'schoolPhone': schoolPhone,
      'schoolEmail': schoolEmail,
      'schoolId': schoolId,
      'firestoreId': firestoreId,
      'generatedAt': generatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'receiptNumber': receiptNumber,
      'paymentId': paymentId,
      'studentName': studentName,
      'className': className,
      'sectionName': sectionName,
      'feeType': feeType,
      'period': period,
      'year': year,
      'amount': amount,
      'paymentDate': paymentDate.toIso8601String(),
      'schoolName': schoolName,
      'schoolAddress': schoolAddress,
      'schoolPhone': schoolPhone,
      'schoolEmail': schoolEmail,
      'schoolId': schoolId,
      'generatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory ReceiptModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return ReceiptModel(
      receiptNumber: data['receiptNumber'] ?? '',
      paymentId: data['paymentId'] ?? '',
      studentName: data['studentName'] ?? '',
      className: data['className'] ?? '',
      sectionName: data['sectionName'],
      feeType: data['feeType'] ?? '',
      period: data['period'] ?? '',
      year: data['year'] ?? DateTime.now().year,
      amount: (data['amount'] ?? 0.0).toDouble(),
      paymentDate: data['paymentDate'] != null 
          ? DateTime.parse(data['paymentDate']) 
          : DateTime.now(),
      schoolName: data['schoolName'] ?? '',
      schoolAddress: data['schoolAddress'],
      schoolPhone: data['schoolPhone'],
      schoolEmail: data['schoolEmail'],
      schoolId: data['schoolId'] ?? '',
      firestoreId: docId,
      generatedAt: data['generatedAt'] != null 
          ? (data['generatedAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }
}