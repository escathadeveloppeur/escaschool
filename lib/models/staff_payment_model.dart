// lib/models/staff_payment_model.dart

import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

part 'staff_payment_model.g.dart';


@HiveType(typeId: 80)
class StaffPaymentModel extends HiveObject {
  @HiveField(0)
  int? id;
  
  @HiveField(1)
  int staffId;
  
  @HiveField(2)
  String staffName;
  
  @HiveField(3)
  String month; // 'Janvier', 'Février', etc.
  
  @HiveField(4)
  int year;
  
  @HiveField(5)
  double baseSalary;
  
  @HiveField(6)
  double bonus; // Prime
  
  @HiveField(7)
  double deduction; // Déduction
  
  @HiveField(8)
  double netSalary;
  
  @HiveField(9)
  String paymentDate;
  
  @HiveField(10)
  String paymentMethod; // 'Espèces', 'Virement', 'Mobile Money'
  
  @HiveField(11)
  String? reference;
  
  @HiveField(12)
  String? notes;
  
  @HiveField(13)
  String schoolId;
  
  @HiveField(14)
  DateTime? createdAt;
  
  @HiveField(15)
  String? firestoreId;

  StaffPaymentModel({
    this.id,
    required this.staffId,
    required this.staffName,
    required this.month,
    required this.year,
    required this.baseSalary,
    this.bonus = 0,
    this.deduction = 0,
    required this.netSalary,
    required this.paymentDate,
    required this.paymentMethod,
    this.reference,
    this.notes,
    required this.schoolId,
    this.createdAt,
    this.firestoreId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'staffId': staffId,
      'staffName': staffName,
      'month': month,
      'year': year,
      'baseSalary': baseSalary,
      'bonus': bonus,
      'deduction': deduction,
      'netSalary': netSalary,
      'paymentDate': paymentDate,
      'paymentMethod': paymentMethod,
      'reference': reference,
      'notes': notes,
      'schoolId': schoolId,
      'createdAt': createdAt?.toIso8601String(),
      'firestoreId': firestoreId,
    };
  }

  factory StaffPaymentModel.fromMap(Map<String, dynamic> map) {
    return StaffPaymentModel(
      id: map['id'],
      staffId: map['staffId'] ?? 0,
      staffName: map['staffName'] ?? '',
      month: map['month'] ?? '',
      year: map['year'] ?? DateTime.now().year,
      baseSalary: map['baseSalary'] ?? 0.0,
      bonus: map['bonus'] ?? 0.0,
      deduction: map['deduction'] ?? 0.0,
      netSalary: map['netSalary'] ?? 0.0,
      paymentDate: map['paymentDate'] ?? '',
      paymentMethod: map['paymentMethod'] ?? 'Espèces',
      reference: map['reference'],
      notes: map['notes'],
      schoolId: map['schoolId'] ?? '',
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt']) : null,
      firestoreId: map['firestoreId'],
    );
  }

  // Getter pour le libellé du mois
  String get monthLabel => '$month $year';

  // Getter pour le mode de paiement en français
  String get paymentMethodLabel {
    switch (paymentMethod) {
      case 'Espèces': return 'Espèces';
      case 'Virement': return 'Virement bancaire';
      case 'Mobile Money': return 'Mobile Money';
      default: return paymentMethod;
    }
  }

  // Getter pour l'icône du mode de paiement
  IconData get paymentMethodIcon {
    switch (paymentMethod) {
      case 'Espèces': return Icons.money;
      case 'Virement': return Icons.account_balance;
      case 'Mobile Money': return Icons.phone_android;
      default: return Icons.payment;
    }
  }
}