// lib/models/online_course_model.dart

import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'online_course_model.g.dart';

@HiveType(typeId: 14)
class OnlineCourseModel extends HiveObject {
  @HiveField(0)
  final int id;
  
  @HiveField(1)
  final String title;
  
  @HiveField(2)
  final String description;
  
  @HiveField(3)
  final String subject;
  
  @HiveField(4)
  final String className;
  
  @HiveField(5)
  final String classId;
  
  @HiveField(6)
  final String professorId;
  
  @HiveField(7)
  final List<Map<String, dynamic>> chapters;
  
  @HiveField(8)
  final List<Map<String, dynamic>> resources;
  
  @HiveField(9)
  final DateTime createdAt;
  
  @HiveField(10)
  final DateTime updatedAt;

  // ===============================================================
  // NOUVEAUX CHAMPS POUR LA STRUCTURE HIÉRARCHIQUE
  // ===============================================================
  
  @HiveField(11)
  String? schoolFirestoreId;
  
  @HiveField(12)
  String? courseFirestoreId;
  
  @HiveField(13)
  String? professorName;
  
  @HiveField(14)
  int? schoolId;
  
  @HiveField(15)
  String? localKey;
  
  @HiveField(16)
  bool isPublished; // ✅ Champ défini ici
  
  @HiveField(17)
  String? thumbnailUrl;
  
  @HiveField(18)
  int? duration;
  
  @HiveField(19)
  int? enrolledStudents;

  OnlineCourseModel({
    required this.id,
    required this.title,
    required this.description,
    required this.subject,
    required this.className,
    required this.classId,
    required this.professorId,
    required this.chapters,
    required this.resources,
    required this.createdAt,
    required this.updatedAt,
    this.schoolFirestoreId,
    this.courseFirestoreId,
    this.professorName,
    this.schoolId,
    this.localKey,
    this.isPublished = false, // ✅ Valeur par défaut
    this.thumbnailUrl,
    this.duration,
    this.enrolledStudents,
  });

  // ===============================================================
  // PROPRIÉTÉS CALCULÉES (sans doublons)
  // ===============================================================
  
  int get chapterCount => chapters.length;
  
  int get resourceCount => resources.length;
  
  bool get hasChapters => chapters.isNotEmpty;
  
  bool get hasResources => resources.isNotEmpty;
  
  // ✅ Getter renommé pour éviter le conflit
  bool get isPublishedStatus => isPublished;
  
  bool get hasThumbnail => thumbnailUrl != null && thumbnailUrl!.isNotEmpty;
  
  bool get hasFirestoreId => courseFirestoreId != null && courseFirestoreId!.isNotEmpty;
  
  String get durationLabel {
    if (duration == null) return 'Durée non spécifiée';
    final hours = duration! ~/ 60;
    final minutes = duration! % 60;
    if (hours > 0) {
      return '$hours h ${minutes > 0 ? '$minutes min' : ''}';
    }
    return '$minutes min';
  }

  // ===============================================================
  // CONSTRUCTEUR DEPUIS FIRESTORE
  // ===============================================================
  
  factory OnlineCourseModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return OnlineCourseModel(
      id: data['id'] ?? 0,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      subject: data['subject'] ?? '',
      className: data['className'] ?? '',
      classId: data['classId'] ?? '',
      professorId: data['professorId'] ?? '',
      professorName: data['professorName'],
      chapters: List<Map<String, dynamic>>.from(data['chapters'] ?? []),
      resources: List<Map<String, dynamic>>.from(data['resources'] ?? []),
      createdAt: data['createdAt'] != null 
          ? DateTime.parse(data['createdAt']) 
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null 
          ? DateTime.parse(data['updatedAt']) 
          : DateTime.now(),
      schoolFirestoreId: data['schoolFirestoreId'],
      courseFirestoreId: docId,
      schoolId: data['schoolId'],
      localKey: data['localKey'] ?? data['id']?.toString(),
      isPublished: data['isPublished'] ?? false,
      thumbnailUrl: data['thumbnailUrl'],
      duration: data['duration'],
      enrolledStudents: data['enrolledStudents'] ?? 0,
    );
  }

  // ===============================================================
  // CONVERSION POUR FIRESTORE
  // ===============================================================
  
  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'subject': subject,
      'className': className,
      'classId': classId,
      'professorId': professorId,
      'professorName': professorName,
      'chapters': chapters,
      'resources': resources,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'schoolId': schoolId,
      'schoolFirestoreId': schoolFirestoreId,
      'localKey': localKey ?? id.toString(),
      'isPublished': isPublished, // ✅ Utilisation du champ
      'thumbnailUrl': thumbnailUrl,
      'duration': duration,
      'enrolledStudents': enrolledStudents ?? 0,
    };
  }

  // ===============================================================
  // CONVERSION POUR HIVE (LOCAL)
  // ===============================================================
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'subject': subject,
      'className': className,
      'classId': classId,
      'professorId': professorId,
      'professorName': professorName,
      'chapters': chapters,
      'resources': resources,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'schoolFirestoreId': schoolFirestoreId,
      'courseFirestoreId': courseFirestoreId,
      'schoolId': schoolId,
      'localKey': localKey,
      'isPublished': isPublished,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration,
      'enrolledStudents': enrolledStudents,
    };
  }

  factory OnlineCourseModel.fromMap(Map<String, dynamic> map) {
    return OnlineCourseModel(
      id: map['id'] ?? 0,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      subject: map['subject'] ?? '',
      className: map['className'] ?? '',
      classId: map['classId'] ?? '',
      professorId: map['professorId'] ?? '',
      professorName: map['professorName'],
      chapters: List<Map<String, dynamic>>.from(map['chapters'] ?? []),
      resources: List<Map<String, dynamic>>.from(map['resources'] ?? []),
      createdAt: map['createdAt'] ?? DateTime.now(),
      updatedAt: map['updatedAt'] ?? DateTime.now(),
      schoolFirestoreId: map['schoolFirestoreId'],
      courseFirestoreId: map['courseFirestoreId'],
      schoolId: map['schoolId'],
      localKey: map['localKey'],
      isPublished: map['isPublished'] ?? false,
      thumbnailUrl: map['thumbnailUrl'],
      duration: map['duration'],
      enrolledStudents: map['enrolledStudents'] ?? 0,
    );
  }

  // ===============================================================
  // MÉTHODES UTILITAIRES
  // ===============================================================
  
  OnlineCourseModel copyWith({
    int? id,
    String? title,
    String? description,
    String? subject,
    String? className,
    String? classId,
    String? professorId,
    List<Map<String, dynamic>>? chapters,
    List<Map<String, dynamic>>? resources,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? schoolFirestoreId,
    String? courseFirestoreId,
    String? professorName,
    int? schoolId,
    String? localKey,
    bool? isPublished,
    String? thumbnailUrl,
    int? duration,
    int? enrolledStudents,
  }) {
    return OnlineCourseModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      subject: subject ?? this.subject,
      className: className ?? this.className,
      classId: classId ?? this.classId,
      professorId: professorId ?? this.professorId,
      chapters: chapters ?? this.chapters,
      resources: resources ?? this.resources,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schoolFirestoreId: schoolFirestoreId ?? this.schoolFirestoreId,
      courseFirestoreId: courseFirestoreId ?? this.courseFirestoreId,
      professorName: professorName ?? this.professorName,
      schoolId: schoolId ?? this.schoolId,
      localKey: localKey ?? this.localKey,
      isPublished: isPublished ?? this.isPublished,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      enrolledStudents: enrolledStudents ?? this.enrolledStudents,
    );
  }

  OnlineCourseModel addChapter(Map<String, dynamic> chapter) {
    final newChapters = List<Map<String, dynamic>>.from(chapters);
    newChapters.add(chapter);
    return copyWith(
      chapters: newChapters,
      updatedAt: DateTime.now(),
    );
  }

  OnlineCourseModel addResource(Map<String, dynamic> resource) {
    final newResources = List<Map<String, dynamic>>.from(resources);
    newResources.add(resource);
    return copyWith(
      resources: newResources,
      updatedAt: DateTime.now(),
    );
  }

  OnlineCourseModel removeChapter(int index) {
    final newChapters = List<Map<String, dynamic>>.from(chapters);
    if (index >= 0 && index < newChapters.length) {
      newChapters.removeAt(index);
    }
    return copyWith(
      chapters: newChapters,
      updatedAt: DateTime.now(),
    );
  }

  OnlineCourseModel removeResource(int index) {
    final newResources = List<Map<String, dynamic>>.from(resources);
    if (index >= 0 && index < newResources.length) {
      newResources.removeAt(index);
    }
    return copyWith(
      resources: newResources,
      updatedAt: DateTime.now(),
    );
  }
}

// ===============================================================
// EXTENSION POUR FACILITER LA MANIPULATION DES COURS
// ===============================================================

extension OnlineCourseModelExtension on List<OnlineCourseModel> {
  List<OnlineCourseModel> filterByClass(String classId) {
    return where((c) => c.classId == classId).toList();
  }

  List<OnlineCourseModel> filterBySubject(String subject) {
    return where((c) => c.subject == subject).toList();
  }

  List<OnlineCourseModel> filterByProfessor(String professorId) {
    return where((c) => c.professorId == professorId).toList();
  }

  List<OnlineCourseModel> filterBySchool(String schoolFirestoreId) {
    return where((c) => c.schoolFirestoreId == schoolFirestoreId).toList();
  }

  List<OnlineCourseModel> getPublished() {
    return where((c) => c.isPublished).toList(); // ✅ Utilisation du champ
  }

  List<OnlineCourseModel> getUnpublished() {
    return where((c) => !c.isPublished).toList(); // ✅ Utilisation du champ
  }

  List<OnlineCourseModel> filterByTitle(String query) {
    if (query.isEmpty) return this;
    return where((c) => 
      c.title.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }

  List<OnlineCourseModel> filterByDescription(String query) {
    if (query.isEmpty) return this;
    return where((c) => 
      c.description.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }

  Map<String, List<OnlineCourseModel>> groupBySubject() {
    final Map<String, List<OnlineCourseModel>> result = {};
    for (var c in this) {
      if (!result.containsKey(c.subject)) {
        result[c.subject] = [];
      }
      result[c.subject]!.add(c);
    }
    return result;
  }

  Map<String, List<OnlineCourseModel>> groupByClass() {
    final Map<String, List<OnlineCourseModel>> result = {};
    for (var c in this) {
      if (!result.containsKey(c.classId)) {
        result[c.classId] = [];
      }
      result[c.classId]!.add(c);
    }
    return result;
  }

  Map<String, List<OnlineCourseModel>> groupByProfessor() {
    final Map<String, List<OnlineCourseModel>> result = {};
    for (var c in this) {
      if (!result.containsKey(c.professorId)) {
        result[c.professorId] = [];
      }
      result[c.professorId]!.add(c);
    }
    return result;
  }

  Map<String, dynamic> getStatistics() {
    final bySubject = groupBySubject();
    final byClass = groupByClass();
    
    return {
      'total': length,
      'published': getPublished().length,
      'unpublished': getUnpublished().length,
      'bySubject': bySubject.map((key, value) => MapEntry(key, value.length)),
      'byClass': byClass.map((key, value) => MapEntry(key, value.length)),
      'totalChapters': fold(0, (sum, c) => sum + c.chapterCount),
      'totalResources': fold(0, (sum, c) => sum + c.resourceCount),
    };
  }

  List<OnlineCourseModel> getUnsynced() {
    return where((c) => !c.hasFirestoreId).toList();
  }

  List<OnlineCourseModel> sortedByDateDesc() {
    final list = [...this];
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<OnlineCourseModel> sortedByTitle() {
    final list = [...this];
    list.sort((a, b) => a.title.compareTo(b.title));
    return list;
  }

  List<OnlineCourseModel> sortedBySubject() {
    final list = [...this];
    list.sort((a, b) => a.subject.compareTo(b.subject));
    return list;
  }

  List<OnlineCourseModel> sortedByChapterCount() {
    final list = [...this];
    list.sort((a, b) => b.chapterCount.compareTo(a.chapterCount));
    return list;
  }
}