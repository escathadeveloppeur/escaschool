// lib/services/notification_trigger.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class NotificationTrigger {
  static final NotificationTrigger _instance = NotificationTrigger._internal();
  factory NotificationTrigger() => _instance;
  NotificationTrigger._internal();

  /// Écouter les nouveaux messages dans Firestore
  void listenToNewMessages() {
    FirebaseFirestore.instance
        .collection('messages')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            _onNewMessage(data);
          }
        }
      }
    });
  }

  /// Écouter les nouvelles notes
  void listenToNewGrades() {
    FirebaseFirestore.instance
        .collection('grades')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            _onNewGrade(data);
          }
        }
      }
    });
  }

  /// Écouter les nouvelles absences
  void listenToNewAttendances() {
    FirebaseFirestore.instance
        .collection('attendances')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null && data['status'] == 'absent') {
            _onNewAbsence(data);
          }
        }
      }
    });
  }

  /// Écouter les nouveaux examens
  void listenToNewExams() {
    FirebaseFirestore.instance
        .collection('online_exams')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            _onNewExam(data);
          }
        }
      }
    });
  }

  void _onNewMessage(Map<String, dynamic> data) async {
    final recipientId = data['recipientId'];
    final senderName = data['senderName'] ?? 'Quelqu\'un';
    final content = data['content'] ?? '';
    
    if (recipientId != null) {
      await NotificationService().notifyNewMessage(
        recipientId,
        senderName,
        content,
      );
      print('📨 Notification message envoyée à $recipientId');
    }
  }

  void _onNewGrade(Map<String, dynamic> data) async {
    final studentName = data['studentName'];
    final subject = data['subject'];
    final score = (data['score'] as num?)?.toDouble() ?? 0;
    final maxScore = (data['maxScore'] as num?)?.toDouble() ?? 20;
    
    if (studentName == null) return;
    
    // Récupérer l'ID de l'étudiant
    final studentQuery = await FirebaseFirestore.instance
        .collection('students')
        .where('fullName', isEqualTo: studentName)
        .limit(1)
        .get();
    
    if (studentQuery.docs.isNotEmpty) {
      final studentId = studentQuery.docs.first.id;
      final parentId = studentQuery.docs.first.data()['parentUserId'];
      
      await NotificationService().notifyNewGrade(studentId, subject, score, maxScore);
      print('📝 Notification note envoyée à $studentId');
      
      if (parentId != null) {
        await NotificationService().notifyNewGrade(parentId, subject, score, maxScore);
        print('📝 Notification note envoyée au parent $parentId');
      }
    }
  }

  void _onNewAbsence(Map<String, dynamic> data) async {
    final studentName = data['studentName'];
    final date = data['date'] != null 
        ? (data['date'] as Timestamp).toDate() 
        : DateTime.now();
    
    if (studentName == null) return;
    
    final studentQuery = await FirebaseFirestore.instance
        .collection('students')
        .where('fullName', isEqualTo: studentName)
        .limit(1)
        .get();
    
    if (studentQuery.docs.isNotEmpty) {
      final parentId = studentQuery.docs.first.data()['parentUserId'];
      if (parentId != null) {
        await NotificationService().notifyAbsence(
          parentId,
          studentName,
          '${date.day}/${date.month}/${date.year}',
        );
        print('⚠️ Notification absence envoyée au parent $parentId');
      }
    }
  }

  void _onNewExam(Map<String, dynamic> data) async {
    final className = data['className'];
    final examTitle = data['title'];
    final startDate = data['startDate'] != null 
        ? (data['startDate'] as Timestamp).toDate() 
        : DateTime.now();
    
    if (className == null) return;
    
    final students = await FirebaseFirestore.instance
        .collection('students')
        .where('className', isEqualTo: className)
        .get();
    
    for (var student in students.docs) {
      final studentId = student.id;
      final parentId = student.data()['parentUserId'];
      
      await NotificationService().notifyNewExam(studentId, examTitle, startDate);
      print('📚 Notification examen envoyée à $studentId');
      
      if (parentId != null) {
        await NotificationService().notifyNewExam(parentId, examTitle, startDate);
        print('📚 Notification examen envoyée au parent $parentId');
      }
    }
  }

  /// Démarrer tous les listeners (à appeler une seule fois dans main)
  void startAllListeners() {
    listenToNewMessages();
    listenToNewGrades();
    listenToNewAttendances();
    listenToNewExams();
    print('✅ Tous les écouteurs de notifications sont actifs');
  }
}