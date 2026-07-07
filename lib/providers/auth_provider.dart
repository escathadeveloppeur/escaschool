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
  String? get currentSchoolId => _user?.schoolId;
  bool get isSuperAdmin => _user?.role == 'super_admin';
  bool get isSchoolAdmin => _user?.role == 'admin';
  bool get isTeacher => _user?.role == 'teacher';
  bool get isStudent => _user?.role == 'student';
  bool get isParent => _user?.role == 'parent';
  bool get hasSchool => _user?.schoolId != null && _user!.schoolId!.isNotEmpty;
  String get userRole => _user?.role ?? 'unknown';

  // ================= CONSTRUCTEUR =================
  
  /// Constructeur avec initialisation automatique
  AuthProvider() {
    print('🔐 AuthProvider créé');
    _autoInit();
  }
  
  /// Initialisation automatique au chargement du provider
  Future<void> _autoInit() async {
    print('🔄 Auto-init AuthProvider...');
    _isLoading = true;
    notifyListeners();
    
    // Vérifier si un utilisateur Firebase est déjà connecté
    _firebaseUser = _firebaseAuth.currentUser;
    _isFirebaseConnected = _firebaseUser != null;
    
    print('📱 Utilisateur Firebase connecté: ${_firebaseUser?.email ?? 'aucun'}');
    
    if (_firebaseUser != null) {
      await _loadUserFromFirestore(_firebaseUser!.uid);
    }
    
    _isLoading = false;
    notifyListeners();
    print('✅ Auto-init terminé');
  }

  // ================= INITIALISATION MANUELLE =================
  
  /// Initialisation manuelle (si nécessaire)
  Future<void> init() async {
    print('🔧 Initialisation manuelle AuthProvider');
    await _autoInit();
  }

  // ================= UTILITAIRE: CONVERSION SCHOOL ID =================
  
  /// Convertir schoolId de String/Dynamic vers int
  int? _parseSchoolId(dynamic schoolIdDynamic) {
    if (schoolIdDynamic == null) return null;
    if (schoolIdDynamic is int) return schoolIdDynamic;
    if (schoolIdDynamic is String) return int.tryParse(schoolIdDynamic);
    return null;
  }

  // ================= LOGIN AVEC FIREBASE =================
  
  /// Connexion avec email et mot de passe (Firebase + Hive local)
  Future<bool> login(String email, String password) async {
    print('\n═══════════════════════════════════════════════════════════');
    print('🔐 TENTATIVE DE CONNEXION');
    print('📧 Email: $email');
    print('═══════════════════════════════════════════════════════════\n');
    
    _isLoading = true;
    notifyListeners();
    
    try {
      // 1. Connexion avec Firebase Authentication
      print('📡 Étape 1: Connexion à Firebase Auth...');
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      _firebaseUser = userCredential.user;
      _isFirebaseConnected = true;
      print('✅ Firebase Auth réussi!');
      print('   UID: ${_firebaseUser!.uid}');
      print('   Email: ${_firebaseUser!.email}');
      
      // 2. Récupérer les données utilisateur depuis Firestore
      print('📡 Étape 2: Chargement des données Firestore...');
      await _loadUserFromFirestore(_firebaseUser!.uid);
      
      // 3. Vérifier le statut du compte
      print('📡 Étape 3: Vérification du statut...');
      final userDoc = await _firestore.collection('users').doc(_firebaseUser!.uid).get();
      
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final status = userData['status'] ?? 'pending';
        print('📊 Statut du compte: $status');
        
        if (status != 'approved') {
          print('❌ Compte non approuvé! Statut: $status');
          await _firebaseAuth.signOut();
          _isLoading = false;
          notifyListeners();
          return false;
        }
        
        // Vérifier pour admin/staff
        final role = userData['role'] ?? '';
        if ((role == 'admin' || role == 'staff') && userData['schoolId'] == null) {
          print('❌ Admin/Staff sans école associée!');
          await _firebaseAuth.signOut();
          _isLoading = false;
          notifyListeners();
          return false;
        }
      } else {
        print('❌ Document utilisateur non trouvé dans Firestore!');
        await _firebaseAuth.signOut();
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      // 4. Vérifier aussi dans Hive local (fallback)
      print('📡 Étape 4: Vérification locale Hive...');
      final localUserData = await _db.getUserByEmail(email);
      
      if (localUserData != null) {
        print('📦 Données locales trouvées:');
        print('   - id: ${localUserData['id']} (type: ${localUserData['id'].runtimeType})');
        print('   - schoolId: ${localUserData['schoolId']} (type: ${localUserData['schoolId'].runtimeType})');
        
        // 🔥 CORRECTION: Convertir schoolId correctement
        final schoolIdInt = _parseSchoolId(localUserData['schoolId']);
        print('   - schoolId converti: $schoolIdInt');
        
        _user = User(
          id: localUserData['id'] as int? ?? 0,
          firestoreId: localUserData['firestoreId'] as String?,
          name: localUserData['name'] as String? ?? '',
          email: localUserData['email'] as String? ?? '',
          role: localUserData['role'] as String? ?? 'student',
          password: localUserData['password'] as String? ?? '',
          schoolId: localUserData['schoolId'] as String?,

          firebaseUid: _firebaseUser!.uid,
        );
        print('✅ Utilisateur créé depuis données locales');
      } else {
        print('⚠️ Aucune donnée locale trouvée pour cet email');
      }
      
      if (_user == null) {
        print('❌ Impossible de charger l\'utilisateur');
        await _firebaseAuth.signOut();
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      print('✅ Utilisateur chargé:');
      print('   Nom: ${_user!.name}');
      print('   Rôle: ${_user!.role}');
      print('   École ID: ${_user!.schoolId}');
      print('   Firebase UID: ${_user!.firebaseUid}');
      
      // 5. Si l'utilisateur appartient à une école, synchroniser les données
      if (_user?.schoolId != null) {
        print('📡 Étape 5: Démarrage synchronisation...');
        await _syncService.fullSyncFromFirestore(schoolId: _user!.schoolId.toString());
        _syncService.startRealtimeListeners(schoolId: _user!.schoolId.toString());
        _syncService.startAutoSync();
        print('✅ Synchronisation démarrée');
      }
      
      _isLoading = false;
      notifyListeners();
      print('\n✅ CONNEXION RÉUSSIE! ✅\n');
      return true;
      
    } on firebase.FirebaseAuthException catch (e) {
      print('\n❌ ERREUR FIREBASE AUTH ❌');
      print('   Code: ${e.code}');
      print('   Message: ${e.message}');
      print('   Stack trace: ${e.stackTrace}\n');
      
      // Fallback: essayer la connexion locale Hive
      print('📡 Tentative de connexion locale Hive...');
      try {
        final userData = await _db.getUserByEmail(email);
        if (userData != null && userData['password'] == password) {
          print('✅ Connexion locale réussie!');
          
          final schoolIdInt = _parseSchoolId(userData['schoolId']);
          
          _user = User(
            id: userData['id'] as int? ?? 0,
            firestoreId: userData['firestoreId'] as String?,
            name: userData['name'] as String? ?? '',
            email: userData['email'] as String? ?? '',
            role: userData['role'] as String? ?? 'student',
            password: userData['password'] as String? ?? '',
            schoolId: userData['schoolId'] as String?,

          );
          _isLoading = false;
          notifyListeners();
          return true;
        } else {
          print('❌ Échec connexion locale: utilisateur non trouvé ou mot de passe incorrect');
        }
      } catch (localError) {
        print('❌ Erreur login local: $localError');
      }
      
      _isLoading = false;
      notifyListeners();
      return false;
      
    } catch (e) {
      print('\n❌ ERREUR GÉNÉRALE ❌');
      print('   Type: ${e.runtimeType}');
      print('   Message: $e');
      print('   Stack trace: ${StackTrace.current}\n');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Charger les données utilisateur depuis Firestore
  Future<void> _loadUserFromFirestore(String uid) async {
    print('📥 Chargement Firestore pour UID: $uid');
    try {
      final docSnapshot = await _firestore.collection('users').doc(uid).get();
      
      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        _schoolName = data['schoolName'];
        
        print('📦 Données Firestore:');
        print('   - name: ${data['name']}');
        print('   - role: ${data['role']}');
        print('   - schoolId: ${data['schoolId']} (type: ${data['schoolId'].runtimeType})');
        print('   - status: ${data['status']}');
        
        // 🔥 CORRECTION: Convertir schoolId correctement
        final schoolIdInt = _parseSchoolId(data['schoolId']);
        
        _user = User(
          id: data['localId'] ?? 0,
          firestoreId: uid,
          name: data['name'] ?? '',
          email: data['email'] ?? '',
          role: data['role'] ?? 'student',
          password: '',
          schoolId:data['schoolId'] as String?,
          firebaseUid: uid,
        );
        
        print('✅ Utilisateur chargé depuis Firestore: ${_user!.name} (${_user!.role})');
        print('   schoolId après conversion: ${_user!.schoolId}');
        
        // Sauvegarder aussi localement dans Hive
        await _db.insertUser({
          'name': _user!.name,
          'email': _user!.email,
          'role': _user!.role,
          'schoolId': _user!.schoolId,
          'firebaseUid': uid,
          'firestoreId': uid,
        });
        print('✅ Utilisateur sauvegardé localement');
      } else {
        print('⚠️ Document utilisateur non trouvé pour UID: $uid');
      }
    } catch (e) {
      print('❌ Erreur chargement Firestore: $e');
    }
  }

  // ================= INSCRIPTION AVEC FIREBASE =================
  
  /// Inscription avec Firebase et sauvegarde locale
  Future<bool> register(String name, String email, String password, String role, String schoolId) async {
    print('\n═══════════════════════════════════════════════════════════');
    print('📝 TENTATIVE D\'INSCRIPTION');
    print('   Nom: $name');
    print('   Email: $email');
    print('   Rôle: $role');
    print('   schoolId: $schoolId');
    print('═══════════════════════════════════════════════════════════\n');
    
    _isLoading = true;
    notifyListeners();
    
    try {
      // Vérifier si l'utilisateur existe déjà localement
      print('📡 Vérification existence locale...');
      final existingUser = await _db.getUserByEmail(email);
      if (existingUser != null) {
        print('❌ Utilisateur existe déjà localement');
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      // 1. Créer l'utilisateur dans Firebase Authentication
      print('📡 Création Firebase Auth...');
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      _firebaseUser = userCredential.user;
      _isFirebaseConnected = true;
      print('✅ Firebase Auth réussi! UID: ${_firebaseUser!.uid}');
      
      // 2. Créer le document utilisateur dans Firestore
      print('📡 Création document Firestore...');
      final userData = {
        'name': name,
        'email': email.toLowerCase().trim(),
        'role': role,
        'schoolId': schoolId,
        'schoolName': _schoolName,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'localId': null,
      };
      
      await _firestore.collection('users').doc(_firebaseUser!.uid).set(userData);
      print('✅ Document Firestore créé');
      
      // 3. Sauvegarder localement dans Hive
      print('📡 Sauvegarde locale...');
      final userId = await _db.insertUser({
        'name': name,
        'email': email.toLowerCase().trim(),
        'password': password,
        'role': role,
        'schoolId': schoolId,
        'firebaseUid': _firebaseUser!.uid,
        'firestoreId': _firebaseUser!.uid,
        'status': 'pending',
      });
      print('✅ Sauvegarde locale réussie, ID: $userId');
      
      // 4. Mettre à jour Firestore avec l'ID local
      await _firestore.collection('users').doc(_firebaseUser!.uid).update({
        'localId': userId,
      });
      print('✅ Firestore mis à jour avec localId');
      
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
        print('📡 Synchronisation initiale...');
        await _syncService.fullSyncFromFirestore(schoolId: schoolId.toString());
        _syncService.startRealtimeListeners(schoolId: schoolId.toString());
        _syncService.startAutoSync();
        print('✅ Synchronisation démarrée');
      }
      
      _isLoading = false;
      notifyListeners();
      print('\n✅ INSCRIPTION RÉUSSIE! ✅\n');
      return true;
      
    } on firebase.FirebaseAuthException catch (e) {
      print('\n❌ ERREUR FIREBASE AUTH ❌');
      print('   Code: ${e.code}');
      print('   Message: ${e.message}\n');
      _isLoading = false;
      notifyListeners();
      return false;
      
    } catch (e) {
      print('\n❌ ERREUR INSCRIPTION ❌');
      print('   $e\n');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ================= RÉINITIALISATION DU MOT DE PASSE =================
  
  /// Envoyer un email de réinitialisation de mot de passe
  Future<bool> resetPassword(String email) async {
    print('📧 Demande réinitialisation pour: $email');
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
      print('✅ Email de réinitialisation envoyé');
      return true;
    } catch (e) {
      print('❌ Erreur reset password: $e');
      return false;
    }
  }

  // ================= DÉCONNEXION =================
  
  /// Déconnexion (Firebase + local)
  Future<void> logout() async {
    print('🚪 Déconnexion...');
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
    print('✅ Déconnecté');
  }

  // ================= MISE À JOUR PROFIL =================
  
  /// Mettre à jour le profil utilisateur (local + Firestore)
  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    if (_user == null) return false;
    
    print('✏️ Mise à jour profil: $updates');
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
          print('✅ Firestore mis à jour');
        }
      }
      
      // 2. Mettre à jour localement
      await _db.updateUser(_user!.id, updates);
      print('✅ Hive mis à jour');
      
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
    
    print('🔑 Changement mot de passe');
    _isLoading = true;
    notifyListeners();
    
    try {
      // Changer le mot de passe dans Firebase
      if (_firebaseUser != null) {
        final credential = firebase.EmailAuthProvider.credential(
          email: _user!.email,
          password: oldPassword,
        );
        await _firebaseUser!.reauthenticateWithCredential(credential);
        await _firebaseUser!.updatePassword(newPassword);
        print('✅ Firebase Auth mis à jour');
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
    
    print('🔄 Rafraîchissement utilisateur');
    
    try {
      // Essayer depuis Firestore d'abord
      if (_firebaseUser != null) {
        final docSnapshot = await _firestore.collection('users').doc(_firebaseUser!.uid).get();
        if (docSnapshot.exists) {
          final data = docSnapshot.data()!;
          
          final schoolIdInt = _parseSchoolId(data['schoolId']);
          
          _user = User(
            id: data['localId'] ?? _user!.id,
            firestoreId: _firebaseUser!.uid,
            name: data['name'] ?? _user!.name,
            email: data['email'] ?? _user!.email,
            role: data['role'] ?? _user!.role,
            password: _user!.password,
            schoolId:data['schoolId'] as String?,

            firebaseUid: _firebaseUser!.uid,
          );
          notifyListeners();
          print('✅ Utilisateur rafraîchi depuis Firestore');
          return;
        }
      }
      
      // Fallback: depuis Hive local
      final userData = await _db.getUserByEmail(_user!.email);
      if (userData != null) {
        final schoolIdInt = _parseSchoolId(userData['schoolId']);
        
        _user = User(
          id: userData['id'] as int? ?? 0,
          firestoreId: userData['firestoreId'] as String?,
          name: userData['name'] as String? ?? '',
          email: userData['email'] as String? ?? '',
          role: userData['role'] as String? ?? 'student',
          password: userData['password'] as String? ?? '',
          schoolId:userData['schoolId'] as String?,

          firebaseUid: _user!.firebaseUid,
        );
        notifyListeners();
        print('✅ Utilisateur rafraîchi depuis Hive');
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