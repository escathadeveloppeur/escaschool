// lib/services/db_helper.dart (version corrigée)

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../models/payment_model.dart';
import '../models/document_model.dart';
import '../models/attendance_model.dart';
import '../models/grade_model.dart';
import '../models/professor_model.dart';
import '../models/schedule_model.dart';
import '../models/professor_permission_model.dart';
import '../models/parent_student_link.dart';
import 'package:collection/collection.dart';
import '../models/online_exam_model.dart';
import '../models/exam_result_model.dart';
import '../models/online_course_model.dart';
import '../models/university/departement_model.dart';
import '../models/university/etablissement_model.dart';
import '../models/university/faculte_model.dart';
import '../models/university/niveau_model.dart';
import '../models/university/module_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../models/user.dart';
import '../models/message_model.dart';
import '../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../models/staff_model.dart';
import '../models/staff_payment_model.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();
    static const String staffBox = 'staff';  // ✅ Constante pour le nom de la box
  static const String staffPaymentsBox = 'staff_payments';
  static const String _staffBox = 'staff';
  static const String _staffPaymentsBox = 'staff_payments';

  // ================= CONSTANTES =================
  static const String BOX_NAME = 'ecole_box';
  static const String USERS_KEY = 'users';
  static const String LAST_ID_KEY = 'users_last_id';
  static const String CLASSES_KEY = 'classes';
  static const String LOGS_KEY = 'logs';
  static const String ANNOUNCEMENTS_KEY = 'announcements';
  static const String STUDENTS_KEY = 'students';
  static const String PAYMENTS_KEY = 'payments';
  static const String DOCUMENTS_KEY = 'documents';
  static const String LAST_CLASS_ID = 'last_class_id';
  static const String LAST_STUDENT_ID = 'last_student_id';
  static const String LAST_PAYMENT_ID = 'last_payment_id';

  // Clés pour professeurs
  static const String PROFESSORS_KEY = 'professors';
  static const String SCHEDULES_KEY = 'schedules';
  static const String PROFESSOR_PERMISSIONS_KEY = 'professor_permissions';
  static const String LAST_PROFESSOR_ID = 'last_professor_id';
  static const String LAST_SCHEDULE_ID = 'last_schedule_id';
  static const String LAST_PERMISSION_ID = 'last_permission_id';
  
  // Examen en ligne
  static const String ONLINE_EXAMS_KEY = 'online_exams';
  static const String EXAM_RESULTS_KEY = 'exam_results';
  static const String ONLINE_COURSES_KEY = 'online_courses';

  // Clés pour les permissions des étudiants
  static const String STUDENT_PERMISSIONS_KEY = 'student_permissions';
  static const String STUDENT_CLASS_PERMISSIONS_KEY = 'student_class_permissions';
  
  // Clé pour la liaison parent-enfant
  static const String PARENT_STUDENT_LINKS_KEY = 'parent_student_links';
  
  // Clés pour les matières
  static const String SUBJECTS_KEY = 'subjects';
  static const String LAST_SUBJECT_ID = 'last_subject_id';
  
  // Clés pour la synchronisation
  static const String SYNC_STATUS_KEY = 'sync_status';
  static const String LAST_SYNC_KEY = 'last_sync';

  // ================= CONSTANTES UNIVERSITÉ =================

  static const String FACULTES_KEY = 'facultes';
  static const String DEPARTEMENTS_KEY = 'departements';
  static const String NIVEAUX_KEY = 'niveaux';
  static const String MODULES_KEY = 'modules';
  
  //cles message
  static const String MESSAGES_KEY='messages'; 
   static const String NOTIFICATION_KEY='notifications';
  
  static const String ETABLISSEMENT_BOX = 'etablissements';
  

  // Box Hive
  late Box _box;
  
  final ApiService _apiService = ApiService();

  // ================= INIT =================
  Future<void> init() async {
  WidgetsFlutterBinding.ensureInitialized();
  Directory dir;
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    dir = await getApplicationSupportDirectory();
  } else {
    dir = await getApplicationDocumentsDirectory();
  }
  
  print('🔥🔥🔥 HIVE STORAGE PATH: ${dir.path} 🔥🔥🔥');
  Hive.init(dir.path);
  
  // ⚠️ IMPORTANT: Enregistrer TOUS les adaptateurs AVANT d'ouvrir les boxes
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(ClassModelAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(StudentModelAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(PaymentModelAdapter());
  if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(DocumentModelAdapter());
  if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(AttendanceModelAdapter());
  if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(GradeModelAdapter());
  if (!Hive.isAdapterRegistered(7)) Hive.registerAdapter(ProfessorModelAdapter());
  if (!Hive.isAdapterRegistered(8)) Hive.registerAdapter(ScheduleModelAdapter());
  if (!Hive.isAdapterRegistered(9)) Hive.registerAdapter(ProfessorPermissionModelAdapter());
  if (!Hive.isAdapterRegistered(11)) Hive.registerAdapter(ParentStudentLinkAdapter());
  if (!Hive.isAdapterRegistered(12)) Hive.registerAdapter(OnlineExamModelAdapter());
  if (!Hive.isAdapterRegistered(13)) Hive.registerAdapter(ExamResultModelAdapter());
  if (!Hive.isAdapterRegistered(14)) Hive.registerAdapter(OnlineCourseModelAdapter());
  if (!Hive.isAdapterRegistered(15)) Hive.registerAdapter(EtablissementModelAdapter());
  if (!Hive.isAdapterRegistered(16)) Hive.registerAdapter(FaculteModelAdapter());
  if (!Hive.isAdapterRegistered(17)) Hive.registerAdapter(DepartementModelAdapter());
  if (!Hive.isAdapterRegistered(18)) Hive.registerAdapter(NiveauModelAdapter());
  if (!Hive.isAdapterRegistered(19)) Hive.registerAdapter(ModuleModelAdapter());
  if (!Hive.isAdapterRegistered(20)) Hive.registerAdapter(MessageModelAdapter());
  if (!Hive.isAdapterRegistered(21)) Hive.registerAdapter(NotificationModelAdapter());
  if (!Hive.isAdapterRegistered(22)) Hive.registerAdapter(StaffModelAdapter());      // ← AJOUTER
  if (!Hive.isAdapterRegistered(23)) Hive.registerAdapter(StaffPaymentModelAdapter()); // ← AJOUTER

  // MAINTENANT ouvrir les boxes
  _box = await Hive.openBox(BOX_NAME);
  
  // Ouvrir les autres boxes
  await Hive.openBox<StudentModel>(STUDENTS_KEY);
  await Hive.openBox<PaymentModel>(PAYMENTS_KEY);
  await Hive.openBox<DocumentModel>(DOCUMENTS_KEY);
  await Hive.openBox<ClassModel>(CLASSES_KEY);
  await Hive.openBox<AttendanceModel>('attendance');
  await Hive.openBox<GradeModel>('grades');
  await Hive.openBox<ProfessorModel>(PROFESSORS_KEY);
  await Hive.openBox<ScheduleModel>(SCHEDULES_KEY);
  await Hive.openBox<ProfessorPermissionModel>(PROFESSOR_PERMISSIONS_KEY);
  await Hive.openBox<ParentStudentLink>(PARENT_STUDENT_LINKS_KEY);
  await Hive.openBox<OnlineExamModel>(ONLINE_EXAMS_KEY);
  await Hive.openBox<ExamResultModel>(EXAM_RESULTS_KEY);
  await Hive.openBox<OnlineCourseModel>(ONLINE_COURSES_KEY);
  await Hive.openBox<FaculteModel>(FACULTES_KEY);
  await Hive.openBox<DepartementModel>(DEPARTEMENTS_KEY);
  await Hive.openBox<NiveauModel>(NIVEAUX_KEY);
  await Hive.openBox<ModuleModel>(MODULES_KEY);
  await Hive.openBox<MessageModel>(MESSAGES_KEY);
  await Hive.openBox<NotificationModel>(NOTIFICATION_KEY);
  // Dans init()
await Hive.openBox<Map<String, dynamic>>(ETABLISSEMENT_BOX);
  await Hive.openBox<StaffModel>('staff');
  await Hive.openBox<StaffPaymentModel>('staff_payments');
}
// lib/services/db_helper.dart

// ================= MESSAGES =================

/// Ajouter un message
Future<void> addMessage(MessageModel message) async {
  try {
    final box = await Hive.openBox<Map>('messages');
    final messageMap = {
      'key': message.key,
      'senderName': message.senderName,
      'senderRole': message.senderRole,
      'recipientName': message.recipientName,
      'recipientRole': message.recipientRole,
      'studentName': message.studentName,
      'subject': message.subject,
      'content': message.content,
      'date': message.date.toIso8601String(),
      'read': message.read,
      'important': message.important,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await box.put(message.key, messageMap);
    print('✅ Message ajouté: ${message.key}');
  } catch (e) {
    print('❌ Erreur ajout message: $e');
    throw e;
  }
}

/// Récupérer tous les messages
Future<List<MessageModel>> getAllMessages() async {
  try {
    final box = await Hive.openBox<Map>('messages');
    final List<MessageModel> messages = [];
    
    for (var key in box.keys) {
      final data = box.get(key) as Map;
      messages.add(MessageModel(
        senderName: data['senderName'] ?? '',
        senderRole: data['senderRole'] ?? '',
        recipientName: data['recipientName'] ?? '',
        recipientRole: data['recipientRole'] ?? '',
        studentName: data['studentName'] ?? '',
        subject: data['subject'] ?? '',
        content: data['content'] ?? '',
        date: data['date'] != null ? DateTime.parse(data['date']) : DateTime.now(),
        read: data['read'] ?? false,
        important: data['important'] ?? false,
      ));
    }
    
    // Trier par date (plus récent en premier)
    messages.sort((a, b) => b.date.compareTo(a.date));
    return messages;
  } catch (e) {
    print('❌ Erreur récupération messages: $e');
    return [];
  }
}

/// Récupérer un message par sa clé
Future<MessageModel?> getMessageByKey(String key) async {
  try {
    final box = await Hive.openBox<Map>('messages');
    final data = box.get(key) as Map?;
    
    if (data == null) return null;
    
    return MessageModel(
      senderName: data['senderName'] ?? '',
      senderRole: data['senderRole'] ?? '',
      recipientName: data['recipientName'] ?? '',
      recipientRole: data['recipientRole'] ?? '',
      studentName: data['studentName'] ?? '',
      subject: data['subject'] ?? '',
      content: data['content'] ?? '',
      date: data['date'] != null ? DateTime.parse(data['date']) : DateTime.now(),
      read: data['read'] ?? false,
      important: data['important'] ?? false,
    );
  } catch (e) {
    print('❌ Erreur récupération message par clé: $e');
    return null;
  }
}

/// Mettre à jour le statut de lecture d'un message
Future<void> updateMessageReadStatus(String key, bool read) async {
  try {
   
  } catch (e) {
    print('❌ Erreur mise à jour statut lecture: $e');
  }
}

/// Marquer un message comme important
Future<void> markMessageAsImportant(String key, bool important) async {
  try {    
  } catch (e) {
    print('❌ Erreur marquage message: $e');
  }
}

/// Supprimer un message
Future<void> deleteMessage(String key) async {
  try {
    final box = await Hive.openBox<Map>('messages');
    await box.delete(key);
    print('✅ Message supprimé: $key');
  } catch (e) {
    print('❌ Erreur suppression message: $e');
  }
}

/// Supprimer tous les messages
Future<void> deleteAllMessages() async {
  try {
    final box = await Hive.openBox<Map>('messages');
    await box.clear();
    print('✅ Tous les messages supprimés');
  } catch (e) {
    print('❌ Erreur suppression tous les messages: $e');
  }
}

/// Compter le nombre de messages non lus pour un utilisateur
Future<int> getUnreadMessagesCount({
  required String recipientName,
  required String recipientRole,
  String? studentName,
}) async {
  try {
    final messages = await getAllMessages();
    
    return messages.where((message) {
      if (studentName != null && studentName.isNotEmpty) {
        return message.recipientName == recipientName &&
               message.recipientRole == recipientRole &&
               message.studentName == studentName &&
               !message.read;
      }
      return message.recipientName == recipientName &&
             message.recipientRole == recipientRole &&
             !message.read;
    }).length;
  } catch (e) {
    print('❌ Erreur comptage messages non lus: $e');
    return 0;
  }
}

/// Récupérer les messages d'un utilisateur spécifique
Future<List<MessageModel>> getMessagesForRecipient({
  required String recipientName,
  required String recipientRole,
  String? studentName,
}) async {
  try {
    final messages = await getAllMessages();
    
    return messages.where((message) {
      if (studentName != null && studentName.isNotEmpty) {
        return message.recipientName == recipientName &&
               message.recipientRole == recipientRole &&
               message.studentName == studentName;
      }
      return message.recipientName == recipientName &&
             message.recipientRole == recipientRole;
    }).toList();
  } catch (e) {
    print('❌ Erreur récupération messages par destinataire: $e');
    return [];
  }
}

/// Récupérer les messages envoyés par un utilisateur
Future<List<MessageModel>> getMessagesFromSender({
  required String senderName,
  required String senderRole,
}) async {
  try {
    final messages = await getAllMessages();
    
    return messages.where((message) {
      return message.senderName == senderName &&
             message.senderRole == senderRole;
    }).toList();
  } catch (e) {
    print('❌ Erreur récupération messages par expéditeur: $e');
    return [];
  }
}

/// Récupérer les messages importants d'un utilisateur
Future<List<MessageModel>> getImportantMessagesForRecipient({
  required String recipientName,
  required String recipientRole,
  String? studentName,
}) async {
  try {
    final messages = await getAllMessages();
    
    return messages.where((message) {
      if (studentName != null && studentName.isNotEmpty) {
        return message.recipientName == recipientName &&
               message.recipientRole == recipientRole &&
               message.studentName == studentName &&
               message.important;
      }
      return message.recipientName == recipientName &&
             message.recipientRole == recipientRole &&
             message.important;
    }).toList();
  } catch (e) {
    print('❌ Erreur récupération messages importants: $e');
    return [];
  }
}

/// Compter le nombre total de messages
Future<int> getTotalMessagesCount() async {
  try {
    final box = await Hive.openBox<Map>('messages');
    return box.length;
  } catch (e) {
    print('❌ Erreur comptage total messages: $e');
    return 0;
  }
}

/// Vérifier si un message existe
Future<bool> messageExists(String key) async {
  try {
    final box = await Hive.openBox<Map>('messages');
    return box.containsKey(key);
  } catch (e) {
    print('❌ Erreur vérification existence message: $e');
    return false;
  }
}

/// Mettre à jour un message existant
Future<void> updateMessage(MessageModel message) async {
  try {
    final box = await Hive.openBox<Map>('messages');
    final messageMap = {
      'key': message.key,
      'senderName': message.senderName,
      'senderRole': message.senderRole,
      'recipientName': message.recipientName,
      'recipientRole': message.recipientRole,
      'studentName': message.studentName,
      'subject': message.subject,
      'content': message.content,
      'date': message.date.toIso8601String(),
      'read': message.read,
      'important': message.important,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await box.put(message.key, messageMap);
    print('✅ Message mis à jour: ${message.key}');
  } catch (e) {
    print('❌ Erreur mise à jour message: $e');
    throw e;
  }
}
 
  Map<String, Map<String, dynamic>> _getUsersMap() {
    final m = _box.get(USERS_KEY, defaultValue: {});
    return Map<String, Map<String, dynamic>>.from(
      (m as Map).map((k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map))),
    );
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final users = _getUsersMap();
    final searchEmail = email.toLowerCase().trim();
    for (final u in users.values) {
      if ((u['email'] as String) == searchEmail) {
        return Map<String, dynamic>.from(u);
      }
    }
    return null;
  }

  Future<int> insertUser(Map<String, dynamic> user) async {
    print('📝 insertUser: ${user['name']}');
    final users = _getUsersMap();
    int lastId = _box.get(LAST_ID_KEY, defaultValue: 0) as int;
    final newId = lastId + 1;
    user['id'] = newId;
    user['email'] = (user['email'] as String).toLowerCase().trim();
    user['password'] = (user['password'] as String).trim();
    users[newId.toString()] = Map<String, dynamic>.from(user);
    await _box.put(USERS_KEY, users);
    await _box.put(LAST_ID_KEY, newId);
    await addLog("Admin a ajouté l'utilisateur ${user['name']} (${user['role']})");
    print('✅ Utilisateur inséré avec ID: $newId');
    return newId;
  }
// Dans lib/services/db_helper.dart
Future<String> getDatabasePath() async {
  final dir = await getApplicationDocumentsDirectory();
  return dir.path;
}
  // Dans db_helper.dart
Future<void> addLog(String action, {int? schoolId}) async {
  final logs = List<String>.from(_box.get(LOGS_KEY, defaultValue: []));
  final logEntry = schoolId != null 
      ? '[${DateTime.now().toIso8601String()}] [École ID: $schoolId] $action'
      : '[${DateTime.now().toIso8601String()}] $action';
  logs.add(logEntry);
  await _box.put(LOGS_KEY, logs);
}
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final users = _getUsersMap();
    return users.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }



  Future<void> updateUser(int id, Map<String, dynamic> updatedUser) async {
    final users = _getUsersMap();
    final key = id.toString();
    if (!users.containsKey(key)) return;
    users[key] = {
      ...users[key]!,
      'name': updatedUser['name'] ?? users[key]!['name'],
      'email': (updatedUser['email'] ?? users[key]!['email']).toLowerCase().trim(),
      'password': (updatedUser['password'] ?? users[key]!['password']).trim(),
      'role': updatedUser['role'] ?? users[key]!['role'],
    };
    await _box.put(USERS_KEY, users);
    await addLog("Admin a modifié l'utilisateur ${users[key]!['name']} (${users[key]!['role']})");
  }

  Future<bool> deleteUser(int id) async {
    final users = _getUsersMap();
    final key = id.toString();
    if (!users.containsKey(key)) return false;
    final removed = users.remove(key);
    await _box.put(USERS_KEY, users);
    await addLog("Admin a supprimé l'utilisateur ${removed?['name']} (${removed?['role']})");
    return true;
  }

  

  // ================= LIAISON PARENT-ENFANT =================
  Future<void> linkParentToStudent({
    required int parentUserId,
    required int studentKey,
    required String relation,
  }) async {
    try {
      final box = await Hive.openBox<ParentStudentLink>(PARENT_STUDENT_LINKS_KEY);
      await box.add(ParentStudentLink(
        parentUserId: parentUserId,
        studentKeyHive: studentKey,
        relation: relation,
      ));
      await addLog("Parent $parentUserId lié à l'étudiant $studentKey ($relation)");
    } catch (e) {
      print('Erreur linkParentToStudent: $e');
    }
  }

  Future<List<StudentModel>> getStudentsForParent(int parentUserId) async {
    try {
      final linksBox = await Hive.openBox<ParentStudentLink>(PARENT_STUDENT_LINKS_KEY);
      final studentBox = await Hive.openBox<StudentModel>(STUDENTS_KEY);
      
      List<StudentModel> students = [];
      
      for (var link in linksBox.values) {
        if (link.parentUserId == parentUserId) {
          final student = studentBox.get(link.studentKeyHive);
          if (student != null) students.add(student);
        }
      }
      return students;
    } catch (e) {
      print('Erreur getStudentsForParent: $e');
      return [];
    }
  }

  // ================= PROFESSEURS =================
  Map<String, Map<String, dynamic>> _getProfessorsMap() {
    final m = _box.get(PROFESSORS_KEY, defaultValue: {});
    return Map<String, Map<String, dynamic>>.from(
      (m as Map).map((k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map))),
    );
  }

  Future<List<Map<String, dynamic>>> getAllProfessors() async {
    final professors = _getProfessorsMap();
    return professors.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }
  // lib/services/db_helper.dart (extrait des méthodes à ajouter)

/// Récupérer une annonce par son ID local
Future<Map<String, dynamic>?> getAnnouncementByLocalId(dynamic localId) async {
  try {
    final box = await Hive.openBox<Map<String, dynamic>>('announcements');
    final allAnnouncements = box.values.toList();
    
    for (var announcement in allAnnouncements) {
      if (announcement['id'] == localId) {
        return announcement;
      }
    }
    return null;
  } catch (e) {
    print('❌ Erreur récupération annonce par localId: $e');
    return null;
  }
}

/// Mettre à jour une annonce par son ID local
Future<void> updateAnnouncementByLocalId(dynamic localId, Map<String, dynamic> announcement) async {
  try {
    final box = await Hive.openBox<Map<String, dynamic>>('announcements');
    
    // Trouver la clé correspondant à l'ID local
    for (var key in box.keys) {
      final existing = box.get(key);
      if (existing != null && existing['id'] == localId) {
        // Mettre à jour l'annonce
        final updatedAnnouncement = {
          ...existing,
          ...announcement,
          'updatedAt': DateTime.now().toIso8601String(),
        };
        await box.put(key, updatedAnnouncement);
        print('✅ Annonce mise à jour localement: $localId');
        return;
      }
    }
    print('⚠️ Annonce non trouvée pour mise à jour: $localId');
  } catch (e) {
    print('❌ Erreur mise à jour annonce: $e');
    throw e;
  }
}
// lib/services/db_helper.dart

/// ✅ Récupérer un résultat d'examen par ses clés (avec int)
Future<ExamResultModel?> getExamResultByKeys(int examId, int studentId) async {
  try {
    final box = await Hive.openBox<ExamResultModel>('exam_results');
    final key = '${examId}_${studentId}';
    final result = box.get(key);
    
    if (result != null) {
      print('✅ Résultat trouvé pour l\'examen $examId et l\'étudiant $studentId');
      return result;
    } else {
      print('ℹ️ Aucun résultat trouvé pour l\'examen $examId et l\'étudiant $studentId');
      return null;
    }
  } catch (e) {
    print('❌ Erreur récupération résultat examen: $e');
    return null;
  }
}

/// ✅ Ajouter un résultat d'examen
Future<void> addExamResult(ExamResultModel result) async {
  try {
    final box = await Hive.openBox<ExamResultModel>('exam_results');
    final key = result.localKey ?? '${result.examId}_${result.studentId}';
    await box.put(key, result);
    print('✅ Résultat examen ajouté: $key');
  } catch (e) {
    print('❌ Erreur ajout résultat examen: $e');
    throw e;
  }
}

/// ✅ Mettre à jour un résultat d'examen
Future<void> updateExamResult(ExamResultModel result) async {
  try {
    final box = await Hive.openBox<ExamResultModel>('exam_results');
    final key = result.localKey ?? '${result.examId}_${result.studentId}';
    await box.put(key, result);
    print('✅ Résultat examen mis à jour: $key');
  } catch (e) {
    print('❌ Erreur mise à jour résultat examen: $e');
    throw e;
  }
}
Future<List<Map<String, dynamic>>> getProfessorsWithDetails({int? schoolId}) async {
  final professors = await getAllProfessors();
  final users = await _getUsersMap();  // Assurez-vous que cette méthode est async ou adaptez

  final List<Map<String, dynamic>> result = [];

  for (var professor in professors) {
    Map<String, dynamic> prof = Map<String, dynamic>.from(professor);
    
    if (prof['userId'] != null) {
      final userKey = prof['userId'].toString();
      if (users.containsKey(userKey)) {
        final user = users[userKey]!;
        prof['userEmail'] = user['email'];
        prof['userRole'] = user['role'];
        prof['schoolId'] = user['schoolId'];  // Ajoutez cette ligne
        
        // Filtrage par école
        if (schoolId != null && user['schoolId'] != schoolId) {
          continue;  // Ignorer ce professeur s'il n'appartient pas à l'école demandée
        }
      }
    }
    result.add(prof);
  }
  return result;
}


  Future<int> addProfessor(Map<String, dynamic> professor) async {
    final professors = _getProfessorsMap();
    int lastId = _box.get(LAST_PROFESSOR_ID, defaultValue: 0) as int;
    final newId = lastId + 1;
    
    professor['id'] = newId;
    professor['createdAt'] = DateTime.now().toIso8601String();
    professor['status'] = professor['status'] ?? 'active';
    
    professors[newId.toString()] = Map<String, dynamic>.from(professor);
    await _box.put(PROFESSORS_KEY, professors);
    await _box.put(LAST_PROFESSOR_ID, newId);
    
    await addLog("Professeur ajouté: ${professor['fullName']}");
    
    // AJOUT: Synchronisation avec Laravel
    await _syncProfessorToServer(professor);
    
    return newId;
  }

  // AJOUT: Méthode de synchronisation professeur
  Future<void> _syncProfessorToServer(Map<String, dynamic> professor) async {
    try {
      final isConnected = await _apiService.testConnection();
      if (isConnected) {
        await _apiService.createProfesseur({
          'fullName': professor['fullName'],
          'email': professor['email'],
          'phone': professor['phone'],
          'specialty': professor['specialty'],
          'status': professor['status'],
        });
        print('✅ Professeur synchronisé avec Laravel');
      }
    } catch (e) {
      print('⚠️ Erreur synchronisation professeur: $e');
    }
  }

  Future<void> updateProfessor(int id, Map<String, dynamic> professor) async {
    final professors = _getProfessorsMap();
    final key = id.toString();
    if (!professors.containsKey(key)) return;
    
    professors[key] = {
      ...professors[key]!,
      'fullName': professor['fullName'] ?? professors[key]!['fullName'],
      'email': professor['email'] ?? professors[key]!['email'],
      'phone': professor['phone'] ?? professors[key]!['phone'],
      'specialty': professor['specialty'] ?? professors[key]!['specialty'],
      'userId': professor['userId'] ?? professors[key]!['userId'],
      'status': professor['status'] ?? professors[key]!['status'],
      'updatedAt': DateTime.now().toIso8601String(),
    };
    
    await _box.put(PROFESSORS_KEY, professors);
    await addLog("Professeur modifié: ${professors[key]!['fullName']}");
  }

  Future<bool> deleteProfessor(int id) async {
    final professors = _getProfessorsMap();
    final key = id.toString();
    if (!professors.containsKey(key)) return false;
    
    final removed = professors.remove(key);
    
    final schedules = await getSchedulesByProfessor(id);
    for (var schedule in schedules) {
      await deleteSchedule(schedule['id']);
    }
    
    final permissions = await getProfessorPermissions(id);
    for (var permission in permissions) {
      await revokeClassPermission(id, permission['classId']);
    }
    
    await _box.put(PROFESSORS_KEY, professors);
    await addLog("Professeur supprimé: ${removed?['fullName']}");
    return true;
  }

  Future<Map<String, dynamic>?> getProfessor(int id) async {
    final professors = _getProfessorsMap();
    final key = id.toString();
    return professors.containsKey(key) ? Map<String, dynamic>.from(professors[key]!) : null;
  }

  // ================= HORAIRES =================
  Map<String, Map<String, dynamic>> _getSchedulesMap() {
    final m = _box.get(SCHEDULES_KEY, defaultValue: {});
    return Map<String, Map<String, dynamic>>.from(
      (m as Map).map((k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map))),
    );
  }

  Future<int> addSchedule(Map<String, dynamic> schedule) async {
    final schedules = _getSchedulesMap();
    int lastId = _box.get(LAST_SCHEDULE_ID, defaultValue: 0) as int;
    final newId = lastId + 1;
    
    schedule['id'] = newId;
    schedule['createdAt'] = DateTime.now().toIso8601String();
    
    schedules[newId.toString()] = Map<String, dynamic>.from(schedule);
    await _box.put(SCHEDULES_KEY, schedules);
    await _box.put(LAST_SCHEDULE_ID, newId);
    
    final professor = await getProfessor(schedule['professorId']);
    final className = await _getClassName(schedule['classId']);
    
    await addLog("Horaire ajouté: ${professor?['fullName']} - ${schedule['subject']} ($className)");
    return newId;
  }

  Future<List<Map<String, dynamic>>> getSchedulesByProfessor(int professorId) async {
    final schedules = _getSchedulesMap();
    return schedules.values
        .where((s) => s['professorId'] == professorId)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getSchedulesByClass(int classId) async {
    final schedules = _getSchedulesMap();
    return schedules.values
        .where((s) => s['classId'] == classId)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getAllSchedules() async {
    final schedules = _getSchedulesMap();
    return schedules.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> updateSchedule(int id, Map<String, dynamic> schedule) async {
    final schedules = _getSchedulesMap();
    final key = id.toString();
    if (!schedules.containsKey(key)) return;
    
    schedules[key] = {
      ...schedules[key]!,
      'professorId': schedule['professorId'] ?? schedules[key]!['professorId'],
      'classId': schedule['classId'] ?? schedules[key]!['classId'],
      'dayOfWeek': schedule['dayOfWeek'] ?? schedules[key]!['dayOfWeek'],
      'startTime': schedule['startTime'] ?? schedules[key]!['startTime'],
      'endTime': schedule['endTime'] ?? schedules[key]!['endTime'],
      'subject': schedule['subject'] ?? schedules[key]!['subject'],
      'room': schedule['room'] ?? schedules[key]!['room'],
      'updatedAt': DateTime.now().toIso8601String(),
    };
    
    await _box.put(SCHEDULES_KEY, schedules);
    
    final professor = await getProfessor(schedules[key]!['professorId']);
    final className = await _getClassName(schedules[key]!['classId']);
    
    await addLog("Horaire modifié: ${professor?['fullName']} - ${schedules[key]!['subject']} ($className)");
  }

  Future<bool> deleteSchedule(int id) async {
    final schedules = _getSchedulesMap();
    final key = id.toString();
    if (!schedules.containsKey(key)) return false;
    
    await _box.put(SCHEDULES_KEY, schedules);
    
    await addLog("Horaire supprimé, clé: $id");
    return true;
  }

  Future<String> _getClassName(int classId) async {
    try {
      final classesBox = await Hive.openBox<ClassModel>(CLASSES_KEY);
      final classModel = classesBox.get(classId);
      return classModel?.className ?? 'Classe inconnue';
    } catch (e) {
      return 'Classe inconnue';
    }
  }

  // ================= PERMISSIONS PROFESSEUR-CLASSES =================
  Map<String, Map<String, dynamic>> _getPermissionsMap() {
    final m = _box.get(PROFESSOR_PERMISSIONS_KEY, defaultValue: {});
    return Map<String, Map<String, dynamic>>.from(
      (m as Map).map((k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map))),
    );
  }

  Future<int> grantClassPermission(int professorId, int classId, {String permissionType = 'view'}) async {
    final permissions = _getPermissionsMap();
    
    final existingKey = _findPermissionKey(professorId, classId);
    if (existingKey != null) {
      final key = existingKey;
      permissions[key] = {
        ...permissions[key]!,
        'permissionType': permissionType,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await _box.put(PROFESSOR_PERMISSIONS_KEY, permissions);
      
      final professor = await getProfessor(professorId);
      final className = await _getClassName(classId);
      await addLog("Permission mise à jour: ${professor?['fullName']} -> $className ($permissionType)");
      
      return int.parse(key);
    }
    
    int lastId = _box.get(LAST_PERMISSION_ID, defaultValue: 0) as int;
    final newId = lastId + 1;
    
    final permission = {
      'id': newId,
      'professorId': professorId,
      'classId': classId,
      'permissionType': permissionType,
      'grantedAt': DateTime.now().toIso8601String(),
    };
    
    permissions[newId.toString()] = permission;
    await _box.put(PROFESSOR_PERMISSIONS_KEY, permissions);
    await _box.put(LAST_PERMISSION_ID, newId);
    
    final professor = await getProfessor(professorId);
    final className = await _getClassName(classId);
    await addLog("Permission accordée: ${professor?['fullName']} -> $className ($permissionType)");
    
    return newId;
  }

  Future<bool> revokeClassPermission(int professorId, int classId) async {
    final permissions = _getPermissionsMap();
    final key = _findPermissionKey(professorId, classId);
    
    if (key == null) return false;
    
    
    await _box.put(PROFESSOR_PERMISSIONS_KEY, permissions);
    
    final professor = await getProfessor(professorId);
    final className = await _getClassName(classId);
    await addLog("Permission retirée: ${professor?['fullName']} -> $className");
    
    return true;
  }

  Future<List<Map<String, dynamic>>> getProfessorPermissions(int professorId) async {
    final permissions = _getPermissionsMap();
    return permissions.values
        .where((p) => p['professorId'] == professorId)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getClassesForProfessor(int professorId) async {
    final permissions = await getProfessorPermissions(professorId);
    final classesBox = await Hive.openBox<ClassModel>(CLASSES_KEY);
    
    List<Map<String, dynamic>> result = [];
    
    for (var permission in permissions) {
      final classModel = classesBox.get(permission['classId']);
      if (classModel != null) {
        result.add({
          'id': classModel.key,
          'className': classModel.className,
          'level': classModel.level,
          'year': classModel.year,
          'permissionType': permission['permissionType'],
          'grantedAt': permission['grantedAt'],
        });
      }
    }
    
    return result;
  }

  Future<List<Map<String, dynamic>>> getProfessorsForClass(int classId) async {
    final permissions = _getPermissionsMap();
    final professors = _getProfessorsMap();
    
    List<Map<String, dynamic>> result = [];
    
    for (var permission in permissions.values) {
      if (permission['classId'] == classId) {
        final professorId = permission['professorId'];
        final professor = professors[professorId.toString()];
        
        if (professor != null) {
          result.add({
            'id': professor['id'],
            'fullName': professor['fullName'],
            'email': professor['email'],
            'specialty': professor['specialty'],
            'permissionType': permission['permissionType'],
            'grantedAt': permission['grantedAt'],
          });
        }
      }
    }
    
    return result;
  }

  Future<bool> hasPermission(int professorId, int classId) async {
    return _findPermissionKey(professorId, classId) != null;
  }

  String? _findPermissionKey(int professorId, int classId) {
    final permissions = _getPermissionsMap();
    for (var entry in permissions.entries) {
      if (entry.value['professorId'] == professorId && 
          entry.value['classId'] == classId) {
        return entry.key;
      }
    }
    return null;
  }

  // ================= CLASSES =================
  Future<int> insertClass(ClassModel c) async {
    // 1. Sauvegarder dans Hive (local)
    final box = await Hive.openBox<ClassModel>(CLASSES_KEY);
    int key = await box.add(c);
    
    // AJOUT: 2. Synchroniser avec Laravel
    bool synced = false;
    try {
      final isConnected = await _apiService.testConnection();
      if (isConnected) {
        final result = await _apiService.createClass({
          'nom': c.className,
          'niveau': c.level,
          'annee_scolaire': c.year,
          'effectif': 0,
        });
        
        if (result['success'] == true) {
          synced = true;
          print('✅ Classe synchronisée avec Laravel: ${c.className}');
        }
      } else {
        print('⚠️ Pas de connexion, classe sauvegardée localement');
      }
    } catch (e) {
      print('❌ Erreur synchronisation classe: $e');
    }
    
    // 3. Marquer comme synchronisé uniquement si réussi
    if (synced) {
      await markAsSynced('class', key);
    }
    
    await addLog("Classe ajoutée: ${c.className}");
    return key;
  }

  Future<Map<int, Map<String, dynamic>>> getAllClassesAsMap() async {
    final box = await Hive.openBox<ClassModel>(CLASSES_KEY);
    final Map<int, Map<String, dynamic>> result = {};
    
    for (var key in box.keys) {
      final classModel = box.get(key);
      if (classModel != null) {
        result[key as int] = {
          'id': key,
          'className': classModel.className,
          'level': classModel.level,
          'year': classModel.year,
        };
      }
    }
    
    return result;
  }

  Future<Box<ClassModel>> getClassBox() async {
    return await Hive.openBox<ClassModel>(CLASSES_KEY);
  }

  Future<List<ClassModel>> getAllClasses() async {
    final box = await Hive.openBox<ClassModel>(CLASSES_KEY);
    return box.values.toList();
  }

  Future<void> updateClass(int key, ClassModel c) async {
    final box = await Hive.openBox<ClassModel>(CLASSES_KEY);
    await box.put(key, c);
    await markAsSynced('class', key);
    await addLog("Classe modifiée: ${c.className}");
    
    // AJOUT: Synchroniser la modification avec Laravel
    try {
      final isConnected = await _apiService.testConnection();
      if (isConnected) {
        await _apiService.updateClass(key, {
          'nom': c.className,
          'niveau': c.level,
          'annee_scolaire': c.year,
        });
        print('✅ Classe mise à jour sur Laravel');
      }
    } catch (e) {
      print('⚠️ Erreur mise à jour classe sur Laravel: $e');
    }
  }

  Future<void> deleteClass(int key) async {
    final box = await Hive.openBox<ClassModel>(CLASSES_KEY);
    
    final permissions = _getPermissionsMap();
    final permissionsToRemove = permissions.entries
        .where((entry) => entry.value['classId'] == key)
        .map((entry) => entry.key)
        .toList();
    
    for (var permissionKey in permissionsToRemove) {
      permissions.remove(permissionKey);
    }
    
    final schedules = _getSchedulesMap();
    final schedulesToRemove = schedules.entries
        .where((entry) => entry.value['classId'] == key)
        .map((entry) => entry.key)
        .toList();
    
    for (var scheduleKey in schedulesToRemove) {
      schedules.remove(scheduleKey);
    }
    
    await _box.put(PROFESSOR_PERMISSIONS_KEY, permissions);
    await _box.put(SCHEDULES_KEY, schedules);
    await box.delete(key);
    await addLog("Classe supprimée, clé: $key");
    
    // AJOUT: Supprimer sur Laravel
    try {
      final isConnected = await _apiService.testConnection();
      if (isConnected) {
        await _apiService.deleteClass(key);
        print('✅ Classe supprimée sur Laravel');
      }
    } catch (e) {
      print('⚠️ Erreur suppression classe sur Laravel: $e');
    }
  }

  // ================= STUDENTS =================
  Future<int> addStudent(StudentModel s) async {
    // 1. Sauvegarder dans Hive
    final box = await Hive.openBox<StudentModel>(STUDENTS_KEY);
    int key = await box.add(s);
    
    // AJOUT: 2. Synchroniser avec Laravel
    try {
      final isConnected = await _apiService.testConnection();
      if (isConnected) {
        await _apiService.createEtudiant({
          'fullName': s.fullName,
          'className': s.className,
          'dateNaissance': s.birthDate,
          'lieuNaissance': s.birthPlace,
          'pere': s.fatherName,
          'mere': s.motherName,
          'telephoneParent': s.parentPhone,
          'adresse': s.address,
        });
        await markAsSynced('student', key);
        print('✅ Étudiant synchronisé avec Laravel: ${s.fullName}');
      } else {
        print('⚠️ Pas de connexion, étudiant sauvegardé localement');
      }
    } catch (e) {
      print('❌ Erreur synchronisation étudiant: $e');
    }
    
    await addLog("Étudiant ajouté: ${s.fullName}");
    return key;
  }

  Future<List<StudentModel>> getAllStudents() async {
    final box = await Hive.openBox<StudentModel>(STUDENTS_KEY);
    return box.values.toList();
  }

  Future<void> updateStudent(int key, StudentModel s) async {
    final box = await Hive.openBox<StudentModel>(STUDENTS_KEY);
    await box.put(key, s);
    await markAsSynced('student', key);
    await addLog("Étudiant modifié: ${s.fullName}");
  }

  Future<void> deleteStudent(int key) async {
    final box = await Hive.openBox<StudentModel>(STUDENTS_KEY);
    await box.delete(key);
    await addLog("Étudiant supprimé, clé: $key");
  }

  Future<StudentModel?> getStudentById(int key) async {
    final box = await Hive.openBox<StudentModel>(STUDENTS_KEY);
    return box.get(key);
  }

  // ================= PAYMENTS =================
  Future<int> addPayment(PaymentModel p) async {
    final box = await Hive.openBox<PaymentModel>(PAYMENTS_KEY);
    int key = await box.add(p);
    await markAsSynced('payment', key);
    await addLog("Paiement ajouté: ${p.fullName}, mois: ${p.month}");
    return key;
  }

  Future<List<PaymentModel>> getAllPayments() async {
    final box = await Hive.openBox<PaymentModel>(PAYMENTS_KEY);
    return box.values.toList();
  }

  Future<List<PaymentModel>> getAllPaymentsForStudent(int studentKeyHive) async {
    final payments = await getAllPayments();
    return payments.where((p) => p.studentKeyHive == studentKeyHive).toList();
  }

  Future<PaymentModel?> checkPreviousMonthPayment(int studentKeyHive, int month, int year) async {
    final payments = await getAllPaymentsForStudent(studentKeyHive);
    return payments.firstWhereOrNull((p) => p.month == month && p.year == year);
  }

  Future<void> updatePayment(int key, PaymentModel p) async {
    final box = await Hive.openBox<PaymentModel>(PAYMENTS_KEY);
    await box.put(key, p);
    await markAsSynced('payment', key);
    await addLog("Paiement modifié: ${p.fullName}, clé: $key");
  }

  Future<void> deletePayment(int key) async {
    final box = await Hive.openBox<PaymentModel>(PAYMENTS_KEY);
    await box.delete(key);
    await addLog("Paiement supprimé, clé: $key");
  }

  // ================= DOCUMENTS =================
  Future<int> addDocument(DocumentModel d) async {
    final box = await Hive.openBox<DocumentModel>(DOCUMENTS_KEY);
    int key = await box.add(d);
    await markAsSynced('document', key);
    await addLog("Document ajouté: ${d.fullName}, type: ${d.docType}");
    return key;
  }

  Future<List<DocumentModel>> getAllDocuments() async {
    final box = await Hive.openBox<DocumentModel>(DOCUMENTS_KEY);
    return box.values.toList();
  }

  Future<void> updateDocument(int key, DocumentModel d) async {
    final box = await Hive.openBox<DocumentModel>(DOCUMENTS_KEY);
    await box.put(key, d);
    await markAsSynced('document', key);
    await addLog("Document modifié, clé: $key");
  }

  Future<void> deleteDocument(int key) async {
    final box = await Hive.openBox<DocumentModel>(DOCUMENTS_KEY);
    await box.delete(key);
    await addLog("Document supprimé, clé: $key");
  }

  // ================= ANNOUNCEMENTS =================
  Future<List<Map<String, dynamic>>> getAllAnnouncements() async {
    final anns = _box.get(ANNOUNCEMENTS_KEY, defaultValue: {});
    return Map<String, Map<String, dynamic>>.from(
      (anns as Map).map((k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map)))
    ).values.toList();
  }

  Future<void> addAnnouncement(Map<String, dynamic> ann) async {
    final anns = _box.get(ANNOUNCEMENTS_KEY, defaultValue: {});
    final annsMap = Map<String, Map<String, dynamic>>.from(
        (anns as Map).map((k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map))));
    int id = annsMap.keys.length + 1;
    ann['id'] = id;
    ann['date'] = DateTime.now().toIso8601String();
    annsMap[id.toString()] = ann;
    await _box.put(ANNOUNCEMENTS_KEY, annsMap);
    await addLog("Admin a publié l'annonce ${ann['title']}");
  }

  Future<Map<String, Map<String, dynamic>>> getAnnouncementsMap() async {
    final anns = _box.get(ANNOUNCEMENTS_KEY, defaultValue: {});
    return Map<String, Map<String, dynamic>>.from(
      (anns as Map).map((k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map)))
    );
  }

  Future<void> updateAnnouncements(Map<String, Map<String, dynamic>> anns) async {
    await _box.put(ANNOUNCEMENTS_KEY, anns);
    await addLog("Admin a modifié des annonces");
  }

  Future<bool> deleteAnnouncement(int id) async {
    final anns = await getAnnouncementsMap();
    if (!anns.containsKey(id.toString())) return false;
    final removed = anns.remove(id.toString());
    await _box.put(ANNOUNCEMENTS_KEY, anns);
    await addLog("Admin a supprimé l'annonce ${removed?['title']}");
    return true;
  }

  // ================= ATTENDANCE =================
  Future<void> addAttendance(AttendanceModel attendance) async {
    final box = await Hive.openBox<AttendanceModel>('attendance');
    int key = await box.add(attendance);
    await markAsSynced('attendance', key);
  }

  Future<List<AttendanceModel>> getAttendanceByClass(String className) async {
    final box = await Hive.openBox<AttendanceModel>('attendance');
    return box.values.where((a) => a.className == className).toList();
  }

  Future<List<AttendanceModel>> getAllAttendances() async {
    try {
      final box = await Hive.openBox<AttendanceModel>('attendance');
      return box.values.toList();
    } catch (e) {
      print('Erreur getAllAttendances: $e');
      return [];
    }
  }

  // ================= GRADES =================
  Future<void> addGrade(GradeModel grade) async {
    final box = await Hive.openBox<GradeModel>('grades');
    int key = await box.add(grade);
    await markAsSynced('grade', key);
  }

  Future<List<GradeModel>> getGradesByStudent(int studentKey) async {
    final box = await Hive.openBox<GradeModel>('grades');
    return box.values.where((g) => g.studentKeyHive == studentKey).toList();
  }

  Future<List<GradeModel>> getAllGrades() async {
    try {
      final box = await Hive.openBox<GradeModel>('grades');
      return box.values.toList();
    } catch (e) {
      print('Erreur getAllGrades: $e');
      return [];
    }
  }

  Future<double> calculateStudentAverage(int studentKey, String subject) async {
    final grades = await getGradesByStudent(studentKey);
    final subjectGrades = grades.where((g) => g.subject == subject).toList();
    
    if (subjectGrades.isEmpty) return 0.0;
    
    double totalWeighted = 0;
    double totalCoefficient = 0;
    
    for (var grade in subjectGrades) {
      totalWeighted += grade.score * grade.coefficient;
      totalCoefficient += grade.coefficient;
    }
    
    return totalWeighted / totalCoefficient;
  }

  // ================= PERMISSIONS ÉTUDIANTS =================
  Future<void> grantStudentPermission(int studentId, String permissionType) async {
    try {
      final Box<Map> permissionsBox = await Hive.openBox<Map>(STUDENT_PERMISSIONS_KEY);
      
      final permission = {
        'studentId': studentId,
        'permissionType': permissionType,
        'grantedAt': DateTime.now().toIso8601String(),
      };
      
      await permissionsBox.add(permission);
      await addLog("Permission $permissionType accordée à l'étudiant $studentId");
    } catch (e) {
      print('Erreur grantStudentPermission: $e');
    }
  }

  Future<bool> revokeStudentPermission(int studentId, String permissionType) async {
    try {
      final Box<Map> permissionsBox = await Hive.openBox<Map>(STUDENT_PERMISSIONS_KEY);
      
      int? keyToDelete;
      
      for (var key in permissionsBox.keys) {
        final perm = permissionsBox.get(key);
        if (perm != null && 
            perm['studentId'] == studentId && 
            perm['permissionType'] == permissionType) {
          keyToDelete = key as int?;
          break;
        }
      }
      
      if (keyToDelete != null) {
        await permissionsBox.delete(keyToDelete);
        await addLog("Permission $permissionType retirée de l'étudiant $studentId");
        return true;
      }
      
      return false;
    } catch (e) {
      print('Erreur revokeStudentPermission: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getStudentPermissions(int studentId) async {
    try {
      final Box<Map> permissionsBox = await Hive.openBox<Map>(STUDENT_PERMISSIONS_KEY);
      
      final List<Map<String, dynamic>> permissions = [];
      
      for (var key in permissionsBox.keys) {
        final perm = permissionsBox.get(key);
        if (perm != null && perm['studentId'] == studentId) {
          permissions.add({
            'key': key,
            ...perm,
          });
        }
      }
      
      return permissions;
    } catch (e) {
      print('Erreur getStudentPermissions: $e');
      return [];
    }
  }

  // ================= PERMISSIONS DE CLASSE POUR ÉTUDIANTS =================
  Future<void> grantStudentClassPermission(int studentId, int classHiveKey, {String permissionType = 'view'}) async {
    try {
      final Box<Map> permissionsBox = await Hive.openBox<Map>(STUDENT_CLASS_PERMISSIONS_KEY);
      
      final permission = {
        'studentId': studentId,
        'classHiveKey': classHiveKey,
        'permissionType': permissionType,
        'grantedAt': DateTime.now().toIso8601String(),
      };
      
      await permissionsBox.add(permission);
      await addLog("Permission de classe $permissionType accordée à l'étudiant $studentId");
    } catch (e) {
      print('Erreur grantStudentClassPermission: $e');
    }
  }

  Future<bool> revokeStudentClassPermission(int studentId, int classHiveKey) async {
    try {
      final Box<Map> permissionsBox = await Hive.openBox<Map>(STUDENT_CLASS_PERMISSIONS_KEY);
      
      int? keyToDelete;
      
      for (var key in permissionsBox.keys) {
        final perm = permissionsBox.get(key);
        if (perm != null && 
            perm['studentId'] == studentId && 
            perm['classHiveKey'] == classHiveKey) {
          keyToDelete = key as int?;
          break;
        }
      }
      
      if (keyToDelete != null) {
        await permissionsBox.delete(keyToDelete);
        await addLog("Permission de classe retirée de l'étudiant $studentId");
        return true;
      }
      
      return false;
    } catch (e) {
      print('Erreur revokeStudentClassPermission: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getStudentClassPermissions(int studentId) async {
    try {
      final Box<Map> permissionsBox = await Hive.openBox<Map>(STUDENT_CLASS_PERMISSIONS_KEY);
      
      final List<Map<String, dynamic>> permissions = [];
      
      for (var key in permissionsBox.keys) {
        final perm = permissionsBox.get(key);
        if (perm != null && perm['studentId'] == studentId) {
          permissions.add({
            'key': key,
            ...perm,
          });
        }
      }
      
      return permissions;
    } catch (e) {
      print('Erreur getStudentClassPermissions: $e');
      return [];
    }
  }

  Future<bool> hasStudentPermission(int studentId, String permissionType) async {
    try {
      final permissions = await getStudentPermissions(studentId);
      return permissions.any((perm) => perm['permissionType'] == permissionType);
    } catch (e) {
      print('Erreur hasStudentPermission: $e');
      return false;
    }
  }

  // ================= SUBJECTS =================
  Future<List<Map<String, dynamic>>> getAllSubjects() async {
    try {
      final subjects = _box.get(SUBJECTS_KEY, defaultValue: <String, Map<String, dynamic>>{});
      final subjectsMap = Map<String, Map<String, dynamic>>.from(
        (subjects as Map).map((k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map)))
      );
      return subjectsMap.values.toList();
    } catch (e) {
      print('Erreur getAllSubjects: $e');
      return [];
    }
  }

  Future<int> addSubject(Map<String, dynamic> subject) async {
    try {
      final subjects = _box.get(SUBJECTS_KEY, defaultValue: <String, Map<String, dynamic>>{});
      final subjectsMap = Map<String, Map<String, dynamic>>.from(
        (subjects as Map).map((k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map)))
      );
      
      int lastId = _box.get(LAST_SUBJECT_ID, defaultValue: 0) as int;
      final newId = lastId + 1;
      
      subject['id'] = newId;
      subjectsMap[newId.toString()] = subject;
      
      await _box.put(SUBJECTS_KEY, subjectsMap);
      await _box.put(LAST_SUBJECT_ID, newId);
      await addLog("Matière ajoutée: ${subject['name']}");
      
      return newId;
    } catch (e) {
      print('Erreur addSubject: $e');
      return -1;
    }
  }

  Future<void> updateSubject(int id, Map<String, dynamic> subject) async {
    try {
      final subjects = _box.get(SUBJECTS_KEY, defaultValue: <String, Map<String, dynamic>>{});
      final subjectsMap = Map<String, Map<String, dynamic>>.from(
        (subjects as Map).map((k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map)))
      );
      
      final key = id.toString();
      if (subjectsMap.containsKey(key)) {
        subject['updatedAt'] = DateTime.now().toIso8601String();
        subjectsMap[key] = subject;
        await _box.put(SUBJECTS_KEY, subjectsMap);
        await addLog("Matière modifiée: ${subject['name']}");
      }
    } catch (e) {
      print('Erreur updateSubject: $e');
    }
  }

  Future<bool> deleteSubject(int id) async {
    try {
      final subjects = _box.get(SUBJECTS_KEY, defaultValue: <String, Map<String, dynamic>>{});
      final subjectsMap = Map<String, Map<String, dynamic>>.from(
        (subjects as Map).map((k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map)))
      );
      
      final key = id.toString();
      if (subjectsMap.containsKey(key)) {
        final removed = subjectsMap.remove(key);
        await _box.put(SUBJECTS_KEY, subjectsMap);
        await addLog("Matière supprimée: ${removed?['name']}");
        return true;
      }
      return false;
    } catch (e) {
      print('Erreur deleteSubject: $e');
      return false;
    }
  }

  // ================= LOGS =================

// lib/services/db_helper.dart

/// Récupérer tous les logs
Future<List<Map<String, dynamic>>> getAllLogs() async {
  try {
    final box = await Hive.openBox<Map>('logs');
    return box.values.toList().cast<Map<String, dynamic>>();
  } catch (e) {
    print('❌ Erreur récupération logs: $e');
    return [];
  }
}

  Future<void> clearLogs() async {
    await _box.put(LOGS_KEY, <String>[]);
    await addLog("Historique effacé par l'administrateur");
  }

  // ================= STATISTIQUES =================
  Future<Map<String, int>> getDashboardStats() async {
    final users = await getAllUsers();
    final classes = await getAllClasses();
    final announcements = await getAllAnnouncements();
    final professors = await getAllProfessors();
    final students = await getAllStudents();
    final payments = await getAllPayments();
    final schedules = await getAllSchedules();
    
    return {
      'totalUsers': users.length,
      'totalClasses': classes.length,
      'totalAnnouncements': announcements.length,
      'totalProfessors': professors.length,
      'totalStudents': students.length,
      'totalPayments': payments.length,
      'totalSchedules': schedules.length,
    };
  }

  // ================= UTILITAIRES =================
  Future<Map<String, dynamic>?> getProfessorByUserId(int userId) async {
    final professors = _getProfessorsMap();
    
    for (var prof in professors.values) {
      if (prof['userId'] == userId) {
        return Map<String, dynamic>.from(prof);
      }
    }
    return null;
  }
  
  // ================= NOTIFICATIONS =================
  static const String NOTIFICATIONS_KEY = 'notifications';

  Future<void> saveNotification(int parentUserId, Map<String, dynamic> message) async {
    try {
      final box = await Hive.openBox<Map>(NOTIFICATIONS_KEY);
      final notification = {
        'parentUserId': parentUserId,
        'message': message,
        'read': false,
        'responded': false,
        'createdAt': DateTime.now().toIso8601String(),
      };
      await box.add(notification);
    } catch (e) {
      print('Erreur saveNotification: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getParentNotifications(int parentUserId) async {
    try {
      final box = await Hive.openBox<Map>(NOTIFICATIONS_KEY);
      final notifications = <Map<String, dynamic>>[];
      
      for (var key in box.keys) {
        final item = box.get(key);
        if (item != null && item['parentUserId'] == parentUserId) {
          notifications.add({
            'key': key,
            ...item,
          });
        }
      }
      
      // Trier par date décroissante
      notifications.sort((a, b) => b['createdAt'].compareTo(a['createdAt']));
      return notifications;
    } catch (e) {
      print('Erreur getParentNotifications: $e');
      return [];
    }
  }

  Future<void> markNotificationAsRead(int key) async {
    try {
      final box = await Hive.openBox<Map>(NOTIFICATIONS_KEY);
      final notification = box.get(key);
      if (notification != null) {
        notification['read'] = true;
        await box.put(key, notification);
      }
    } catch (e) {
      print('Erreur markNotificationAsRead: $e');
    }
  }

  Future<void> markNotificationAsResponded(int key) async {
    try {
      final box = await Hive.openBox<Map>(NOTIFICATIONS_KEY);
      final notification = box.get(key);
      if (notification != null) {
        notification['responded'] = true;
        await box.put(key, notification);
      }
    } catch (e) {
      print('Erreur markNotificationAsResponded: $e');
    }
  }

  Future<void> deleteNotification(int key) async {
    try {
      final box = await Hive.openBox<Map>(NOTIFICATIONS_KEY);
      await box.delete(key);
    } catch (e) {
      print('Erreur deleteNotification: $e');
    }
  }
  
  // ================= HORAIRES AVEC ScheduleModel =================
  Future<int> addScheduleModel(ScheduleModel schedule) async {
    try {
      final box = await Hive.openBox<ScheduleModel>(SCHEDULES_KEY);
      int key = await box.add(schedule);
      await addLog("Horaire ajouté: ${schedule.subject}");
      return key;
    } catch (e) {
      print('Erreur addScheduleModel: $e');
      return -1;
    }
  }

  Future<void> updateScheduleModel(int key, ScheduleModel schedule) async {
    try {
      final box = await Hive.openBox<ScheduleModel>(SCHEDULES_KEY);
      await box.put(key, schedule);
      await addLog("Horaire modifié: ${schedule.subject}");
    } catch (e) {
      print('Erreur updateScheduleModel: $e');
    }
  }

  // ================= ONLINE COURSES =================
  Future<List<OnlineCourseModel>> getOnlineCoursesByProfessor(int professorId) async {
    final box = await getOnlineCoursesBox();
    final allCourses = box.values.toList();
    return allCourses.where((course) => course.professorId == professorId).toList();
  }

  Future<OnlineCourseModel?> getOnlineCourseById(int id) async {
    final box = await getOnlineCoursesBox();
    return box.get(id);
  }

  Future<void> addOnlineCourse(OnlineCourseModel course) async {
    final box = await getOnlineCoursesBox();
    await box.put(course.id, course);
  }

  Future<void> updateOnlineCourse(OnlineCourseModel course) async {
    final box = await getOnlineCoursesBox();
    await box.put(course.id, course);
  }

  Future<void> deleteOnlineCourse(int id) async {
    final box = await getOnlineCoursesBox();
    await box.delete(id);
  }

  Future<Box<OnlineCourseModel>> getOnlineCoursesBox() async {
    return Hive.openBox<OnlineCourseModel>('online_courses');
  }

  // ================= ONLINE EXAMS =================
  Future<List<OnlineExamModel>> getAllOnlineExams() async {
    final box = await Hive.openBox<OnlineExamModel>(ONLINE_EXAMS_KEY);
    return box.values.toList();
  }



  Future<List<ExamResultModel>> getAllExamResults() async {
    final box = await Hive.openBox<ExamResultModel>(EXAM_RESULTS_KEY);
    return box.values.toList();
  }

  Future<List<OnlineCourseModel>> getAllOnlineCourses() async {
    final box = await Hive.openBox<OnlineCourseModel>(ONLINE_COURSES_KEY);
    return box.values.toList();
  }

  Future<void> addOnlineExam(OnlineExamModel exam) async {
    final box = await Hive.openBox<OnlineExamModel>(ONLINE_EXAMS_KEY);
    await box.add(exam);
  }

  // ================= UNIVERSITÉ =================
  // ==================== CONSTANTES POUR UNIVERSITÉ ====================
 Future<void> updateUserById(int id, Map<String, dynamic> user) async {
  try {
    final box = await Hive.openBox<Map>('users');
    
    // Chercher la clé correspondante
    String? foundKey;
    for (var key in box.keys) {
      final existingUser = box.get(key) as Map<String, dynamic>;
      if (existingUser['id'] == id) {
        foundKey = key.toString();
        break;
      }
    }
    
    if (foundKey != null) {
      // Mettre à jour l'utilisateur existant
      final updatedUser = {
        ...user,
        'id': id,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await box.put(foundKey, updatedUser);
      print('✅ Utilisateur mis à jour localement: $id');
    } else {
      // Si non trouvé, ajouter
      await insertUser(user);
    }
  } catch (e) {
    print('❌ Erreur mise à jour utilisateur: $e');
    throw e;
  }
}
  
  // ==================== ÉTABLISSEMENTS ====================
  // Ajoutez ces méthodes dans DBHelper

// lib/services/db_helper.dart

/// ✅ Supprimer un étudiant par sa clé
Future<void> deleteStudentByKey(String key) async {
  try {
    final box = await Hive.openBox<StudentModel>('students');
    await box.delete(key);
    print('🗑️ Étudiant supprimé localement: $key');
  } catch (e) {
    print('❌ Erreur suppression étudiant: $e');
    throw e;
  }
}
Future<GradeModel?> getGradeByKey(int? key) async {
  if (key == null) return null;
  final box = await Hive.openBox<GradeModel>('grades');
  return box.get(key);
}

// Pour PaymentModel
Future<PaymentModel?> getPaymentByKey(int? key) async {
  if (key == null) return null;
  final box = await Hive.openBox<PaymentModel>('payments');
  return box.get(key);
}

// Pour ScheduleModel
Future<ScheduleModel?> getScheduleByKey(int? key) async {
  if (key == null) return null;
  final box = await Hive.openBox<ScheduleModel>('schedules');
  return box.get(key);
}

// Pour MessageModel

Future<StudentModel?> getStudentByKey(dynamic key) async {
  if (key == null) return null;
  final box = await Hive.openBox<StudentModel>('students');
  return box.get(key);
}

// Pour AttendanceModel
Future<AttendanceModel?> getAttendanceByKey(dynamic key) async {
  if (key == null) return null;
  final box = await Hive.openBox<AttendanceModel>('attendances');
  return box.get(key);
}
// Dans db_helper.dart, ajoutez cette méthode :

Future<Map<String, dynamic>?> getUserById(int id) async {
  try {
    final box = await Hive.openBox('users');
    // Parcourir toutes les clés pour trouver l'utilisateur avec l'ID correspondant
    for (var key in box.keys) {
      final user = box.get(key);
      if (user != null && user['id'] == id) {
        return user;
      }
    }
    return null;
  } catch (e) {
    print('Erreur getUserById: $e');
    return null;
  }
}
// Dans db_helper.dart, ajoutez ces méthodes :

// Dans db_helper.dart, ajoutez ces méthodes :

// Pour StaffModel
// db_helper.dart - Version mise à jour avec Hive



  // ==================== CONSTANTES DES BOX ====================


  // ==================== GESTION DU PERSONNEL ====================

  /// Ajouter un membre du personnel
  /// // lib/services/db_helper.dart

/// ✅ Mettre à jour un horaire par sa clé
Future<void> updateScheduleByKey(int key, Map<String, dynamic> schedule) async {
  try {
    final box = await Hive.openBox<Map>('schedules');
    final keyStr = key.toString();
    
    if (box.containsKey(keyStr)) {
      await box.put(keyStr, schedule);
      print('✅ Horaire mis à jour localement: $key');
    } else {
      // Si la clé n'existe pas, ajouter
      await box.put(keyStr, schedule);
      print('✅ Horaire ajouté localement: $key');
    }
  } catch (e) {
    print('❌ Erreur mise à jour horaire: $e');
    throw e;
  }
}

/// ✅ Récupérer un horaire par sa clé




/// ✅ Supprimer un horaire par sa clé
Future<void> deleteScheduleByKey(int key) async {
  try {
    final box = await Hive.openBox<Map>('schedules');
    final keyStr = key.toString();
    await box.delete(keyStr);
    print('🗑️ Horaire supprimé localement: $key');
  } catch (e) {
    print('❌ Erreur suppression horaire: $e');
    throw e;
  }
}

/// ✅ Récupérer tous les horaires

  Future<int> addStaff(StaffModel staff) async {
    try {
      final box = await Hive.openBox<StaffModel>(staffBox);
      final key = await box.add(staff);
      print('✅ Personnel ajouté localement avec ID: $key');
      return key;
    } catch (e) {
      print('❌ Erreur ajout personnel: $e');
      throw e;
    }
  }

  /// Mettre à jour un membre du personnel
  Future<void> updateStaff(int id, StaffModel staff) async {
    try {
      final box = await Hive.openBox<StaffModel>(staffBox);
      await box.put(id, staff);
      print('✅ Personnel mis à jour localement: ID $id');
    } catch (e) {
      print('❌ Erreur mise à jour personnel: $e');
      throw e;
    }
  }

  /// Supprimer un membre du personnel
  Future<void> deleteStaff(int id) async {
    try {
      final box = await Hive.openBox<StaffModel>(staffBox);
      await box.delete(id);
      print('🗑️ Personnel supprimé localement: ID $id');
    } catch (e) {
      print('❌ Erreur suppression personnel: $e');
      throw e;
    }
  }

  /// Récupérer tout le personnel
  Future<List<StaffModel>> getAllStaff() async {
    try {
      final box = await Hive.openBox<StaffModel>(staffBox);
      final staffList = box.values.toList();
      print('📋 Récupération de ${staffList.length} employés');
      return staffList;
    } catch (e) {
      print('❌ Erreur récupération personnel: $e');
      return [];
    }
  }

  /// Récupérer le personnel par école
  /// ✅ MODIFIÉ: schoolId maintenant en String
  Future<List<StaffModel>> getStaffBySchool(String schoolId) async {
    try {
      final box = await Hive.openBox<StaffModel>(staffBox);
      final staffList = box.values
          .where((s) => s.schoolId == schoolId)  // ✅ String comparison
          .toList();
      print('📋 ${staffList.length} employés pour l\'école: $schoolId');
      return staffList;
    } catch (e) {
      print('❌ Erreur récupération personnel par école: $e');
      return [];
    }
  }

  /// Récupérer un personnel par son ID
  Future<StaffModel?> getStaffById(int id) async {
    try {
      final box = await Hive.openBox<StaffModel>(staffBox);
      final staff = box.get(id);
      if (staff != null) {
        print('✅ Personnel trouvé: ${staff.fullName} (ID: $id)');
      } else {
        print('⚠️ Aucun personnel trouvé avec ID: $id');
      }
      return staff;
    } catch (e) {
      print('❌ Erreur récupération personnel par ID: $e');
      return null;
    }
  }

  /// Mettre à jour le Firestore ID d'un personnel
  Future<void> updateStaffFirestoreId(int id, String firestoreId) async {
    try {
      final box = await Hive.openBox<StaffModel>(staffBox);
      final staff = box.get(id);
      if (staff != null) {
        staff.firestoreId = firestoreId;
        await box.put(id, staff);
        print('✅ Firestore ID mis à jour pour personnel ID $id: $firestoreId');
      } else {
        print('⚠️ Personnel non trouvé pour mise à jour Firestore ID: $id');
      }
    } catch (e) {
      print('❌ Erreur mise à jour Firestore ID: $e');
      throw e;
    }
  }

  /// Supprimer tout le personnel d'une école
  Future<void> deleteStaffBySchool(String schoolId) async {
    try {
      final box = await Hive.openBox<StaffModel>(staffBox);
      final keysToDelete = <dynamic>[];
      
      for (var key in box.keys) {
        final staff = box.get(key);
        if (staff != null && staff.schoolId == schoolId) {
          keysToDelete.add(key);
        }
      }
      
      for (var key in keysToDelete) {
        await box.delete(key);
      }
      
      print('🗑️ ${keysToDelete.length} employés supprimés pour l\'école: $schoolId');
    } catch (e) {
      print('❌ Erreur suppression personnel par école: $e');
      throw e;
    }
  }

  /// Vérifier si un personnel existe
  Future<bool> staffExists(String fullName, String position, String schoolId) async {
    try {
      final box = await Hive.openBox<StaffModel>(staffBox);
      final exists = box.values.any((staff) => 
        staff.fullName.toLowerCase() == fullName.toLowerCase() &&
        staff.position == position &&
        staff.schoolId == schoolId
      );
      return exists;
    } catch (e) {
      print('❌ Erreur vérification existence personnel: $e');
      return false;
    }
  }

  /// Compter le nombre de personnel par école
  Future<int> countStaffBySchool(String schoolId) async {
    try {
      final box = await Hive.openBox<StaffModel>(staffBox);
      final count = box.values.where((s) => s.schoolId == schoolId).length;
      return count;
    } catch (e) {
      print('❌ Erreur comptage personnel: $e');
      return 0;
    }
  }

  /// Récupérer le personnel par poste
  Future<List<StaffModel>> getStaffByPosition(String position, String schoolId) async {
    try {
      final box = await Hive.openBox<StaffModel>(staffBox);
      final staffList = box.values
          .where((s) => s.position == position && s.schoolId == schoolId)
          .toList();
      return staffList;
    } catch (e) {
      print('❌ Erreur récupération personnel par poste: $e');
      return [];
    }
  }

  // ==================== GESTION DES PAIEMENTS DU PERSONNEL ====================

 /// Ajouter un paiement pour un personnel
Future<int> addStaffPayment(StaffPaymentModel payment) async {
  try {
    final box = await Hive.openBox<StaffPaymentModel>(_staffPaymentsBox);
    final key = await box.add(payment);
    print('✅ Paiement ajouté: ${payment.netSalary} FCFA pour staff ID ${payment.staffId}');
    return key;
  } catch (e) {
    print('❌ Erreur ajout paiement: $e');
    throw e;
  }
}

/// Récupérer les paiements d'un personnel
Future<List<StaffPaymentModel>> getStaffPaymentsByStaff(int staffId) async {
  try {
    final box = await Hive.openBox<StaffPaymentModel>(_staffPaymentsBox);
    final payments = box.values
        .where((p) => p.staffId == staffId)
        .toList();
    print('📋 ${payments.length} paiements pour staff ID $staffId');
    return payments;
  } catch (e) {
    print('❌ Erreur récupération paiements par staff: $e');
    return [];
  }
}

/// Récupérer tous les paiements du personnel
Future<List<StaffPaymentModel>> getAllStaffPayments() async {
  try {
    final box = await Hive.openBox<StaffPaymentModel>(_staffPaymentsBox);
    final payments = box.values.toList();
    print('📋 ${payments.length} paiements totaux');
    return payments;
  } catch (e) {
    print('❌ Erreur récupération tous les paiements: $e');
    return [];
  }
}

/// Mettre à jour un paiement
Future<void> updateStaffPayment(int id, StaffPaymentModel payment) async {
  try {
    final box = await Hive.openBox<StaffPaymentModel>(_staffPaymentsBox);
    await box.put(id, payment);
    print('✅ Paiement mis à jour: ID $id');
  } catch (e) {
    print('❌ Erreur mise à jour paiement: $e');
    throw e;
  }
}

/// Supprimer un paiement
Future<void> deleteStaffPayment(int id) async {
  try {
    final box = await Hive.openBox<StaffPaymentModel>(_staffPaymentsBox);
    await box.delete(id);
    print('🗑️ Paiement supprimé: ID $id');
  } catch (e) {
    print('❌ Erreur suppression paiement: $e');
    throw e;
  }
}

/// Récupérer les paiements par école
Future<List<StaffPaymentModel>> getStaffPaymentsBySchool(String schoolId) async {
  try {
    final staffBoxInstance = await Hive.openBox<StaffModel>(_staffBox);
    final paymentsBoxInstance = await Hive.openBox<StaffPaymentModel>(_staffPaymentsBox);
    
    // Récupérer tous les staff IDs de l'école
    final staffIds = staffBoxInstance.values
        .where((s) => s.schoolId == schoolId)
        .map((s) => s.id)
        .toList();
    
    // Filtrer les paiements par staff IDs
    final payments = paymentsBoxInstance.values
        .where((p) => staffIds.contains(p.staffId))
        .toList();
    
    print('📋 ${payments.length} paiements pour l\'école: $schoolId');
    return payments;
  } catch (e) {
    print('❌ Erreur récupération paiements par école: $e');
    return [];
  }
}

/// Récupérer les paiements par période
Future<List<StaffPaymentModel>> getStaffPaymentsByDateRange(
  DateTime startDate, 
  DateTime endDate
) async {
  try {
    final box = await Hive.openBox<StaffPaymentModel>(_staffPaymentsBox);
    final payments = box.values
        .where((p) {
          // Convertir paymentDate (String) en DateTime pour la comparaison
          final paymentDateTime = DateTime.tryParse(p.paymentDate);
          if (paymentDateTime == null) return false;
          return paymentDateTime.isAfter(startDate.subtract(const Duration(days: 1))) &&
                 paymentDateTime.isBefore(endDate.add(const Duration(days: 1)));
        })
        .toList();
    print('📋 ${payments.length} paiements entre $startDate et $endDate');
    return payments;
  } catch (e) {
    print('❌ Erreur récupération paiements par date: $e');
    return [];
  }
}

/// Calculer le total des paiements pour un staff
Future<double> getTotalPaymentsByStaff(int staffId) async {
  try {
    final payments = await getStaffPaymentsByStaff(staffId);
    // ✅ Correction: utiliser netSalary au lieu de amount
    final total = payments.fold(0.0, (sum, p) => sum + p.netSalary);
    print('💰 Total des paiements pour staff $staffId: $total FCFA');
    return total;
  } catch (e) {
    print('❌ Erreur calcul total paiements: $e');
    return 0.0;
  }
}

/// Vérifier si un paiement existe déjà pour une période
Future<bool> paymentExistsForPeriod(int staffId, DateTime month) async {
  try {
    final payments = await getStaffPaymentsByStaff(staffId);
    final exists = payments.any((p) {
      // Convertir paymentDate (String) en DateTime
      final paymentDate = DateTime.tryParse(p.paymentDate);
      if (paymentDate == null) return false;
      return paymentDate.year == month.year &&
             paymentDate.month == month.month;
    });
    return exists;
  } catch (e) {
    print('❌ Erreur vérification paiement existant: $e');
    return false;
  }
}

  // ==================== MÉTHODES UTILITAIRES ====================

  /// Fermer toutes les boxes (à appeler avant la fermeture de l'app)
  Future<void> closeAllBoxes() async {
    try {
      await Hive.close();
      print('✅ Toutes les boxes Hive sont fermées');
    } catch (e) {
      print('❌ Erreur fermeture boxes: $e');
    }
  }

  /// Nettoyer les données d'une école (supprimer tout le personnel et leurs paiements)
  Future<void> cleanSchoolData(String schoolId) async {
    try {
      // Supprimer les paiements liés aux staff de l'école
      final staffList = await getStaffBySchool(schoolId);
      final paymentsBox = await Hive.openBox<StaffPaymentModel>(staffPaymentsBox);
      
      for (var staff in staffList) {
        final paymentsToDelete = <dynamic>[];
        for (var key in paymentsBox.keys) {
          final payment = paymentsBox.get(key);
          if (payment != null && payment.staffId == staff.id) {
            paymentsToDelete.add(key);
          }
        }
        for (var key in paymentsToDelete) {
          await paymentsBox.delete(key);
        }
      }
      
      // Supprimer le personnel
      await deleteStaffBySchool(schoolId);
      
      print('✅ Données nettoyées pour l\'école: $schoolId');
    } catch (e) {
      print('❌ Erreur nettoyage données école: $e');
      throw e;
    }
  }



Future<void> updateOnlineExam(OnlineExamModel exam) async {
  final box = await Hive.openBox<OnlineExamModel>('online_exams');
  final key = exam.id;
  await box.put(key, exam);
}

Future<OnlineExamModel?> getOnlineExamById(int id) async {
  final box = await Hive.openBox<OnlineExamModel>('online_exams');
  return box.get(id);
}
// Dans db_helper.dart, ajoutez ces méthodes :

Future<void> addSystemLog(Map<String, dynamic> log) async {
  final box = await Hive.openBox('system_logs');
  await box.add(log);
}

Future<List<Map<String, dynamic>>> getSystemLogs() async {
  final box = await Hive.openBox('system_logs');
  return box.values.cast<Map<String, dynamic>>().toList();
}

Future<void> addSchoolPayment(Map<String, dynamic> payment) async {
  final box = await Hive.openBox('school_payments');
  await box.add(payment);
}

Future<List<Map<String, dynamic>>> getSchoolPayments() async {
  final box = await Hive.openBox('school_payments');
  return box.values.cast<Map<String, dynamic>>().toList();
}

Future<void> deleteOnlineExam(int id) async {
  final box = await Hive.openBox<OnlineExamModel>('online_exams');
  await box.delete(id);
}
// Pour DocumentModel
Future<DocumentModel?> getDocumentByKey(int? key) async {
  if (key == null) return null;
  final box = await Hive.openBox<DocumentModel>('documents');
  return box.get(key);
}

// ==================== ÉTABLISSEMENTS (VERSION UNIFIÉE) ====================

Future<int> addEtablissement(EtablissementModel ecole) async {
  try {
    final box = Hive.box<Map<String, dynamic>>(ETABLISSEMENT_BOX);
    final id = await box.add(ecole.toMap());
    ecole.id = id;
    print('📦 École ajoutée dans Hive avec ID: $id');
    return id;
  } catch (e) {
    print('❌ Erreur addEtablissement: $e');
    throw e;
  }
}

// lib/services/db_helper.dart

// lib/services/db_helper.dart

Future<List<EtablissementModel>> getAllEtablissements() async {
  try {
    // ⚠️ Gardez le même type que dans init()
    final box = Hive.box<Map<String, dynamic>>(ETABLISSEMENT_BOX);
    final List<EtablissementModel> list = [];
    
    for (var key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        // Conversion sécurisée
        final nom = data['nom']?.toString() ?? '';
        final type = data['type']?.toString() ?? 'École';
        final adresse = data['adresse']?.toString();
        final telephone = data['telephone']?.toString();
        final email = data['email']?.toString();
        final siteWeb = data['siteWeb']?.toString();
        final firestoreId = data['firestoreId']?.toString();
        final createdAt = data['createdAt'] != null 
            ? DateTime.tryParse(data['createdAt'].toString()) 
            : null;
        final isActive = data['isActive'] == true;
        final schoolCode = data['schoolCode']?.toString() ?? '';
        
        final school = EtablissementModel(
          id: key as int?,
          nom: nom,
          type: type,
          adresse: adresse,
          telephone: telephone,
          email: email,
          siteWeb: siteWeb,
          firestoreId: firestoreId,
          createdAt: createdAt,
          isActive: isActive,
          schoolCode: schoolCode,
        );
        list.add(school);
      }
    }
    
    print('📚 ${list.length} écoles chargées depuis Hive');
    return list;
  } catch (e) {
    print('❌ Erreur getAllEtablissements: $e');
    return [];
  }
}

Future<EtablissementModel?> getEtablissementById(int id) async {
  try {
    // ⚠️ Même type
    final box = Hive.box<Map<String, dynamic>>(ETABLISSEMENT_BOX);
    final data = box.get(id);
    if (data == null) return null;
    
    return EtablissementModel(
      id: id,
      nom: data['nom']?.toString() ?? '',
      type: data['type']?.toString() ?? 'École',
      adresse: data['adresse']?.toString(),
      telephone: data['telephone']?.toString(),
      email: data['email']?.toString(),
      siteWeb: data['siteWeb']?.toString(),
      firestoreId: data['firestoreId']?.toString(),
      createdAt: data['createdAt'] != null 
          ? DateTime.tryParse(data['createdAt'].toString()) 
          : null,
      isActive: data['isActive'] == true,
      schoolCode: data['schoolCode']?.toString() ?? '',
    );
  } catch (e) {
    print('❌ Erreur getEtablissementById: $e');
    return null;
  }
}
Future<void> updateEtablissement(int id, EtablissementModel school) async {
  try {
    final box = Hive.box<Map<String, dynamic>>(ETABLISSEMENT_BOX);
    await box.put(id, school.toMap());
    print('✅ École mise à jour dans Hive: $id');
  } catch (e) {
    print('❌ Erreur updateEtablissement: $e');
    throw e;
  }
}

Future<void> updateEtablissementFirestoreId(int localId, String firestoreId) async {
  try {
    final box = Hive.box<Map<String, dynamic>>(ETABLISSEMENT_BOX);
    final data = box.get(localId);
    if (data != null) {
      data['firestoreId'] = firestoreId;
      await box.put(localId, data);
      print('✅ Firestore ID mis à jour pour l\'école ID $localId');
    }
  } catch (e) {
    print('❌ Erreur updateEtablissementFirestoreId: $e');
  }
}
Future<EtablissementModel?> getEtablissementByFirestoreId(String firestoreId) async {
  try {
    final box = Hive.box<Map<String, dynamic>>(ETABLISSEMENT_BOX);
    for (var key in box.keys) {
      final data = box.get(key);
      if (data != null && data['firestoreId'] == firestoreId) {
        return EtablissementModel(
          id: key as int?,
          nom: data['nom']?.toString() ?? '',
          type: data['type']?.toString() ?? 'École',
          adresse: data['adresse']?.toString(),
          telephone: data['telephone']?.toString(),
          email: data['email']?.toString(),
          siteWeb: data['siteWeb']?.toString(),
          firestoreId: data['firestoreId']?.toString(),
          createdAt: data['createdAt'] != null ? DateTime.tryParse(data['createdAt'].toString()) : null,
          isActive: data['isActive'] == true,
          schoolCode: data['schoolCode']?.toString() ?? '',
        );
      }
    }
    return null;
  } catch (e) {
    print('❌ Erreur getEtablissementByFirestoreId: $e');
    return null;
  }
}

Future<void> updateEtablissementStatus(int id, bool isActive) async {
  try {
    final box = Hive.box<Map<String, dynamic>>(ETABLISSEMENT_BOX);
    final data = box.get(id);
    if (data != null) {
      data['isActive'] = isActive;
      await box.put(id, data);
      print('✅ Statut école mis à jour: $id -> ${isActive ? "Actif" : "Inactif"}');
    }
  } catch (e) {
    print('❌ Erreur updateEtablissementStatus: $e');
  }
}

Future<void> deleteEtablissement(int id) async {
  try {
    final box = Hive.box<Map<String, dynamic>>(ETABLISSEMENT_BOX);
    await box.delete(id);
    print('🗑️ École supprimée de Hive: $id');
  } catch (e) {
    print('❌ Erreur deleteEtablissement: $e');
  }
}

  
  // ==================== FACULTÉS ====================
  Future<void> addFaculte(FaculteModel f) async {
    final box = await Hive.openBox<FaculteModel>(FACULTES_KEY);
    await box.put(f.id, f);
  }

  Future<List<FaculteModel>> getAllFacultes() async {
    final box = await Hive.openBox<FaculteModel>(FACULTES_KEY);
    return box.values.toList();
  }

  Future<List<FaculteModel>> getFacultesByEtablissement(int etablissementId) async {
    final box = await Hive.openBox<FaculteModel>(FACULTES_KEY);
    return box.values.where((f) => f.etablissementId == etablissementId).toList();
  }

  Future<FaculteModel?> getFaculte(int id) async {
    final box = await Hive.openBox<FaculteModel>(FACULTES_KEY);
    return box.get(id);
  }

  Future<void> updateFaculte(FaculteModel f) async {
    final box = await Hive.openBox<FaculteModel>(FACULTES_KEY);
    await box.put(f.id, f);
  }

  Future<void> deleteFaculte(int id) async {
    final box = await Hive.openBox<FaculteModel>(FACULTES_KEY);
    await box.delete(id);
  }
// Récupérer les utilisateurs par école
Future<List<Map<String, dynamic>>> getUsersBySchool(int schoolId) async {
  final users = _getUsersMap();
  return users.values
      .where((user) => user['schoolId'] == schoolId)
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

// Récupérer les étudiants par école
Future<List<StudentModel>> getStudentsBySchool(int schoolId) async {
  final allStudents = await getAllStudents();
  final users = await getUsersBySchool(schoolId);
  final userIds = users.map((u) => u['id']).toList();
  
  return allStudents.where((s) => 
    userIds.contains(s.userId) || s.schoolId == schoolId
  ).toList();
}

// Récupérer les professeurs par école
Future<List<ProfessorModel>> getProfessorsBySchool(int schoolId) async {
  final allProfessors = await getAllProfessors(); // Cela retourne List<Map<String, dynamic>>
  final users = await getUsersBySchool(schoolId);
  final userIds = users.map((u) => u['id']).toList();
  
  // Convertir les Map en ProfessorModel
  final List<ProfessorModel> result = [];
  
  for (var profMap in allProfessors) {
    final hasMatchingUserId = profMap['userId'] != null && userIds.contains(profMap['userId']);
    final hasMatchingSchoolId = profMap['schoolId'] == schoolId;
    
    if (hasMatchingUserId || hasMatchingSchoolId) {
      // Créer un ProfessorModel à partir de la Map
      final professor = ProfessorModel(
        id: profMap['id'] as int? ?? 0,
        userId: profMap['userId'] as int?,
        fullName: profMap['fullName'] as String? ?? '',
        email: profMap['email'] as String? ?? '',
        phone: profMap['phone'] as String? ?? '',
        specialty: profMap['specialty'] as String? ?? '',
        status: profMap['status'] as String? ?? 'active',
        schoolId: profMap['schoolId'] as int?,
        createdAt: profMap['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      );
      result.add(professor);
    }
  }
  
  return result;
}
// Récupérer les classes par école
Future<List<ClassModel>> getClassesBySchool(String schoolId) async {
  final allClasses = await getAllClasses();
  return allClasses.where((c) => c.schoolId == schoolId).toList();
}
  // ==================== DÉPARTEMENTS ====================
  Future<void> addDepartement(DepartementModel d) async {
    final box = await Hive.openBox<DepartementModel>(DEPARTEMENTS_KEY);
    await box.put(d.id, d);
  }

  Future<List<DepartementModel>> getAllDepartements() async {
    final box = await Hive.openBox<DepartementModel>(DEPARTEMENTS_KEY);
    return box.values.toList();
  }

  Future<List<DepartementModel>> getDepartementsByFaculte(int faculteId) async {
    final box = await Hive.openBox<DepartementModel>(DEPARTEMENTS_KEY);
    return box.values.where((d) => d.faculteId == faculteId).toList();
  }

  Future<DepartementModel?> getDepartement(int id) async {
    final box = await Hive.openBox<DepartementModel>(DEPARTEMENTS_KEY);
    return box.get(id);
  }

  Future<void> updateDepartement(DepartementModel d) async {
    final box = await Hive.openBox<DepartementModel>(DEPARTEMENTS_KEY);
    await box.put(d.id, d);
  }

  Future<void> deleteDepartement(int id) async {
    final box = await Hive.openBox<DepartementModel>(DEPARTEMENTS_KEY);
    await box.delete(id);
  }

  // ==================== NIVEAUX ====================
  Future<void> addNiveau(NiveauModel n) async {
    final box = await Hive.openBox<NiveauModel>(NIVEAUX_KEY);
    await box.put(n.id, n);
  }

  Future<List<NiveauModel>> getAllNiveaux() async {
    final box = await Hive.openBox<NiveauModel>(NIVEAUX_KEY);
    return box.values.toList();
  }

  Future<List<NiveauModel>> getNiveauxByDepartement(int departementId) async {
    final box = await Hive.openBox<NiveauModel>(NIVEAUX_KEY);
    return box.values.where((n) => n.departementId == departementId).toList();
  }

  Future<NiveauModel?> getNiveau(int id) async {
    final box = await Hive.openBox<NiveauModel>(NIVEAUX_KEY);
    return box.get(id);
  }

  Future<void> updateNiveau(NiveauModel n) async {
    final box = await Hive.openBox<NiveauModel>(NIVEAUX_KEY);
    await box.put(n.id, n);
  }

  Future<void> deleteNiveau(int id) async {
    final box = await Hive.openBox<NiveauModel>(NIVEAUX_KEY);
    await box.delete(id);
  }

  // ==================== MODULES ====================
  Future<void> addModule(ModuleModel m) async {
    final box = await Hive.openBox<ModuleModel>(MODULES_KEY);
    await box.put(m.id, m);
  }

  Future<List<ModuleModel>> getAllModules() async {
    final box = await Hive.openBox<ModuleModel>(MODULES_KEY);
    return box.values.toList();
  }

  Future<List<ModuleModel>> getModulesByNiveau(int niveauId) async {
    final box = await Hive.openBox<ModuleModel>(MODULES_KEY);
    return box.values.where((m) => m.niveauId == niveauId).toList();
  }

  Future<ModuleModel?> getModule(int id) async {
    final box = await Hive.openBox<ModuleModel>(MODULES_KEY);
    return box.get(id);
  }

  Future<void> updateModule(ModuleModel m) async {
    final box = await Hive.openBox<ModuleModel>(MODULES_KEY);
    await box.put(m.id, m);
  }

  Future<void> deleteModule(int id) async {
    final box = await Hive.openBox<ModuleModel>(MODULES_KEY);
    await box.delete(id);
  }

  Future<List<ModuleModel>> getModulesByProfessor(int professorId) async {
    final box = await Hive.openBox<ModuleModel>(MODULES_KEY);
    return box.values.where((m) => m.professeurId == professorId).toList();
  }

  // ================= SYNCHRONISATION API =================
  Future<void> markAsSynced(String collection, int id) async {
    final syncBox = await Hive.openBox(SYNC_STATUS_KEY);
    await syncBox.put('$collection:$id', DateTime.now().toIso8601String());
  }
  
  Future<bool> isSynced(String collection, int id) async {
    final syncBox = await Hive.openBox(SYNC_STATUS_KEY);
    return syncBox.containsKey('$collection:$id');
  }
  
  Future<DateTime?> getLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString(LAST_SYNC_KEY);
    if (lastSync != null) {
      return DateTime.parse(lastSync);
    }
    return null;
  }
  
  Future<void> setLastSync(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(LAST_SYNC_KEY, date.toIso8601String());
  }
  
  // Récupérer les données non synchronisées
  Future<List<ClassModel>> getUnsyncedClasses() async {
    final box = await Hive.openBox<ClassModel>(CLASSES_KEY);
    final unsynced = <ClassModel>[];
    
    for (var key in box.keys) {
      final classModel = box.get(key);
      if (classModel != null && !await isSynced('class', key as int)) {
        unsynced.add(classModel);
      }
    }
    return unsynced;
  }

  // AJOUT: Récupérer les étudiants non synchronisés
  Future<List<StudentModel>> getUnsyncedStudents() async {
    final box = await Hive.openBox<StudentModel>(STUDENTS_KEY);
    final unsynced = <StudentModel>[];
    
    for (var key in box.keys) {
      final student = box.get(key);
      if (student != null && !await isSynced('student', key as int)) {
        unsynced.add(student);
      }
    }
    return unsynced;
  }

  // AJOUT: Récupérer les notes non synchronisées
  Future<List<GradeModel>> getUnsyncedGrades() async {
    final box = await Hive.openBox<GradeModel>('grades');
    final unsynced = <GradeModel>[];
    
    for (var key in box.keys) {
      final grade = box.get(key);
      if (grade != null && !await isSynced('grade', key as int)) {
        unsynced.add(grade);
      }
    }
    return unsynced;
  }

  // AJOUT: Récupérer les présences non synchronisées
  Future<List<AttendanceModel>> getUnsyncedAttendances() async {
    final box = await Hive.openBox<AttendanceModel>('attendance');
    final unsynced = <AttendanceModel>[];
    
    for (var key in box.keys) {
      final attendance = box.get(key);
      if (attendance != null && !await isSynced('attendance', key as int)) {
        unsynced.add(attendance);
      }
    }
    return unsynced;
  }

  // AJOUT: Récupérer les paiements non synchronisés
  Future<List<PaymentModel>> getUnsyncedPayments() async {
    final box = await Hive.openBox<PaymentModel>(PAYMENTS_KEY);
    final unsynced = <PaymentModel>[];
    
    for (var key in box.keys) {
      final payment = box.get(key);
      if (payment != null && !await isSynced('payment', key as int)) {
        unsynced.add(payment);
      }
    }
    return unsynced;
  }

  // AJOUT: Synchronisation complète avec le serveur
  Future<Map<String, dynamic>> syncWithServer() async {
    final results = {
      'success': true,
      'pushed': {'success': 0, 'failed': 0},
      'pulled': {'success': 0, 'failed': 0},
      'messages': []
    };
    
    // Vérifier la connexion
    final isConnected = await _apiService.testConnection();
    if (!isConnected) {
      results['success'] = false;
      (results['messages']as List<String>).add('⚠️ Pas de connexion au serveur Laravel');
      return results;
    }
    
    print('🔄 Début de la synchronisation avec Laravel...');
    (results['messages']as List<String>).add('🔄 Début de la synchronisation...');
    
    // 1. PUSH : Envoyer les données locales non synchronisées
    print('📤 Envoi des données locales non synchronisées...');
    
    // Classes non synchronisées
    final unsyncedClasses = await getUnsyncedClasses();
    for (var classModel in unsyncedClasses) {
      try {
        await _apiService.createClass({
          'nom': classModel.className,
          'niveau': classModel.level,
          'annee_scolaire': classModel.year,
        });
        await markAsSynced('class', classModel.key!);
        final pushed = results['pushed'] as Map<String, dynamic>;
        pushed['success'] = (pushed['success'] as int) + 1;
        print('✅ Classe synchronisée: ${classModel.className}');
      } catch (e) {
        final pushed = results['pushed'] as Map<String, dynamic>;
         pushed['failed'] = (pushed['failed'] as int) + 1;
        print('❌ Erreur synchronisation classe: $e');
      }
    }
    // lib/services/db_helper.dart

/// ✅ Supprimer un étudiant par sa clé


/// ✅ Supprimer un étudiant par sa clé Hive

    
    // Étudiants non synchronisés
    // lib/services/db_helper.dart

/// ✅ Marquer un élément comme synchronisé (générique) - À placer AVANT son utilisation
// lib/services/db_helper.dart

/// ✅ Supprimer un étudiant par sa clé


/// ✅ Supprimer un étudiant (alias)


/// ✅ Supprimer un étudiant par son HiveKey



/// ✅ Supprimer tous les étudiants d'une école









    
// Solution correcte :
(results['messages'] as List<String>).add('📤 PUSH terminé: ${(results['pushed'] as Map<String, dynamic>)['success']} succès, ${(results['pushed'] as Map<String, dynamic>)['failed']} échecs');
print('📤 PUSH terminé: ${(results['pushed'] as Map<String, dynamic>)['success']} succès, ${(results['pushed'] as Map<String, dynamic>)['failed']} échecs');
    // 2. PULL : Récupérer les données du serveur
    print('📥 Récupération des données depuis le serveur...');
    (results['messages']as List<String>).add('📥 Récupération des données du serveur...');
    
    try {
      final serverData = await _apiService.pullAllData();
      
      if (serverData['success'] == true) {
        // Synchroniser les classes reçues
        for (var classData in serverData['classes']) {
          try {
            final existingClasses = await getAllClasses();
            final exists = existingClasses.any((c) => c.className == classData['nom']);
            
            if (!exists) {
              final newClass = ClassModel(
                className: classData['nom'],
                level: classData['niveau'],
                year: classData['annee_scolaire'],
              );
              await insertClass(newClass);
              final pulled = results['pulled'] as Map<String, dynamic>;
              pulled['success'] = (pulled['success'] as int) + 1;
            }
          } catch (e) {
            final pulled = results['pulled'] as Map<String, dynamic>;
            pulled['failed'] = (pulled['failed'] as int) + 1;
          }
        }
        
        // Synchroniser les étudiants reçus
        for (var etudiantData in serverData['etudiants']) {
          try {
            final existingStudents = await getAllStudents();
            final exists = existingStudents.any((s) => s.fullName == etudiantData['fullName']);
            
            if (!exists) {
              final newStudent = StudentModel(
                fullName: etudiantData['fullName'],
                className: etudiantData['className'] ?? '',
                birthDate: etudiantData['dateNaissance'] ?? '',
                birthPlace: etudiantData['lieuNaissance'] ?? '',
                fatherName: etudiantData['pere'] ?? '',
                motherName: etudiantData['mere'] ?? '',
                parentPhone: etudiantData['telephoneParent'] ?? '',
                address: etudiantData['adresse'] ?? '',
              );
              await addStudent(newStudent);
              final pulled = results['pulled'] as Map<String, dynamic>;
pulled['success'] = (pulled['success'] as int) + 1;
            }
          } catch (e) {
            final pulled = results['pulled'] as Map<String, dynamic>;
            pulled['failed'] = (pulled['failed'] as int) + 1;
          }
        }
        
// Solution correcte :
(results['messages'] as List<String>).add('📤 PUSH terminé: ${(results['pushed'] as Map<String, dynamic>)['success']} succès, ${(results['pushed'] as Map<String, dynamic>)['failed']} échecs');
print('📤 PUSH terminé: ${(results['pushed'] as Map<String, dynamic>)['success']} succès, ${(results['pushed'] as Map<String, dynamic>)['failed']} échecs');      }
    } catch (e) {
      final pulled = results['pulled'] as Map<String, dynamic>;
      pulled['failed'] = (pulled['failed'] as int) + 1;
      (results['messages'] as List<String>).add('❌ Erreur PULL: $e');
    }
    
    // Mettre à jour la date de dernière synchronisation
    await setLastSync(DateTime.now());
    
    (results['messages'] as List<String>).add('✅ Synchronisation terminée !');
    print('✅ Synchronisation terminée !');
    
    return results;
  }
  // ================= MESSAGES PROFESSEUR =================
Future<List<Map<String, dynamic>>> getMessagesForProfessor(int professorId) async {
  try {
    final box = await Hive.openBox<Map>(NOTIFICATIONS_KEY);
    final messages = <Map<String, dynamic>>[];
    
    for (var key in box.keys) {
      final item = box.get(key);
      if (item != null && item['professorId'] == professorId) {
        messages.add({
          'key': key,
          ...item,
        });
      }
    }
    
    messages.sort((a, b) => b['createdAt'].compareTo(a['createdAt']));
    return messages;
  } catch (e) {
    print('Erreur getMessagesForProfessor: $e');
    return [];
  }
}
Future<Box<StudentModel>> getStudentsBox() async {
  return await Hive.openBox<StudentModel>(STUDENTS_KEY);
}
// Récupérer tous les messages (tous rôles confondus)
Future<Box<MessageModel>> getMessageBox() async =>
    await Hive.openBox<MessageModel>('messages');

Future<Box<NotificationModel>> getNotificationBox() async =>
    await Hive.openBox<NotificationModel>('notifications');



// Marquer un message comme lu
Future<void> markMessageAsRead(int messageKey) async {
  final box = await getMessageBox();
  final message = box.get(messageKey);
  if (message != null && !message.read) {
    message.read = true;
    await box.put(messageKey, message); // Correction : utiliser put
  }
}

// Marquer une notification comme lue


// Répondre à une notification d'absence
Future<void> respondToAbsence(int notificationKey, String justification) async {
  // 1. Mettre à jour la notification
  final notifBox = await getNotificationBox();
  final notif = notifBox.get(notificationKey);
  if (notif != null && notif.type == 'absence') {
    notif.responded = true;
    await notifBox.put(notificationKey, notif); // Correction : utiliser put
  }

  // 2. Créer un message pour l'administration
  final adminUser = await getAdminUserForStudent(notif?.studentName ?? '');
  if (adminUser != null) {
    final replyMessage = MessageModel(
      senderName: 'Parent',
      senderRole: 'parent',
      recipientName: adminUser['name'],
      recipientRole: 'admin',
      studentName: notif?.studentName ?? '',
      subject: 'Justificatif d\'absence',
      content: justification,
      date: DateTime.now(),
      read: false,
      important: false,
    );
    await addMessage(replyMessage);
  }
}

// Ajouter un message

// Ajouter un message (envoyé par le parent ou reçu)


// Récupérer l'utilisateur administrateur / enseignant responsable d'un élève
// (À adapter selon votre logique métier)
Future<Map<String, dynamic>?> getAdminUserForStudent(String studentName) async {
  // Exemple : chercher le professeur principal de la classe de l'élève
  // Ici, on retourne un admin fictif pour l'exemple
  final users = await getAllUsers();
  return users.firstWhere(
    (u) => u['role'] == 'admin' || u['role'] == 'super_admin',
    orElse: () => {} ,
  );
}
// lib/services/db_helper.dart

/// Mettre à jour une présence existante
Future<void> updateAttendance(AttendanceModel attendance) async {
  try {
    final box = await Hive.openBox<AttendanceModel>('attendances');
    await box.put(attendance.key, attendance);
    print('✅ Présence mise à jour localement: ${attendance.key}');
  } catch (e) {
    print('❌ Erreur mise à jour présence: $e');
    throw e;
  }
}

/// Mettre à jour une présence par sa clé
Future<void> updateAttendanceByKey(String key, AttendanceModel attendance) async {
  try {
    final box = await Hive.openBox<AttendanceModel>('attendances');
    await box.put(key, attendance);
    print('✅ Présence mise à jour par clé: $key');
  } catch (e) {
    print('❌ Erreur mise à jour présence par clé: $e');
    throw e;
  }
}
// lib/services/db_helper.dart

/// Supprimer un document par sa clé
Future<void> deleteDocumentByKey(String key) async {
  try {
    final box = await Hive.openBox<DocumentModel>('documents');
    await box.delete(key);
    print('🗑️ Document supprimé localement: $key');
  } catch (e) {
    print('❌ Erreur suppression document: $e');
    throw e;
  }
}

/// Supprimer un document par sa clé Hive
Future<void> deleteDocumentByKeyHive(int keyHive) async {
  try {
    final box = await Hive.openBox<DocumentModel>('documents');
    // Chercher le document avec cette clé Hive
    final keys = box.keys.where((k) {
      final doc = box.get(k);
      return doc?.keyHive == keyHive;
    }).toList();
    
    for (var key in keys) {
      await box.delete(key);
    }
    print('🗑️ Document(s) supprimé(s) avec keyHive: $keyHive');
  } catch (e) {
    print('❌ Erreur suppression document par keyHive: $e');
    throw e;
  }
}
// lib/services/db_helper.dart

/// Supprimer un paiement par sa clé
Future<void> deletePaymentByKey(String key) async {
  try {
    final box = await Hive.openBox<PaymentModel>('payments');
    await box.delete(key);
    print('🗑️ Paiement supprimé localement: $key');
  } catch (e) {
    print('❌ Erreur suppression paiement: $e');
    throw e;
  }
}

/// Supprimer un paiement par sa clé Hive
Future<void> deletePaymentByKeyHive(int keyHive) async {
  try {
    final box = await Hive.openBox<PaymentModel>('payments');
    final keys = box.keys.where((k) {
      final payment = box.get(k);
      return payment?.studentKeyHive == keyHive;
    }).toList();
    
    for (var key in keys) {
      await box.delete(key);
    }
    print('🗑️ Paiement(s) supprimé(s) avec studentKeyHive: $keyHive');
  } catch (e) {
    print('❌ Erreur suppression paiement par keyHive: $e');
    throw e;
  }
}
// lib/services/db_helper.dart

// ==================== GESTION DES PROFESSEURS ====================

/// Récupérer tous les professeurs

// lib/services/db_helper.dart

// ==================== GESTION DES NOTES ====================

/// Supprimer une note par sa clé
Future<void> deleteGradeByKey(String key) async {
  try {
    final box = await Hive.openBox<GradeModel>('grades');
    await box.delete(key);
    print('🗑️ Note supprimée localement: $key');
  } catch (e) {
    print('❌ Erreur suppression note: $e');
    throw e;
  }
}

/// Supprimer une note par sa clé Hive
Future<void> deleteGradeByKeyHive(int keyHive) async {
  try {
    final box = await Hive.openBox<GradeModel>('grades');
    final keys = box.keys.where((k) {
      final grade = box.get(k);
      return grade?.studentKeyHive == keyHive;
    }).toList();
    
    for (var key in keys) {
      await box.delete(key);
    }
    print('🗑️ Note(s) supprimée(s) avec studentKeyHive: $keyHive');
  } catch (e) {
    print('❌ Erreur suppression note par keyHive: $e');
    throw e;
  }
}
// lib/services/db_helper.dart

// ==================== GESTION DES MESSAGES ====================

/// Récupérer tous les messages


/// Récupérer un message par sa clé


/// Récupérer les messages d'un destinataire
Future<List<MessageModel>> getMessagesByRecipient(String recipientName) async {
  try {
    final box = await Hive.openBox<MessageModel>('messages');
    return box.values.where((m) => m.recipientName == recipientName).toList();
  } catch (e) {
    print('❌ Erreur récupération messages par destinataire: $e');
    return [];
  }
}

/// Récupérer les messages non lus d'un destinataire
Future<List<MessageModel>> getUnreadMessagesByRecipient(String recipientName) async {
  try {
    final box = await Hive.openBox<MessageModel>('messages');
    return box.values
        .where((m) => m.recipientName == recipientName && !m.read)
        .toList();
  } catch (e) {
    print('❌ Erreur récupération messages non lus: $e');
    return [];
  }
}

/// Ajouter un message


/// Mettre à jour un message

/// ✅ Mettre à jour le statut de lecture d'un message


/// ✅ Mettre à jour le statut important d'un message
Future<void> updateMessageImportantStatus(String key, bool important) async {
  try {
    final box = await Hive.openBox<MessageModel>('messages');
    final message = box.get(key);
    if (message != null) {
      // Créer une nouvelle instance avec le statut mis à jour
      final updatedMessage = MessageModel(
        senderName: message.senderName,
        senderRole: message.senderRole,
        recipientName: message.recipientName,
        recipientRole: message.recipientRole,
        studentName: message.studentName,
        subject: message.subject,
        content: message.content,
        date: message.date,
        read: message.read,
        important: important,
        firestoreId: message.firestoreId,
        replyTo: message.replyTo,
        schoolFirestoreId: message.schoolFirestoreId,
        studentId: message.studentId,
        messageFirestoreId: message.messageFirestoreId,
        localKey: message.localKey,
        schoolId: message.schoolId,
        readAt: message.readAt,
        senderId: message.senderId,
        recipientId: message.recipientId,
      );
      await box.put(key, updatedMessage);
      print('📌 Statut important mis à jour: $key -> ${important ? "important" : "normal"}');
    }
  } catch (e) {
    print('❌ Erreur mise à jour statut important: $e');
    throw e;
  }
}

/// ✅ Supprimer un message par sa clé
Future<void> deleteMessageByKey(String key) async {
  try {
    final box = await Hive.openBox<MessageModel>('messages');
    await box.delete(key);
    print('🗑️ Message supprimé localement: $key');
  } catch (e) {
    print('❌ Erreur suppression message: $e');
    throw e;
  }
}

/// Supprimer un message (alias)


/// Supprimer tous les messages d'un destinataire
Future<void> deleteMessagesByRecipient(String recipientName) async {
  try {
    final box = await Hive.openBox<MessageModel>('messages');
    final keys = box.keys.where((k) {
      final message = box.get(k);
      return message?.recipientName == recipientName;
    }).toList();
    
    for (var key in keys) {
      await box.delete(key);
    }
    print('🗑️ Messages supprimés pour le destinataire: $recipientName');
  } catch (e) {
    print('❌ Erreur suppression messages par destinataire: $e');
    throw e;
  }
}

/// Supprimer tous les messages


/// Compter les messages
Future<int> countMessages() async {
  try {
    final box = await Hive.openBox<MessageModel>('messages');
    return box.length;
  } catch (e) {
    print('❌ Erreur comptage messages: $e');
    return 0;
  }
}

/// Compter les messages non lus
Future<int> countUnreadMessages() async {
  try {
    final box = await Hive.openBox<MessageModel>('messages');
    return box.values.where((m) => !m.read).length;
  } catch (e) {
    print('❌ Erreur comptage messages non lus: $e');
    return 0;
  }
}

/// Compter les messages non lus par destinataire
Future<int> countUnreadMessagesByRecipient(String recipientName) async {
  try {
    final box = await Hive.openBox<MessageModel>('messages');
    return box.values
        .where((m) => m.recipientName == recipientName && !m.read)
        .length;
  } catch (e) {
    print('❌ Erreur comptage messages non lus par destinataire: $e');
    return 0;
  }
}
/// Récupérer un professeur par son ID local
Future<Map<String, dynamic>?> getProfessorByLocalId(int localId) async {
  try {
    final box = await Hive.openBox<Map>('professors');
    // Chercher par localId
    for (var key in box.keys) {
      final professor = box.get(key) as Map<String, dynamic>;
      if (professor['id'] == localId) {
        return professor;
      }
    }
    return null;
  } catch (e) {
    print('❌ Erreur récupération professeur par localId: $e');
    return null;
  }
}

/// Récupérer un professeur par son ID Firestore
Future<Map<String, dynamic>?> getProfessorByFirestoreId(String firestoreId) async {
  try {
    final box = await Hive.openBox<Map>('professors');
    for (var key in box.keys) {
      final professor = box.get(key) as Map<String, dynamic>;
      if (professor['firestoreId'] == firestoreId) {
        return professor;
      }
    }
    return null;
  } catch (e) {
    print('❌ Erreur récupération professeur par firestoreId: $e');
    return null;
  }
}

/// Ajouter un professeur



/// Mettre à jour un professeur par son ID local
Future<void> updateProfessorByLocalId(int localId, Map<String, dynamic> professor) async {
  try {
    final box = await Hive.openBox<Map>('professors');
    // Trouver la clé correspondante
    String? foundKey;
    for (var key in box.keys) {
      final existing = box.get(key) as Map<String, dynamic>;
      if (existing['id'] == localId) {
        foundKey = key.toString();
        break;
      }
    }
    
    if (foundKey != null) {
      await box.put(foundKey, professor);
      print('✅ Professeur mis à jour localement: ${professor['fullName']}');
    } else {
      // Si non trouvé, ajouter
      await addProfessor(professor);
    }
  } catch (e) {
    print('❌ Erreur mise à jour professeur: $e');
    throw e;
  }
}
// lib/services/db_helper.dart

// ==================== GESTION DES RÉSULTATS D'EXAMEN ====================



/// Récupérer un résultat d'examen par ses clés (examId + studentId)



/// ✅ Récupérer tous les résultats d'un examen (avec int)
Future<List<ExamResultModel>> getExamResultsByExamId(int examId) async {
  try {
    final box = await Hive.openBox<ExamResultModel>('exam_results');
    final results = box.values.where((r) => r.examId == examId).toList();
    print('📥 ${results.length} résultats trouvés pour l\'examen $examId');
    return results;
  } catch (e) {
    print('❌ Erreur récupération résultats: $e');
    return [];
  }
}

/// ✅ Récupérer tous les résultats d'un étudiant (avec int)
Future<List<ExamResultModel>> getExamResultsByStudentId(int studentId) async {
  try {
    final box = await Hive.openBox<ExamResultModel>('exam_results');
    final results = box.values.where((r) => r.studentId == studentId).toList();
    print('📥 ${results.length} résultats trouvés pour l\'étudiant $studentId');
    return results;
  } catch (e) {
    print('❌ Erreur récupération résultats étudiant: $e');
    return [];
  }
}



/// ✅ Supprimer un résultat par sa clé
Future<void> deleteExamResultByKey(String key) async {
  try {
    final box = await Hive.openBox<ExamResultModel>('exam_results');
    await box.delete(key);
    print('🗑️ Résultat examen supprimé: $key');
  } catch (e) {
    print('❌ Erreur suppression résultat: $e');
    throw e;
  }
}

/// ✅ Supprimer tous les résultats d'un examen (avec int)
Future<void> deleteExamResultsByExamId(int examId) async {
  try {
    final box = await Hive.openBox<ExamResultModel>('exam_results');
    final keys = <String>[];
    
    for (var key in box.keys) {
      final result = box.get(key);
      if (result != null && result.examId == examId) {
        keys.add(key.toString());
      }
    }
    
    for (var key in keys) {
      await box.delete(key);
    }
    print('🗑️ ${keys.length} résultats supprimés pour l\'examen: $examId');
  } catch (e) {
    print('❌ Erreur suppression résultats par examen: $e');
    throw e;
  }
}
/// Ajouter un résultat d'examen


// lib/services/db_helper.dart

/// ✅ Mettre à jour un résultat d'examen




/// Supprimer tous les résultats d'un étudiant
Future<void> deleteExamResultsByStudentId(String studentId) async {
  try {
    final box = await Hive.openBox<ExamResultModel>('exam_results');
    final keys = box.keys.where((key) {
      final result = box.get(key);
      return result?.studentId == studentId;
    }).toList();
    for (var key in keys) {
      await box.delete(key);
    }
    print('🗑️ Résultats supprimés pour l\'étudiant: $studentId');
  } catch (e) {
    print('❌ Erreur suppression résultats par étudiant: $e');
    throw e;
  }
}
/// Mettre à jour un professeur par son ID Firestore
Future<void> updateProfessorByFirestoreId(String firestoreId, Map<String, dynamic> professor) async {
  try {
    final box = await Hive.openBox<Map>('professors');
    // Trouver la clé correspondante
    String? foundKey;
    for (var key in box.keys) {
      final existing = box.get(key) as Map<String, dynamic>;
      if (existing['firestoreId'] == firestoreId) {
        foundKey = key.toString();
        break;
      }
    }
    
    if (foundKey != null) {
      await box.put(foundKey, professor);
      print('✅ Professeur mis à jour localement: ${professor['fullName']}');
    } else {
      await addProfessor(professor);
    }
  } catch (e) {
    print('❌ Erreur mise à jour professeur: $e');
    throw e;
  }
}

/// Supprimer un professeur par son ID local
Future<void> deleteProfessorByLocalId(int localId) async {
  try {
    final box = await Hive.openBox<Map>('professors');
    String? foundKey;
    for (var key in box.keys) {
      final professor = box.get(key) as Map<String, dynamic>;
      if (professor['id'] == localId) {
        foundKey = key.toString();
        break;
      }
    }
    
    if (foundKey != null) {
      await box.delete(foundKey);
      print('🗑️ Professeur supprimé localement: $localId');
    }
  } catch (e) {
    print('❌ Erreur suppression professeur: $e');
    throw e;
  }
}

/// Supprimer un professeur par son ID Firestore
Future<void> deleteProfessorByFirestoreId(String firestoreId) async {
  try {
    final box = await Hive.openBox<Map>('professors');
    String? foundKey;
    for (var key in box.keys) {
      final professor = box.get(key) as Map<String, dynamic>;
      if (professor['firestoreId'] == firestoreId) {
        foundKey = key.toString();
        break;
      }
    }
    
    if (foundKey != null) {
      await box.delete(foundKey);
      print('🗑️ Professeur supprimé localement: $firestoreId');
    }
  } catch (e) {
    print('❌ Erreur suppression professeur: $e');
    throw e;
  }
}

/// Supprimer tous les professeurs
Future<void> deleteAllProfessors() async {
  try {
    final box = await Hive.openBox<Map>('professors');
    await box.clear();
    print('🗑️ Tous les professeurs supprimés localement');
  } catch (e) {
    print('❌ Erreur suppression tous les professeurs: $e');
    throw e;
  }
}

/// Compter les professeurs
Future<int> countProfessors() async {
  try {
    final box = await Hive.openBox<Map>('professors');
    return box.length;
  } catch (e) {
    print('❌ Erreur comptage professeurs: $e');
    return 0;
  }
}

/// Récupérer les professeurs par statut
Future<List<Map<String, dynamic>>> getProfessorsByStatus(String status) async {
  try {
    final box = await Hive.openBox<Map>('professors');
    return box.values
        .where((prof) => prof['status'] == status)
        .toList()
        .cast<Map<String, dynamic>>();
  } catch (e) {
    print('❌ Erreur récupération professeurs par statut: $e');
    return [];
  }
}

/// Récupérer les professeurs par spécialité
Future<List<Map<String, dynamic>>> getProfessorsBySpecialty(String specialty) async {
  try {
    final box = await Hive.openBox<Map>('professors');
    return box.values
        .where((prof) => prof['specialty'] == specialty)
        .toList()
        .cast<Map<String, dynamic>>();
  } catch (e) {
    print('❌ Erreur récupération professeurs par spécialité: $e');
    return [];
  }
}

/// Récupérer les professeurs titulaires
Future<List<Map<String, dynamic>>> getHomeroomProfessors() async {
  try {
    final box = await Hive.openBox<Map>('professors');
    return box.values
        .where((prof) => prof['isHomeroomTeacher'] == true)
        .toList()
        .cast<Map<String, dynamic>>();
  } catch (e) {
    print('❌ Erreur récupération professeurs titulaires: $e');
    return [];
  }
}
}