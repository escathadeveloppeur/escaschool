// lib/services/notification_trigger.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

class NotificationTrigger {
  static final NotificationTrigger _instance = NotificationTrigger._internal();
  factory NotificationTrigger() => _instance;
  NotificationTrigger._internal();

  bool _isStarted = false;

  /// Écouter les nouveaux messages dans Firestore
  void listenToNewMessages() {
    if (kIsWeb) return; // Désactivé sur web
    
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
    }, onError: (error) {
      print('⚠️ Erreur écoute messages: $error');
    });
  }

  /// Écouter les nouvelles notes
  void listenToNewGrades() {
    if (kIsWeb) return; // Désactivé sur web
    
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
    }, onError: (error) {
      print('⚠️ Erreur écoute notes: $error');
    });
  }

  /// Écouter les nouvelles absences
  void listenToNewAttendances() {
    if (kIsWeb) return; // Désactivé sur web
    
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
    }, onError: (error) {
      print('⚠️ Erreur écoute absences: $error');
    });
  }

  /// Écouter les nouveaux examens
  void listenToNewExams() {
    if (kIsWeb) return; // Désactivé sur web
    
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
    }, onError: (error) {
      print('⚠️ Erreur écoute examens: $error');
    });
  }

  void _onNewMessage(Map<String, dynamic> data) async {
    try {
      final recipientId = data['recipientId'];
      final senderName = data['senderName'] ?? 'Quelqu\'un';
      final content = data['content'] ?? '';
      
      if (recipientId != null && recipientId.isNotEmpty) {
        await NotificationService().notifyNewMessage(
          recipientId,
          senderName,
          content,
        );
        print('📨 Notification message envoyée à $recipientId');
      }
    } catch (e) {
      print('⚠️ Erreur traitement nouveau message: $e');
    }
  }

  void _onNewGrade(Map<String, dynamic> data) async {
    try {
      final studentName = data['studentName'];
      final subject = data['subject'];
      final score = (data['score'] as num?)?.toDouble() ?? 0;
      final maxScore = (data['maxScore'] as num?)?.toDouble() ?? 20;
      
      if (studentName == null || subject == null) return;
      
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
        
        if (parentId != null && parentId.isNotEmpty) {
          await NotificationService().notifyNewGrade(parentId, subject, score, maxScore);
          print('📝 Notification note envoyée au parent $parentId');
        }
      }
    } catch (e) {
      print('⚠️ Erreur traitement nouvelle note: $e');
    }
  }

  void _onNewAbsence(Map<String, dynamic> data) async {
    try {
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
        if (parentId != null && parentId.isNotEmpty) {
          await NotificationService().notifyAbsence(
            parentId,
            studentName,
            '${date.day}/${date.month}/${date.year}',
          );
          print('⚠️ Notification absence envoyée au parent $parentId');
        }
      }
    } catch (e) {
      print('⚠️ Erreur traitement nouvelle absence: $e');
    }
  }

  void _onNewExam(Map<String, dynamic> data) async {
    try {
      final className = data['className'];
      final examTitle = data['title'];
      final startDate = data['startDate'] != null 
          ? (data['startDate'] as Timestamp).toDate() 
          : DateTime.now();
      
      if (className == null || examTitle == null) return;
      
      final students = await FirebaseFirestore.instance
          .collection('students')
          .where('className', isEqualTo: className)
          .get();
      
      for (var student in students.docs) {
        final studentId = student.id;
        final parentId = student.data()['parentUserId'];
        
        await NotificationService().notifyNewExam(studentId, examTitle, startDate);
        print('📚 Notification examen envoyée à $studentId');
        
        if (parentId != null && parentId.isNotEmpty) {
          await NotificationService().notifyNewExam(parentId, examTitle, startDate);
          print('📚 Notification examen envoyée au parent $parentId');
        }
      }
    } catch (e) {
      print('⚠️ Erreur traitement nouvel examen: $e');
    }
  }

  /// Démarrer tous les listeners (à appeler une seule fois dans main)
  void startAllListeners() {
    if (_isStarted) {
      print('ℹ️ Les écouteurs sont déjà actifs');
      return;
    }
    
    if (kIsWeb) {
      print('⚠️ [WEB] Les notifications push sont désactivées sur le web');
      return;
    }
    
    listenToNewMessages();
    listenToNewGrades();
    listenToNewAttendances();
    listenToNewExams();
    
    _isStarted = true;
    print('✅ Tous les écouteurs de notifications sont actifs (mobile uniquement)');
  }
  
  /// Arrêter tous les listeners (optionnel)
  void stopAllListeners() {
    _isStarted = false;
    print('⏹️ Écouteurs de notifications arrêtés');
  }
}