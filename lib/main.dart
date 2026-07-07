// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'models/university/etablissement_model.dart';
import 'services/notification_service.dart';
import 'services/notification_trigger.dart';
import 'services/migration_service.dart';

// Import des écrans existants
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/add_user.dart';
import 'screens/admin/add_announcement.dart';
import 'screens/admin/admin_professors.dart';
import 'screens/admin/admin_schedule.dart';
import 'screens/admin/professor_permissions.dart';
import 'screens/admin/add_class_screen.dart';
import 'screens/admin/manage_sections_screen.dart';
import 'screens/staff/add_document.dart';
import 'screens/staff/add_payment.dart';
import 'screens/staff/add_student.dart';
import 'screens/staff/staff_dashboard.dart';
import 'screens/teacher/teacher_dashboard.dart';
import 'screens/teacher/teacher_schedule.dart';
import 'screens/teacher/teacher_attendance.dart';
import 'screens/teacher/teacher_grades.dart';
import 'screens/teacher/teacher_students.dart';
import 'screens/teacher/teacher_reports.dart';
import 'screens/parent/parent_dashboard.dart';
import 'screens/parent/parent_children.dart';
import 'screens/parent/parent_grades.dart';
import 'screens/parent/parent_attendance.dart';
import 'screens/parent/parent_schedule.dart';
import 'screens/parent/parent_payments.dart';
import 'screens/parent/parent_documents.dart';
import 'screens/parent/parent_messages.dart';
import 'screens/student/student_dashboard.dart';
import 'screens/student/student_profile.dart';
import 'screens/student/student_grades.dart';
import 'screens/student/student_attendance.dart';
import 'screens/student/student_schedule.dart';
import 'screens/student/student_documents.dart';
import 'screens/student/student_exams.dart';
import 'screens/student/student_courses.dart';
import 'screens/secret/admin_creator_screen.dart';

// Import des écrans Super Admin
import 'screens/super_admin/super_admin_dashboard.dart';
import 'screens/super_admin/statistics_screen.dart';
import 'screens/super_admin/system_logs_screen.dart';
import 'screens/super_admin/school_payments_screen.dart';
import 'screens/super_admin/settings_screen.dart';

// Import DBHelper
import 'services/db_helper.dart';
import 'services/sync_service.dart';
import 'services/school_service.dart';
import 'services/user_service.dart';
import 'services/payment_service.dart';
import 'services/document_service.dart';
import 'models/user.dart';

// ✅ GLOBAL NAVIGATOR KEY
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Variables globales pour l'état d'initialisation
bool _isInitialized = false;
String? _initError;
SyncService? _syncService;

// ═══════════════════════════════════════════════════════════════════════════
// CRÉATION DU SUPER ADMIN PAR DÉFAUT
// ═══════════════════════════════════════════════════════════════════════════

Future<void> _createDefaultSuperAdmin() async {
  print('\n🔧 Vérification du compte Super Admin...');
  
  try {
    final db = DBHelper();
    final auth = firebase_auth.FirebaseAuth.instance;
    
    final users = await db.getAllUsers();
    final superAdminExists = users.any((u) => u['role'] == 'super_admin');
    
    if (!superAdminExists) {
      print('⚠️ Aucun Super Admin trouvé, création du compte par défaut...');
      
      try {
        await auth.createUserWithEmailAndPassword(
          email: 'superadmin@ecole.com',
          password: 'Admin123!',
        );
        print('✅ Compte Firebase créé avec succès');
      } on firebase_auth.FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          print('⚠️ Compte Firebase existe déjà');
        } else {
          print('⚠️ Erreur Firebase: ${e.message}');
        }
      }
      
      final userId = await db.insertUser({
        'name': 'Super Administrateur',
        'email': 'superadmin@ecole.com',
        'password': 'Admin123!',
        'role': 'super_admin',
        'schoolId': null,
      });
      
      print('✅ Super Admin créé localement avec ID: $userId');
      print('\n╔═══════════════════════════════════════════════════════════════╗');
      print('║  🔐 COMPTE SUPER ADMIN PAR DÉFAUT                            ║');
      print('╠═══════════════════════════════════════════════════════════════╣');
      print('║  📧 Email: superadmin@ecole.com                              ║');
      print('║  🔑 Mot de passe: Admin123!                                  ║');
      print('╠═══════════════════════════════════════════════════════════════╣');
      print('║  ⚠️  Veuillez changer ces identifiants après connexion !     ║');
      print('╚═══════════════════════════════════════════════════════════════╝');
    } else {
      print('✅ Super Admin existe déjà');
    }
  } catch (e) {
    print('❌ Erreur création Super Admin: $e');
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SYNC DES ÉCOLES DEPUIS FIRESTORE
// ═══════════════════════════════════════════════════════════════════════════

Future<void> _syncSchoolsFromFirestore() async {
  print('\n🔄 Synchronisation des écoles depuis Firestore...');
  
  try {
    final db = DBHelper();
    final snapshot = await FirebaseFirestore.instance.collection('schools').get();
    
    print('📚 ${snapshot.docs.length} écoles trouvées dans Firestore');
    
    for (var doc in snapshot.docs) {
      final data = doc.data();
      
      final existingSchools = await db.getAllEtablissements();
      final exists = existingSchools.any((s) => s.firestoreId == doc.id);
      
      if (!exists) {
        final school = EtablissementModel(
          nom: data['name'] ?? 'École sans nom',
          type: data['type'] ?? 'École',
          adresse: data['address'],
          telephone: data['phone'],
          email: data['email'],
          siteWeb: data['website'],
          firestoreId: doc.id,
          isActive: data['isActive'] ?? true,
          schoolCode: data['schoolCode'] ?? '',
        );
        await db.addEtablissement(school);
        print('  ✅ École ajoutée localement: ${school.nom} (Code: ${school.schoolCode})');
      }
    }
    
    print('✅ Synchronisation des écoles terminée');
  } catch (e) {
    print('❌ Erreur synchronisation écoles: $e');
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MIGRATION AUTOMATIQUE DES ÉTUDIANTS
// ═══════════════════════════════════════════════════════════════════════════

Future<void> _runAutomaticMigration() async {
  print('\n🔄 Vérification de la migration des étudiants...');
  
  try {
    final migrationService = MigrationService();
    final result = await migrationService.runOnce();
    
    if (result['migrated'] > 0) {
      print('✅ Migration automatique: ${result['migrated']} étudiants migrés');
    } else if (result['success']) {
      print('✅ Aucune migration nécessaire');
    } else {
      print('⚠️ Migration: ${result['message']}');
    }
  } catch (e) {
    print('❌ Erreur lors de la migration automatique: $e');
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GESTION DES MESSAGES FCM (Notifications)
// ═══════════════════════════════════════════════════════════════════════════

Future<void> _setupFCMListeners() async {
  print('\n🔔 Configuration des écouteurs FCM...');
  
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('📨 Message reçu en premier plan: ${message.notification?.title}');
  });
  
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('🖱️ Notification tapée: ${message.notification?.title}');
    _handleNotificationTap(message.data);
  });
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📨 Message reçu en arrière-plan: ${message.notification?.title}');
  await Firebase.initializeApp();
}

void _handleNotificationTap(Map<String, dynamic> data) {
  final type = data['type'];
  print('🔍 Navigation depuis notification: type=$type');
}

// ═══════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════

void main() async {
  print("╔════════════════════════════════════════════════════════════╗");
  print("║                    DÉMARRAGE DE L'APP                      ║");
  print("╚════════════════════════════════════════════════════════════╝");
  
  print("\n[1] Initialisation du binding Flutter...");
  WidgetsFlutterBinding.ensureInitialized();
  print("✓ Binding Flutter initialisé");
  
  print("\n[2] Début de l'initialisation des services...");
  
  try {
    print("\n  → Initialisation de Firebase...");
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("  ✓ Firebase initialisé avec succès");
    
    print("\n  → Initialisation du service de notifications...");
    await NotificationService().initialize();
    print("  ✓ Service de notifications initialisé");
    
    print("\n  → Configuration des écouteurs FCM...");
    await _setupFCMListeners();
    print("  ✓ Écouteurs FCM configurés");
    
    print("\n  → Initialisation de la base de données locale (Hive)...");
    final db = DBHelper();
    await db.init();
    print("  ✓ Base de données locale initialisée");
    
    print("\n  → Démarrage du service de synchronisation...");
    _syncService = SyncService();
    _syncService!.startAutoSync();
    print("  ✓ Service de synchronisation démarré");
    
    await _createDefaultSuperAdmin();
    await _syncSchoolsFromFirestore();
    
    print("\n  → Migration automatique des étudiants...");
    await _runAutomaticMigration();
    print("  ✓ Migration des étudiants vérifiée");
    
    print("\n  → Démarrage des écouteurs de notifications automatiques...");
    NotificationTrigger().startAllListeners();
    print("  ✓ Écouteurs de notifications actifs");
    
    _isInitialized = true;
    print("\n✅ TOUS LES SERVICES SONT INITIALISÉS AVEC SUCCÈS ✅");
    
  } catch (e, stackTrace) {
    print("\n❌ ERREUR D'INITIALISATION ❌");
    print("   Message: $e");
    print("   Stack trace: $stackTrace");
    _initError = e.toString();
    _isInitialized = false;
  }
  
  print("\n[3] Lancement de l'interface utilisateur...");
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          print("→ Création de AuthProvider");
          return AuthProvider();
        }),
      ],
      child: const MyApp(),
    ),
  );
  
  print("✓ runApp() exécuté\n");
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // ✅ AJOUTÉ
      title: 'EscaSchool',
      debugShowCheckedModeBanner: false,
      
      initialRoute: '/',
      routes: {
        '/': (context) => _buildHomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/admin_dashboard': (context) => const AdminDashboard(),
        '/add_user': (context) => const AddUserScreen(),
        '/add_announcement': (context) => AddAnnouncementScreen(),
        '/admin_professors': (context) => AdminProfessors(onChanged: () {}),
        '/staff_dashboard': (context) => const AdminStaffDashboard(),
        '/add_document': (context) => const AddDocumentScreen(),
        '/add_payment': (context) => const AddPaymentScreen(),
        '/add_student': (context) => const AddStudentScreen(),
        '/admin_schedule': (context) => AdminSchedule(professorFirestoreId: '', professorName: "Professeur"),
        '/professor_permissions': (context) => ProfessorPermissionsScreen(professorFirestoreId: '', professorName: "Professeur"),
        '/super_admin_dashboard': (context) => const SuperAdminDashboard(),
        '/statistics': (context) => const StatisticsScreen(),
        '/system_logs': (context) => const SystemLogsScreen(),
        '/school_payments': (context) => const SchoolPaymentsScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/secret/admin': (context) => const AdminCreatorScreen(),
        '/add_class': (context) => const AddClassScreen(),
        '/manage_sections': (context) => const ManageSectionsScreen(),
      },
      
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/teacher_dashboard':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => TeacherDashboard(
                professorFirestoreId: args?['professorFirestoreId'] ?? '',
                professorName: args?['professorName'] ?? "Professeur",
              ),
            );
          
          case '/teacher_schedule':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => TeacherScheduleScreen(
                teacherName: args?['teacherName'] ?? "Professeur",
                professorFirestoreId: args?['professorFirestoreId'] ?? '',
                assignedClasses: args?['assignedClasses'] ?? [],
              ),
            );

          case '/teacher_attendance':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => TeacherAttendanceScreen(
                teacherName: args?['teacherName'] ?? "Professeur",
                professorFirestoreId: args?['professorFirestoreId'] ?? '',
                assignedClasses: args?['assignedClasses'] ?? [],
                assignedSubjects: args?['assignedSubjects'] ?? [],
              ),
            );

          case '/teacher_grades':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => TeacherGradesScreen(
                teacherName: args?['teacherName'] ?? "Professeur",
                professorFirestoreId: args?['professorFirestoreId'] ?? '',
                assignedClasses: args?['assignedClasses'] ?? [],
                assignedSubjects: args?['assignedSubjects'] ?? [],
              ),
            );
          
          case '/parent_dashboard':
            return MaterialPageRoute(builder: (context) => const ParentDashboard());
          
          case '/parent_children':
            return MaterialPageRoute(builder: (context) => const ParentChildrenScreen());
          
          case '/parent_grades':
            return MaterialPageRoute(builder: (context) => const ParentGradesScreen());
          
          case '/parent_attendance':
            return MaterialPageRoute(builder: (context) => const ParentAttendanceScreen());
          
          case '/parent_schedule':
            return MaterialPageRoute(builder: (context) => const ParentScheduleScreen());
          
          case '/parent_payments':
            return MaterialPageRoute(builder: (context) => const ParentPaymentsScreen());
          
          case '/parent_documents':
            return MaterialPageRoute(builder: (context) => const ParentDocumentsScreen());
          
          case '/parent_messages':
            return MaterialPageRoute(builder: (context) => const ParentMessagesScreen());
          
          case '/teacher_students':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => TeacherStudentsScreen(
                assignedClasses: args?['assignedClasses'] ?? [],
              ),
            );
          
          case '/teacher_reports':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => TeacherReportsScreen(
                teacherName: args?['teacherName'] ?? "Professeur",
                professorFirestoreId: args?['professorFirestoreId'] ?? "",
                assignedClasses: args?['assignedClasses'] ?? [],
                assignedSubjects: args?['assignedSubjects'] ?? [],
              ),
            );
          
          default:
            return null;
        }
      },
      
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Erreur')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 20),
                  const Text('Page non trouvée', style: TextStyle(fontSize: 24)),
                  const SizedBox(height: 10),
                  Text('La route "${settings.name}" n\'existe pas', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                    ),
                    child: const Text('Retour à la connexion'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildHomeScreen() {
    if (_initError != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 20),
              const Text('Erreur d\'initialisation', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: Text(_initError!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {},
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }
    
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Initialisation de l\'application...'),
            ],
          ),
        ),
      );
    }
    
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Vérification de la session...'),
                ],
              ),
            ),
          );
        }
        
        if (auth.user != null) {
          return _getDashboardScreen(auth.user!.role, auth);
        }
        
        return const LoginScreen();
      },
    );
  }
  
  Widget _getDashboardScreen(String role, AuthProvider auth) {
    switch (role) {
      case 'super_admin':
        return const SuperAdminDashboard();
      case 'admin':
        return const AdminDashboard();
      case 'staff':
        return const AdminStaffDashboard();
      case 'teacher':
        return TeacherDashboard(
          professorFirestoreId: auth.user?.firestoreId ?? '',
          professorName: auth.user?.name ?? "Professeur",
        );
      case 'parent':
        return const ParentDashboard();
      case 'student':
        return const StudentDashboard();
      default:
        return const LoginScreen();
    }
  }
}