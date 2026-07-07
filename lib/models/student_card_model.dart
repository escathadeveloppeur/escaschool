// lib/models/student_card_model.dart
import 'package:flutter/material.dart';


class StudentCardData {
  final String studentId;
  final String fullName;
  final String className;
  final String classCycleType;
  final String? sectionName;
  final String? gender;
  final String? birthDate;
  final String? birthPlace;
  final String? fatherName;
  final String? motherName;
  final String? parentPhone;
  final String? address;
  final String schoolName;
  final String schoolId;
  final DateTime generationDate;
  
  // ✅ Ajout des couleurs personnalisables
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;

  StudentCardData({
    required this.studentId,
    required this.fullName,
    required this.className,
    required this.classCycleType,
    this.sectionName,
    this.gender,
    this.birthDate,
    this.birthPlace,
    this.fatherName,
    this.motherName,
    this.parentPhone,
    this.address,
    required this.schoolName,
    required this.schoolId,
    DateTime? generationDate,
    this.primaryColor = const Color(0xFF1E3A8A),
    this.secondaryColor = const Color(0xFF10B981),
    this.accentColor = const Color(0xFF8B5CF6),
  }) : generationDate = generationDate ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'studentId': studentId,
    'fullName': fullName,
    'className': className,
    'classCycleType': classCycleType,
    'sectionName': sectionName,
    'gender': gender,
    'birthDate': birthDate,
    'birthPlace': birthPlace,
    'fatherName': fatherName,
    'motherName': motherName,
    'parentPhone': parentPhone,
    'address': address,
    'schoolName': schoolName,
    'schoolId': schoolId,
    'generationDate': generationDate.toIso8601String(),
  };

  factory StudentCardData.fromJson(Map<String, dynamic> json) => StudentCardData(
    studentId: json['studentId'],
    fullName: json['fullName'],
    className: json['className'],
    classCycleType: json['classCycleType'],
    sectionName: json['sectionName'],
    gender: json['gender'],
    birthDate: json['birthDate'],
    birthPlace: json['birthPlace'],
    fatherName: json['fatherName'],
    motherName: json['motherName'],
    parentPhone: json['parentPhone'],
    address: json['address'],
    schoolName: json['schoolName'],
    schoolId: json['schoolId'],
    generationDate: DateTime.parse(json['generationDate']),
  );
}