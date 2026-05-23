// lib/services/notification_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  
  String? _token;
  bool _isInitialized = false;

  /// Initialiser les notifications
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Configuration pour Android
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Configuration pour iOS
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(settings);
    
    // Demander la permission
    await _firebaseMessaging.requestPermission();
    
    // Récupérer le token FCM
    _token = await _firebaseMessaging.getToken();
    print('📱 FCM Token: $_token');
    
    // Sauvegarder le token dans Firestore
    await _saveTokenToFirestore();
    
    // Écouter les messages en premier plan
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Écouter les messages quand l'app est en arrière-plan
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
    
    _isInitialized = true;
  }
  
  /// Sauvegarder le token dans Firestore
  Future<void> _saveTokenToFirestore() async {
    final auth = FirebaseAuth.instance.currentUser;
    if (auth != null && _token != null) {
      await FirebaseFirestore.instance.collection('users').doc(auth.uid).update({
        'fcmToken': _token,
        'lastActive': FieldValue.serverTimestamp(),
      });
    }
  }
  
  /// Gérer les messages en premier plan
  void _handleForegroundMessage(RemoteMessage message) {
    print('📨 Message reçu en premier plan: ${message.notification?.title}');
    
    final title = message.notification?.title ?? 'Nouveau message';
    final body = message.notification?.body ?? '';
    
    // Afficher la notification locale
    _showLocalNotification(title, body, message.data);
  }
  
  /// Gérer les messages en arrière-plan
  @pragma('vm:entry-point')
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('📨 Message reçu en arrière-plan: ${message.notification?.title}');
  }
  
  /// Afficher une notification locale
  Future<void> _showLocalNotification(String title, String body, Map<String, dynamic> data) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'messages_channel',
      'Messages',
      channelDescription: 'Notifications des messages',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: data.toString(),
    );
  }
  
  /// Envoyer une notification à un utilisateur
  Future<void> sendNotificationToUser(String userId, String title, String body, {Map<String, dynamic>? data}) async {
    try {
      // Récupérer le token FCM de l'utilisateur
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final token = userDoc.data()?['fcmToken'];
      
      if (token != null && token.isNotEmpty) {
        // Envoyer via Firebase Cloud Messaging
        // Note: Vous devez implémenter un Cloud Function ou un serveur backend
        print('📤 Envoi de notification à $userId: $title');
        
        // Ici vous appelleriez votre backend ou Firebase Cloud Function
        await _sendViaCloudFunction(userId, token, title, body, data);
      }
    } catch (e) {
      print('❌ Erreur envoi notification: $e');
    }
  }
  
  /// Envoyer via Cloud Function (à implémenter)
  Future<void> _sendViaCloudFunction(String userId, String token, String title, String body, Map<String, dynamic>? data) async {
    // Option 1: Appeler une Cloud Function Firebase
    // final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('sendNotification');
    // await callable.call({
    //   'token': token,
    //   'title': title,
    //   'body': body,
    //   'data': data,
    // });
    
    // Option 2: Appeler votre backend
    // Option 3: Utiliser un service comme OneSignal
  }
  
  /// Envoyer une notification pour un nouveau message
  Future<void> notifyNewMessage(String recipientId, String senderName, String messageContent) async {
    await sendNotificationToUser(
      recipientId,
      'Nouveau message de $senderName',
      messageContent.length > 100 ? '${messageContent.substring(0, 100)}...' : messageContent,
      data: {
        'type': 'message',
        'senderName': senderName,
      },
    );
  }
  
  /// Envoyer une notification pour une nouvelle note
  Future<void> notifyNewGrade(String studentId, String subject, double score, double maxScore) async {
    await sendNotificationToUser(
      studentId,
      'Nouvelle note en $subject',
      'Vous avez obtenu ${score.toStringAsFixed(1)}/${maxScore.toStringAsFixed(0)}',
      data: {
        'type': 'grade',
        'subject': subject,
      },
    );
  }
  
  /// Envoyer une notification pour une absence
  Future<void> notifyAbsence(String parentId, String studentName, String date) async {
    await sendNotificationToUser(
      parentId,
      'Absence signalée',
      'Votre enfant $studentName était absent le $date',
      data: {
        'type': 'attendance',
        'studentName': studentName,
      },
    );
  }
  
  /// Envoyer une notification pour un nouvel examen
  Future<void> notifyNewExam(String studentId, String examTitle, DateTime startDate) async {
    final formattedDate = '${startDate.day}/${startDate.month}/${startDate.year} à ${startDate.hour}:${startDate.minute.toString().padLeft(2, '0')}';
    await sendNotificationToUser(
      studentId,
      'Nouvel examen: $examTitle',
      'Début le $formattedDate',
      data: {
        'type': 'exam',
        'examTitle': examTitle,
      },
    );
  }
  
  /// Envoyer une notification à tous les étudiants d'une classe
  Future<void> notifyClass(String className, String title, String body, {Map<String, dynamic>? data}) async {
    final studentsSnapshot = await FirebaseFirestore.instance
        .collection('students')
        .where('className', isEqualTo: className)
        .get();
    
    for (var doc in studentsSnapshot.docs) {
      final studentData = doc.data();
      final parentId = studentData['parentUserId'];
      final studentId = doc.id;
      
      if (parentId != null) {
        await sendNotificationToUser(parentId, title, body, data: data);
      }
      await sendNotificationToUser(studentId, title, body, data: data);
    }
  }
}