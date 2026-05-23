// lib/services/sync_service.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'class_service.dart';
import 'professor_service.dart';
import 'announcement_service.dart';
import 'schedule_service.dart';
import 'school_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _uuid = const Uuid();
  
  bool _isSyncing = false;
  Timer? _autoSyncTimer;
  
  // Écouteurs de changements en temps réel
  final Map<String, StreamSubscription<QuerySnapshot>> _listeners = {};

  // ==================== CONFIGURATION ====================
  
  static const int DEFAULT_SYNC_INTERVAL_MINUTES = 5;
  static const String SYNC_QUEUE_BOX = 'sync_queue';
  static const String LAST_SYNC_KEY = 'last_sync_timestamp';
  
  // ==================== CONNECTIVITÉ ====================
  
  /// Vérifier si une connexion internet est disponible
  Future<bool> hasInternet() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnection = connectivityResult != ConnectivityResult.none;
      print('🌐 Connectivité: ${hasConnection ? "Connecté" : "Non connecté"}');
      return hasConnection;
    } catch (e) {
      print('❌ Erreur vérification connexion: $e');
      return false;
    }
  }
  
  /// Écouter les changements de connectivité
  Stream<ConnectivityResult> get connectivityStream {
    return Connectivity().onConnectivityChanged.map((event) => event.first);
  }
  
  // ==================== INITIALISATION ====================
  
  /// Démarrer la synchronisation automatique
  void startAutoSync({int intervalMinutes = DEFAULT_SYNC_INTERVAL_MINUTES}) {
    print('🚀 SyncService: Démarrage auto-sync toutes les $intervalMinutes minutes');
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (timer) async {
        print('⏰ SyncService: Timer auto-sync déclenché');
        if (await hasInternet() && !_isSyncing) {
          await syncPendingData();
        } else {
          print('⚠️ SyncService: Auto-sync ignoré (pas internet ou déjà en cours)');
        }
      },
    );
    print('✅ Synchronisation automatique démarrée (intervalle: $intervalMinutes min)');
  }
  
  /// Arrêter la synchronisation automatique
  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
    print('🛑 Synchronisation automatique arrêtée');
  }
  
  /// Démarrer les écouteurs Firebase pour toutes les collections
  void startRealtimeListeners({required String schoolId}) {
    print('🎧 Démarrage des écouteurs temps réel pour école: $schoolId');
    _startCollectionListener('students', schoolId);
    _startCollectionListener('payments', schoolId);
    _startCollectionListener('documents', schoolId);
    _startCollectionListener('attendances', schoolId);
    _startCollectionListener('users', schoolId);
    _startCollectionListener('classes', schoolId);
    _startCollectionListener('professors', schoolId);
    _startCollectionListener('announcements', schoolId);
    _startCollectionListener('schedules', schoolId);
    print('✅ Écouteurs temps réel démarrés pour 9 collections');
  }
  
  /// Arrêter tous les écouteurs
  void stopAllListeners() {
    print('🛑 Arrêt de tous les écouteurs Firebase (${_listeners.length} actifs)');
    for (var subscription in _listeners.values) {
      subscription.cancel();
    }
    _listeners.clear();
    print('🛑 Tous les écouteurs Firebase arrêtés');
  }
  
  /// Démarrer un écouteur pour une collection spécifique
  void _startCollectionListener(String collection, String schoolId) {
    if (_listeners.containsKey(collection)) {
      print('⚠️ Écouteur déjà existant pour: $collection');
      return;
    }
    
    print('🎧 Démarrage écouteur pour: $collection (schoolId: $schoolId)');
    
    final subscription = _firestore
        .collection(collection)
        .where('schoolId', isEqualTo: schoolId)
        .snapshots()
        .listen((snapshot) {
          print('📡 Changement détecté dans $collection: ${snapshot.docs.length} documents');
          _handleFirestoreChanges(collection, snapshot);
        }, onError: (error) {
          print('❌ Erreur écouteur $collection: $error');
        });
    
    _listeners[collection] = subscription;
    print('🎧 Écouteur démarré pour: $collection');
  }
  
  // ==================== GESTION DES CHANGEMENTS ====================
  
  /// Gérer les changements provenant de Firestore
  void _handleFirestoreChanges(String collection, QuerySnapshot snapshot) {
    print('🔄 Traitement des changements pour $collection: ${snapshot.docChanges.length} modifications');
    
    for (var change in snapshot.docChanges) {
      final data = change.doc.data() as Map<String, dynamic>;
      final docId = change.doc.id;
      
      switch (change.type) {
        case DocumentChangeType.added:
          print('📥 Document ajouté dans $collection: $docId');
          _processRemoteAddition(collection, docId, data);
          break;
        case DocumentChangeType.modified:
          print('📝 Document modifié dans $collection: $docId');
          _processRemoteUpdate(collection, docId, data);
          break;
        case DocumentChangeType.removed:
          print('🗑️ Document supprimé dans $collection: $docId');
          _processRemoteDeletion(collection, docId);
          break;
      }
    }
  }
  
  /// Traiter l'ajout d'un document depuis Firestore
  Future<void> _processRemoteAddition(String collection, String docId, Map<String, dynamic> data) async {
    try {
      print('📥 Traitement ajout distant: $collection/$docId');
      final localBox = await _getLocalBox(collection);
      final existingData = localBox.get(docId);
      
      if (existingData == null) {
        await localBox.put(docId, data);
        print('✅ Document ajouté localement: $collection/$docId');
      } else {
        final remoteTimestamp = data['lastUpdated'] as Timestamp?;
        final localTimestamp = existingData['lastUpdated'] as Timestamp?;
        
        if (remoteTimestamp != null && 
            (localTimestamp == null || remoteTimestamp.compareTo(localTimestamp) > 0)) {
          await localBox.put(docId, data);
          print('🔄 Document mis à jour localement: $collection/$docId');
        } else {
          print('⏭️ Document local plus récent, ignore mise à jour: $collection/$docId');
        }
      }
    } catch (e) {
      print('❌ Erreur traitement ajout distant: $e');
    }
  }
  
  /// Traiter la modification d'un document depuis Firestore
  Future<void> _processRemoteUpdate(String collection, String docId, Map<String, dynamic> data) async {
    try {
      print('📝 Traitement modification distante: $collection/$docId');
      final localBox = await _getLocalBox(collection);
      final localData = localBox.get(docId);
      
      if (localData != null) {
        final remoteTimestamp = data['lastUpdated'] as Timestamp?;
        final localTimestamp = localData['lastUpdated'] as Timestamp?;
        
        if (remoteTimestamp != null && 
            (localTimestamp == null || remoteTimestamp.compareTo(localTimestamp) > 0)) {
          await localBox.put(docId, data);
          print('🔄 Document modifié localement: $collection/$docId');
        } else {
          print('⏭️ Document local plus récent, ignore modification: $collection/$docId');
        }
      } else {
        await localBox.put(docId, data);
        print('✅ Document ajouté localement (modification): $collection/$docId');
      }
    } catch (e) {
      print('❌ Erreur traitement modification distante: $e');
    }
  }
  
  /// Traiter la suppression d'un document depuis Firestore
  Future<void> _processRemoteDeletion(String collection, String docId) async {
    try {
      print('🗑️ Traitement suppression distante: $collection/$docId');
      final localBox = await _getLocalBox(collection);
      await localBox.delete(docId);
      print('🗑️ Document supprimé localement: $collection/$docId');
    } catch (e) {
      print('❌ Erreur traitement suppression distante: $e');
    }
  }
  
  // ==================== SYNCHRONISATION LOCALE -> CLOUD ====================
  
  /// Synchroniser un document vers Firestore
  Future<void> syncToFirestore({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
    required String schoolId,
  }) async {
    print('☁️ Tentative sync vers Firestore: $collection/$docId');
    
    if (!await hasInternet()) {
      print('⚠️ Pas de connexion, mise en file d\'attente: $collection/$docId');
      await _queueForSync(collection, docId, data);
      return;
    }
    
    final user = _auth.currentUser;
    if (user == null) {
      print('⚠️ Utilisateur non connecté, mise en file d\'attente: $collection/$docId');
      await _queueForSync(collection, docId, data);
      return;
    }
    
    try {
      final syncData = {
        ...data,
        'schoolId': schoolId,
        'userId': user.uid,
        'lastUpdated': FieldValue.serverTimestamp(),
        'syncStatus': 'synced',
      };
      
      await _firestore
          .collection(collection)
          .doc(docId)
          .set(syncData, SetOptions(merge: true));
      
      await _removeFromQueue(collection, docId);
      
      print('☁️ Document synchronisé vers Firestore: $collection/$docId');
    } catch (e) {
      print('❌ Erreur synchronisation $collection/$docId: $e');
      await _queueForSync(collection, docId, data);
    }
  }
  
  /// Mettre à jour un document existant dans Firestore
  Future<void> updateInFirestore({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    print('☁️ Mise à jour Firestore: $collection/$docId');
    
    if (!await hasInternet()) {
      print('⚠️ Pas de connexion, impossible de mettre à jour');
      throw Exception('Pas de connexion');
    }
    
    try {
      final updateData = {
        ...data,
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      
      await _firestore.collection(collection).doc(docId).update(updateData);
      print('☁️ Document mis à jour dans Firestore: $collection/$docId');
    } catch (e) {
      print('❌ Erreur mise à jour Firestore: $e');
      throw e;
    }
  }
  
  /// Supprimer un document de Firestore
  Future<void> deleteFromFirestore({
    required String collection,
    required String docId,
  }) async {
    print('🗑️ Suppression Firestore: $collection/$docId');
    
    if (!await hasInternet()) {
      print('⚠️ Pas de connexion, impossible de supprimer');
      throw Exception('Pas de connexion');
    }
    
    try {
      await _firestore.collection(collection).doc(docId).delete();
      print('🗑️ Document supprimé de Firestore: $collection/$docId');
    } catch (e) {
      print('❌ Erreur suppression Firestore: $e');
    }
  }
  
  // ==================== SYNCHRONISATION CLOUD -> LOCAL ====================
  
  /// Synchroniser toutes les données depuis Firestore
  Future<void> syncFromFirestore({
    required String collection,
    required String schoolId,
  }) async {
    print('📥 Début sync depuis Firestore: $collection');
    
    if (!await hasInternet()) {
      print('⚠️ Pas de connexion, sync impossible');
      return;
    }
    
    try {
      final snapshot = await _firestore
          .collection(collection)
          .where('schoolId', isEqualTo: schoolId)
          .get();
      
      print('📥 ${snapshot.docs.length} documents trouvés dans $collection');
      
      final localBox = await _getLocalBox(collection);
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        await localBox.put(doc.id, data);
      }
      
      print('✅ Synchronisation $collection terminée: ${snapshot.docs.length} documents');
    } catch (e) {
      print('❌ Erreur synchronisation $collection depuis Firestore: $e');
    }
  }
  
  /// Synchronisation complète depuis Firestore
  Future<void> fullSyncFromFirestore({required String schoolId}) async {
    print('🔄 DÉBUT SYNCHRONISATION COMPLÈTE depuis Firestore');
    print('📋 École ID: $schoolId');

    if (!await hasInternet()) {
      print('⚠️ Pas de connexion internet, synchronisation impossible');
      return;
    }

    // 1. Synchroniser les écoles
    final schoolService = SchoolService();
    await schoolService.syncAllSchoolsToFirestore();
    await schoolService.syncSchoolsFromFirestoreToLocal();

    // 2. Synchroniser les classes
    final classService = ClassService();
    await classService.syncAllClassesToFirestore(schoolId);

    // 3. Synchroniser les professeurs
    final professorService = ProfessorService();
    await professorService.syncAllProfessorsToFirestore(schoolId);

    // 4. Synchroniser les annonces
    final announcementService = AnnouncementService();
    await announcementService.syncAllAnnouncementsToFirestore(schoolId);

    // 5. Synchroniser les horaires
    final scheduleService = ScheduleService();
    await scheduleService.syncAllSchedulesToFirestore(schoolId);

    // 6. Synchroniser depuis Firestore vers local
    final collections = ['students', 'payments', 'documents', 'attendances', 'users', 'classes', 'professors', 'announcements', 'schedules'];
    
    for (var collection in collections) {
      await syncFromFirestore(collection: collection, schoolId: schoolId);
    }

    await _updateLastSyncTimestamp();
    print('✅ SYNCHRONISATION COMPLÈTE TERMINÉE');
  }
  
  // ==================== FILE D'ATTENTE ====================
  
  /// Ajouter un document à la file d'attente de synchronisation
  Future<void> _queueForSync(String collection, String docId, Map<String, dynamic> data) async {
    try {
      print('⏳ Mise en file d\'attente: $collection/$docId');
      final queueBox = await Hive.openBox(SYNC_QUEUE_BOX);
      final queueKey = '$collection-$docId';
      
      await queueBox.put(queueKey, {
        'collection': collection,
        'docId': docId,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
        'retryCount': 0,
      });
      
      print('⏳ Document mis en file d\'attente: $collection/$docId');
    } catch (e) {
      print('❌ Erreur mise en file d\'attente: $e');
    }
  }
  
  /// Supprimer un document de la file d'attente
  Future<void> _removeFromQueue(String collection, String docId) async {
    try {
      final queueBox = await Hive.openBox(SYNC_QUEUE_BOX);
      final queueKey = '$collection-$docId';
      await queueBox.delete(queueKey);
      print('🗑️ Document retiré de la file d\'attente: $collection/$docId');
    } catch (e) {
      print('❌ Erreur suppression file d\'attente: $e');
    }
  }
  
  /// Synchroniser tous les documents en attente
  Future<void> syncPendingData() async {
    if (_isSyncing) {
      print('⚠️ Synchronisation déjà en cours...');
      return;
    }
    
    if (!await hasInternet()) {
      print('⚠️ Pas de connexion internet');
      return;
    }
    
    _isSyncing = true;
    print('🔄 Début synchronisation des données en attente');
    
    try {
      final queueBox = await Hive.openBox(SYNC_QUEUE_BOX);
      final pendingKeys = queueBox.keys.toList();
      
      if (pendingKeys.isEmpty) {
        print('📭 Aucune donnée en attente');
        return;
      }
      
      print('🔄 Synchronisation de ${pendingKeys.length} éléments...');
      
      for (var key in pendingKeys) {
        final pending = queueBox.get(key);
        
        if (pending != null) {
          final retryCount = pending['retryCount'] ?? 0;
          
          if (retryCount > 3) {
            print('⚠️ Abandon sync après 3 tentatives: ${pending['collection']}/${pending['docId']}');
            await queueBox.delete(key);
            continue;
          }
          
          try {
            print('🔄 Tentative ${retryCount + 1}/3: ${pending['collection']}/${pending['docId']}');
            await syncToFirestore(
              collection: pending['collection'],
              docId: pending['docId'],
              data: pending['data'],
              schoolId: pending['data']['schoolId'] ?? '',
            );
          } catch (e) {
            pending['retryCount'] = retryCount + 1;
            await queueBox.put(key, pending);
            print('❌ Échec sync (tentative ${retryCount + 1}/3): ${pending['collection']}/${pending['docId']}');
          }
        }
      }
      
      print('✅ Synchronisation des données en attente terminée');
    } catch (e) {
      print('❌ Erreur synchronisation: $e');
    } finally {
      _isSyncing = false;
    }
  }
  
  // ==================== UTILITAIRES ====================
  
  /// Obtenir la boîte Hive correspondant à une collection
  Future<Box<Map<String, dynamic>>> _getLocalBox(String collection) async {
    print('📦 Ouverture boîte Hive: $collection');
    return await Hive.openBox<Map<String, dynamic>>(collection);
  }
  
  /// Sauvegarder l'horodatage de la dernière synchronisation
  Future<void> _updateLastSyncTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = DateTime.now().toIso8601String();
    await prefs.setString(LAST_SYNC_KEY, timestamp);
    print('💾 Dernière synchronisation sauvegardée: $timestamp');
  }
  
  /// Obtenir l'horodatage de la dernière synchronisation
  Future<DateTime?> getLastSyncTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString(LAST_SYNC_KEY);
    print('📅 Dernière synchronisation: ${timestamp ?? "Jamais"}');
    return timestamp != null ? DateTime.parse(timestamp) : null;
  }
  
  /// Vérifier si une synchronisation est nécessaire
  Future<bool> isSyncNeeded({Duration maxAge = const Duration(hours: 1)}) async {
    final lastSync = await getLastSyncTimestamp();
    if (lastSync == null) {
      print('🔄 Sync nécessaire: jamais synchronisé');
      return true;
    }
    final diff = DateTime.now().difference(lastSync);
    final needed = diff > maxAge;
    print('🔄 Sync ${needed ? "nécessaire" : "pas nécessaire"} (dernière sync: ${diff.inMinutes} minutes)');
    return needed;
  }
  
  /// Forcer une synchronisation manuelle
  Future<void> forceSync({required String schoolId}) async {
    print('💪 SYNCHRONISATION FORCÉE DEMANDÉE');
    await fullSyncFromFirestore(schoolId: schoolId);
    await syncPendingData();
    print('✅ SYNCHRONISATION FORCÉE TERMINÉE');
  }
  
  /// Obtenir le nombre d'éléments en attente
  Future<int> getPendingSyncCount() async {
    try {
      final queueBox = await Hive.openBox(SYNC_QUEUE_BOX);
      final count = queueBox.length;
      print('📊 Éléments en attente: $count');
      return count;
    } catch (e) {
      print('❌ Erreur comptage file attente: $e');
      return 0;
    }
  }
  
  /// Nettoyer la file d'attente
  Future<void> clearPendingQueue() async {
    try {
      final queueBox = await Hive.openBox(SYNC_QUEUE_BOX);
      final count = queueBox.length;
      await queueBox.clear();
      print('🧹 File d\'attente vidée ($count éléments supprimés)');
    } catch (e) {
      print('❌ Erreur vidage file d\'attente: $e');
    }
  }
  
  /// Vérifier l'état de la connexion Firebase
  Future<bool> isFirebaseConnected() async {
    print('🔍 Vérification connexion Firebase...');
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('⚠️ Firebase: Aucun utilisateur connecté');
        return false;
      }
      
      await _firestore.collection('test').limit(1).get();
      print('✅ Firebase connecté (utilisateur: ${user.email})');
      return true;
    } catch (e) {
      print('❌ Firebase non connecté: $e');
      return false;
    }
  }
}

// ==================== MODÈLE POUR LA SYNCHRONISATION ====================

class SyncableModel {
  final String id;
  final String schoolId;
  final DateTime lastUpdated;
  final String? userId;
  final String syncStatus;
  
  SyncableModel({
    required this.id,
    required this.schoolId,
    required this.lastUpdated,
    this.userId,
    this.syncStatus = 'synced',
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'schoolId': schoolId,
      'lastUpdated': lastUpdated.toIso8601String(),
      'userId': userId,
      'syncStatus': syncStatus,
    };
  }
  
  factory SyncableModel.fromJson(Map<String, dynamic> json) {
    return SyncableModel(
      id: json['id'],
      schoolId: json['schoolId'],
      lastUpdated: DateTime.parse(json['lastUpdated']),
      userId: json['userId'],
      syncStatus: json['syncStatus'] ?? 'synced',
    );
  }
}