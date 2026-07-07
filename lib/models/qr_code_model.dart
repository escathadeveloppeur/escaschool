// lib/models/qr_code_model.dart

class QRCodeData {
  final String id;
  final String studentId;
  final String studentName;
  final String className;
  final String schoolId;
  final String schoolName;
  final String classCycleType;
  final String? sectionName;
  final String? parentPhone; // ✅ Ajout du téléphone du parent
  final String? parentName; // ✅ Ajout du nom du parent
  final DateTime generatedAt;
  String qrCodeData;
  final bool isActive;
  final int version;

  QRCodeData({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.schoolId,
    required this.schoolName,
    required this.classCycleType,
    this.sectionName,
    this.parentPhone, // ✅ Ajout
    this.parentName, // ✅ Ajout
    DateTime? generatedAt,
    this.qrCodeData = '',
    this.isActive = true,
    this.version = 1,
  }) : generatedAt = generatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'studentId': studentId,
    'studentName': studentName,
    'className': className,
    'schoolId': schoolId,
    'schoolName': schoolName,
    'classCycleType': classCycleType,
    'sectionName': sectionName,
    'parentPhone': parentPhone, // ✅ Ajout
    'parentName': parentName, // ✅ Ajout
    'generatedAt': generatedAt.toIso8601String(),
    'qrCodeData': qrCodeData,
    'isActive': isActive,
    'version': version,
  };

  factory QRCodeData.fromJson(Map<String, dynamic> json) => QRCodeData(
    id: json['id'],
    studentId: json['studentId'],
    studentName: json['studentName'],
    className: json['className'],
    schoolId: json['schoolId'],
    schoolName: json['schoolName'],
    classCycleType: json['classCycleType'],
    sectionName: json['sectionName'],
    parentPhone: json['parentPhone'], // ✅ Ajout
    parentName: json['parentName'], // ✅ Ajout
    generatedAt: DateTime.parse(json['generatedAt']),
    qrCodeData: json['qrCodeData'] ?? '',
    isActive: json['isActive'] ?? true,
    version: json['version'] ?? 1,
  );
}

class ClassQRCodeGroup {
  final String className;
  final String schoolId;
  final String schoolName;
  final String classCycleType;
  final String? sectionName;
  final List<QRCodeData> students;
  final DateTime generatedAt;

  ClassQRCodeGroup({
    required this.className,
    required this.schoolId,
    required this.schoolName,
    required this.classCycleType,
    this.sectionName,
    required this.students,
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'className': className,
    'schoolId': schoolId,
    'schoolName': schoolName,
    'classCycleType': classCycleType,
    'sectionName': sectionName,
    'students': students.map((s) => s.toJson()).toList(),
    'generatedAt': generatedAt.toIso8601String(),
  };

  factory ClassQRCodeGroup.fromJson(Map<String, dynamic> json) => ClassQRCodeGroup(
    className: json['className'],
    schoolId: json['schoolId'],
    schoolName: json['schoolName'],
    classCycleType: json['classCycleType'],
    sectionName: json['sectionName'],
    students: (json['students'] as List).map((s) => QRCodeData.fromJson(s)).toList(),
    generatedAt: DateTime.parse(json['generatedAt']),
  );
}