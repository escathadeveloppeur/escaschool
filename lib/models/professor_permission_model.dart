import 'package:hive/hive.dart';

part 'professor_permission_model.g.dart';

@HiveType(typeId: 9)
class ProfessorPermissionModel {
  @HiveField(0)
  final int id;
  
  @HiveField(1)
  final int professorId;
  
  @HiveField(2)
  final int classId;
  
  @HiveField(3)
  final String permissionType;
  
  @HiveField(4)
  final String grantedAt;
  
  @HiveField(5)
  final String? updatedAt;
  
  ProfessorPermissionModel({
    required this.id,
    required this.professorId,
    required this.classId,
    required this.permissionType,
    required this.grantedAt,
    this.updatedAt,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'professorId': professorId,
      'classId': classId,
      'permissionType': permissionType,
      'grantedAt': grantedAt,
      'updatedAt': updatedAt,
    };
  }
}