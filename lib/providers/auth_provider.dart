import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../services/db_helper.dart';
import '../services/sync_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  final DBHelper _db = DBHelper();
  final SyncService _syncService = SyncService();
  
  // Firebase instances
  final firebase.FirebaseAuth _firebaseAuth = firebase.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // État Firebase
  firebase.User? _firebaseUser;
  bool _isFirebaseConnected = false;
  
  String? _schoolName;
  String? get schoolName => _schoolName;

  // ================= GETTERS =================
  User? get user => _user;
  bool get isLoading => _isLoading;
  firebase.User? get firebaseUser => _firebaseUser;
  bool get isFirebaseConnected => _isFirebaseConnected;
  
  // Getters pour les informations de l'utilisateur
  int? get currentSchoolId => _user?.schoolId;
  bool get isSuperAdmin => _user?.role == 'super_admin';
  bool get isSchoolAdmin => _user?.role == 'admin';
  bool get isTeacher => _user?.role == 'teacher';
  bool get isStudent => _user?.role == 'student';
  bool get isParent => _user?.role == 'parent';
  bool get hasSchool => _user?.schoolId != null;
  String get userRole => _user?.role ?? 'unknown';

  // ================= CONSTRUCTEUR =================
  
  /// Constructeur avec initialisation automatique
  AuthProvider() {
    _autoInit();
  }
  
  /// Initialisation automatique au chargement du provider
  Future<void> _autoInit() async {
    _isLoading = true;
    notifyListeners();
    
    // Vérifier si un utilisateur Firebase est déjà connecté
    _firebaseUser = _firebaseAuth.currentUser;
    _isFirebaseConnected = _firebaseUser != null;
    
    if (_firebaseUser != null) {
      await _loadUserFromFirestore(_firebaseUser!.uid);
    }
    
    _isLoading = false;
    notifyListeners();
  }

  // ================= INITIALISATION MANUELLE =================
  
  /// Initialisation manuelle (si nécessaire)
  Future<void> init() async {
    await _autoInit();
  }

  // ================= LOGIN AVEC FIREBASE =================
  
  /// Connexion avec email et mot de passe (Firebase + Hive local)
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // 1. Connexion avec Firebase Authentication
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      _firebaseUser = userCredential.user;
      _isFirebaseConnected = true;
      
      // 2. Récupérer les données utilisateur depuis Firestore
      await _loadUserFromFirestore(_firebaseUser!.uid);
      
      // 3. Vérifier aussi dans Hive local (fallback)
      final localUserData = await _db.getUserByEmail(email);
      if (localUserData != null && _user == null) {
        _user = User(
          id: localUserData['id'] as int? ?? 0,
          firestoreId: localUserData['firestoreId'] as String?,
          name: localUserData['name'] as String? ?? '',
          email: localUserData['email'] as String? ?? '',
          role: localUserData['role'] as String? ?? 'student',
          password: localUserData['password'] as String? ?? '',
          schoolId: localUserData['schoolId'] as int?,
          firebaseUid: _firebaseUser!.uid,
        );
      }
      
      // 4. Si l'utilisateur appartient à une école, synchroniser les données
      if (_user?.schoolId != null) {
        await _syncService.fullSyncFromFirestore(schoolId: _user!.schoolId.toString());
        _syncService.startRealtimeListeners(schoolId: _user!.schoolId.toString());
        _syncService.startAutoSync();
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
      
    } on firebase.FirebaseAuthException catch (e) {
      print('❌ Firebase Auth erreur: ${e.message}');
      
      // Fallback: essayer la connexion locale Hive
      try {
        final userData = await _db.getUserByEmail(email);
        if (userData != null && userData['password'] == password) {
          _user = User(
            id: userData['id'] as int? ?? 0,
            firestoreId: userData['firestoreId'] as String?,
            name: userData['name'] as String? ?? '',
            email: userData['email'] as String? ?? '',
            role: userData['role'] as String? ?? 'student',
            password: userData['password'] as String? ?? '',
            schoolId: userData['schoolId'] as int?,
          );
          _isLoading = false;
          notifyListeners();
          return true;
        }
      } catch (localError) {
        print('❌ Erreur login local: $localError');
      }
      
      _isLoading = false;
      notifyListeners();
      return false;
      
    } catch (e) {
      print('❌ Erreur login: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Charger les données utilisateur depuis Firestore
  Future<void> _loadUserFromFirestore(String uid) async {
    try {
      final docSnapshot = await _firestore.collection('users').doc(uid).get();
      
      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        _schoolName = data['schoolName'];
        
        _user = User(
          id: data['localId'] ?? 0,
          firestoreId: uid,
          name: data['name'] ?? '',
          email: data['email'] ?? '',
          role: data['role'] ?? 'student',
          password: '',
          schoolId: data['schoolId'],
          firebaseUid: uid,
        );
        
        // Sauvegarder aussi localement dans Hive
        await _db.insertUser({
          'name': _user!.name,
          'email': _user!.email,
          'role': _user!.role,
          'schoolId': _user!.schoolId,
          'firebaseUid': uid,
          'firestoreId': uid,
        });
      }
    } catch (e) {
      print('❌ Erreur chargement Firestore: $e');
    }
  }

  // ================= INSCRIPTION AVEC FIREBASE =================
  
  /// Inscription avec Firebase et sauvegarde locale
  Future<bool> register(String name, String email, String password, String role, int? schoolId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Vérifier si l'utilisateur existe déjà localement
      final existingUser = await _db.getUserByEmail(email);
      if (existingUser != null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      // 1. Créer l'utilisateur dans Firebase Authentication
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      _firebaseUser = userCredential.user;
      _isFirebaseConnected = true;
      
      // 2. Créer le document utilisateur dans Firestore
      final userData = {
        'name': name,
        'email': email.toLowerCase().trim(),
        'role': role,
        'schoolId': schoolId,
        'schoolName': _schoolName,
        'createdAt': FieldValue.serverTimestamp(),
        'localId': null, // Sera mis à jour après l'insertion locale
      };
      
      await _firestore.collection('users').doc(_firebaseUser!.uid).set(userData);
      
      // 3. Sauvegarder localement dans Hive
      final userId = await _db.insertUser({
        'name': name,
        'email': email.toLowerCase().trim(),
        'password': password,
        'role': role,
        'schoolId': schoolId,
        'firebaseUid': _firebaseUser!.uid,
        'firestoreId': _firebaseUser!.uid,
      });
      
      // 4. Mettre à jour Firestore avec l'ID local
      await _firestore.collection('users').doc(_firebaseUser!.uid).update({
        'localId': userId,
      });
      
      _user = User(
        id: userId,
        firestoreId: _firebaseUser!.uid,
        name: name,
        email: email.toLowerCase().trim(),
        role: role,
        password: password,
        schoolId: schoolId,
        firebaseUid: _firebaseUser!.uid,
      );
      
      // 5. Synchroniser les données initiales si l'utilisateur a une école
      if (schoolId != null) {
        await _syncService.fullSyncFromFirestore(schoolId: schoolId.toString());
        _syncService.startRealtimeListeners(schoolId: schoolId.toString());
        _syncService.startAutoSync();
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
      
    } on firebase.FirebaseAuthException catch (e) {
      print('❌ Firebase Auth erreur: ${e.message}');
      _isLoading = false;
      notifyListeners();
      return false;
      
    } catch (e) {
      print('❌ Erreur register: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ================= RÉINITIALISATION DU MOT DE PASSE =================
  
  /// Envoyer un email de réinitialisation de mot de passe
  Future<bool> resetPassword(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
      return true;
    } catch (e) {
      print('❌ Erreur reset password: $e');
      return false;
    }
  }

  // ================= DÉCONNEXION =================
  
  /// Déconnexion (Firebase + local)
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    
    // Arrêter la synchronisation
    _syncService.stopAutoSync();
    _syncService.stopAllListeners();
    
    // Déconnexion Firebase
    await _firebaseAuth.signOut();
    
    // Nettoyer l'état
    _user = null;
    _firebaseUser = null;
    _isFirebaseConnected = false;
    _schoolName = null;
    
    _isLoading = false;
    notifyListeners();
  }

  // ================= MISE À JOUR PROFIL =================
  
  /// Mettre à jour le profil utilisateur (local + Firestore)
  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    if (_user == null) return false;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      // 1. Mettre à jour Firestore si connecté
      if (_firebaseUser != null) {
        final firestoreUpdates = <String, dynamic>{};
        if (updates.containsKey('name')) firestoreUpdates['name'] = updates['name'];
        if (updates.containsKey('email')) firestoreUpdates['email'] = updates['email'];
        if (updates.containsKey('role')) firestoreUpdates['role'] = updates['role'];
        
        if (firestoreUpdates.isNotEmpty) {
          await _firestore.collection('users').doc(_firebaseUser!.uid).update(firestoreUpdates);
        }
      }
      
      // 2. Mettre à jour localement
      await _db.updateUser(_user!.id, updates);
      
      // 3. Mettre à jour l'objet utilisateur
      if (updates.containsKey('name')) _user = _user!.copyWith(name: updates['name']);
      if (updates.containsKey('email')) _user = _user!.copyWith(email: updates['email']);
      if (updates.containsKey('password')) _user = _user!.copyWith(password: updates['password']);
      if (updates.containsKey('role')) _user = _user!.copyWith(role: updates['role']);
      if (updates.containsKey('schoolId')) _user = _user!.copyWith(schoolId: updates['schoolId']);
      
      _isLoading = false;
      notifyListeners();
      return true;
      
    } catch (e) {
      print('❌ Erreur updateProfile: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ================= CHANGEMENT DE MOT DE PASSE =================
  
  /// Changer le mot de passe (Firebase + local)
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    if (_user == null) return false;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      // Changer le mot de passe dans Firebase
      if (_firebaseUser != null) {
        // Réauthentifier l'utilisateur d'abord
        final credential = firebase.EmailAuthProvider.credential(
          email: _user!.email,
          password: oldPassword,
        );
        await _firebaseUser!.reauthenticateWithCredential(credential);
        await _firebaseUser!.updatePassword(newPassword);
      }
      
      // Changer localement
      final success = await updateProfile({'password': newPassword});
      
      _isLoading = false;
      notifyListeners();
      return success;
      
    } catch (e) {
      print('❌ Erreur changePassword: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ================= RAFRAÎCHISSEMENT UTILISATEUR =================
  
  /// Rafraîchir les données utilisateur depuis Firestore et Hive
  Future<void> refreshUser() async {
    if (_user == null) return;
    
    try {
      // Essayer depuis Firestore d'abord
      if (_firebaseUser != null) {
        final docSnapshot = await _firestore.collection('users').doc(_firebaseUser!.uid).get();
        if (docSnapshot.exists) {
          final data = docSnapshot.data()!;
          _user = User(
            id: data['localId'] ?? _user!.id,
            firestoreId: _firebaseUser!.uid,
            name: data['name'] ?? _user!.name,
            email: data['email'] ?? _user!.email,
            role: data['role'] ?? _user!.role,
            password: _user!.password,
            schoolId: data['schoolId'],
            firebaseUid: _firebaseUser!.uid,
          );
          notifyListeners();
          return;
        }
      }
      
      // Fallback: depuis Hive local
      final userData = await _db.getUserByEmail(_user!.email);
      if (userData != null) {
        _user = User(
          id: userData['id'] as int? ?? 0,
          firestoreId: userData['firestoreId'] as String?,
          name: userData['name'] as String? ?? '',
          email: userData['email'] as String? ?? '',
          role: userData['role'] as String? ?? 'student',
          password: userData['password'] as String? ?? '',
          schoolId: userData['schoolId'] as int?,
          firebaseUid: _user!.firebaseUid,
        );
        notifyListeners();
      }
      
    } catch (e) {
      print('❌ Erreur refreshUser: $e');
    }
  }

  // ================= SYNC MANUELLE =================
  
  /// Forcer une synchronisation manuelle
  Future<void> forceSync() async {
    if (_user?.schoolId != null) {
      await _syncService.forceSync(schoolId: _user!.schoolId.toString());
    }
  }
  
  /// Obtenir le nombre d'éléments en attente de synchronisation
  Future<int> getPendingSyncCount() async {
    return await _syncService.getPendingSyncCount();
  }
  
  /// Dernière synchronisation
  Future<DateTime?> getLastSyncTime() async {
    return await _syncService.getLastSyncTimestamp();
  }
}