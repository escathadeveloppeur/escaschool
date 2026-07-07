// lib/models/staff_card_model.dart

import 'package:flutter/material.dart';

class StaffCardData {
  final String staffId;
  final String fullName;
  final String position;
  final String schoolId;
  final String schoolName;
  final String? phone;
  final String? email;
  final String? address;
  final double salary;
  final DateTime hireDate;
  final bool isActive;
  final DateTime generationDate;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;

  StaffCardData({
    required this.staffId,
    required this.fullName,
    required this.position,
    required this.schoolId,
    required this.schoolName,
    this.phone,
    this.email,
    this.address,
    required this.salary,
    required this.hireDate,
    this.isActive = true,
    DateTime? generationDate,
    this.primaryColor = const Color(0xFF0F766E),
    this.secondaryColor = const Color(0xFF14B8A6),
    this.accentColor = const Color(0xFF8B5CF6),
  }) : generationDate = generationDate ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'staffId': staffId,
    'fullName': fullName,
    'position': position,
    'schoolId': schoolId,
    'schoolName': schoolName,
    'phone': phone,
    'email': email,
    'address': address,
    'salary': salary,
    'hireDate': hireDate.toIso8601String(),
    'isActive': isActive,
    'generationDate': generationDate.toIso8601String(),
  };

  factory StaffCardData.fromJson(Map<String, dynamic> json) => StaffCardData(
    staffId: json['staffId'],
    fullName: json['fullName'],
    position: json['position'],
    schoolId: json['schoolId'],
    schoolName: json['schoolName'],
    phone: json['phone'],
    email: json['email'],
    address: json['address'],
    salary: json['salary'].toDouble(),
    hireDate: DateTime.parse(json['hireDate']),
    isActive: json['isActive'] ?? true,
    generationDate: DateTime.parse(json['generationDate']),
  );
}