// lib/services/nana_ai_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/nana_context.dart';
import 'nana_local_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class NanaAIService {
  static List<Map<String, String>> _conversationHistory = [];
  static NanaContext? _currentContext;
  static Map<String, dynamic> _userContext = {};

  // ================================================================
  // INITIALISATION
  // ================================================================

  static Future<void> initializeContext({
    required String role,
    required String userId,
    required String userName,
    String? schoolId,
  }) async {
    print('📥 Initialisation de Nana pour: $userName ($role)');
    
    _userContext = {
      'role': role,
      'userId': userId,
      'userName': userName,
      'schoolId': schoolId,
    };
    
    // 🔥 Charger le contexte utilisateur depuis Firestore
    _currentContext = await _fetchUserData(
      userId: userId,
      role: role,
      userName: userName,
    );
    
    print('📊 Contexte chargé: ${_currentContext?.userName}');
    print('📊 Moyenne: ${_currentContext?.average}');
    print('📊 Classe: ${_currentContext?.className}');
    
    // Charger l'historique
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('nana_history_$userId');
      if (historyJson != null) {
        final List<dynamic> history = jsonDecode(historyJson);
        _conversationHistory = history.map((e) => Map<String, String>.from(e)).toList();
      }
    } catch (e) {
      print('⚠️ Erreur chargement historique: $e');
    }
  }

  static Future<NanaContext?> getUserContext() async {
    return _currentContext;
  }

  // ================================================================
  // RÉCUPÉRATION DES DONNÉES UTILISATEUR (FIRESTORE)
  // ================================================================

  static Future<NanaContext> _fetchUserData({
    required String userId,
    required String role,
    required String userName,
  }) async {
    print('🔍 Récupération des données pour: $userId');
    
    NanaContext context = NanaContext(
      userId: userId,
      role: role,
      userName: userName,
    );
    
    try {
      // 1️⃣ Récupérer les infos de l'utilisateur
      final userDoc = await FirebaseFirestore.instance
          .collection('users_info')
          .doc(userId)
          .get();
      
      print('📄 userDoc existe: ${userDoc.exists}');
      
      if (userDoc.exists) {
        final data = userDoc.data()!;
        print('📄 Données utilisateur: ${data.keys}');
        context = NanaContext(
          userId: userId,
          role: role,
          userName: userName,
          className: data['className'] ?? data['class'] ?? 'Non définie',
        );
      }
      
      // 2️⃣ Si c'est un élève, récupérer ses notes
      if (role == 'student') {
        print('🎓 Récupération des notes pour l\'élève...');
        
        final gradesSnapshot = await FirebaseFirestore.instance
            .collection('grades')
            .where('studentFirestoreId', isEqualTo: userId)
            .get();
        
        print('📊 ${gradesSnapshot.docs.length} notes trouvées');
        
        final grades = gradesSnapshot.docs.map((doc) => doc.data()).toList();
        
        if (grades.isNotEmpty) {
          final Map<String, List<double>> subjectScores = {};
          double total = 0;
          int count = 0;
          
          for (var grade in grades) {
            final subject = grade['subject'] ?? 'Inconnu';
            final score = (grade['score'] as num?)?.toDouble() ?? 0.0;
            final maxScore = (grade['maxScore'] as num?)?.toDouble() ?? 20.0;
            final percentage = maxScore > 0 ? (score / maxScore) * 20 : 0.0;
            
            print('📝 $subject: $score/$maxScore → $percentage/20');
            
            subjectScores.putIfAbsent(subject, () => []);
            subjectScores[subject]!.add(percentage);
            total += percentage;
            count++;
          }
          
          final subjectAverages = <String, double>{};
          final strengths = <String>[];
          final weaknesses = <String>[];
          
          subjectScores.forEach((subject, scores) {
            final avg = scores.reduce((a, b) => a + b) / scores.length;
            subjectAverages[subject] = avg;
            print('📊 $subject: ${avg.toStringAsFixed(2)}/20');
            
            if (avg >= 14) strengths.add(subject);
            if (avg < 10) weaknesses.add(subject);
          });
          
          final average = count > 0 ? total / count : 0.0;
          print('📈 Moyenne générale: ${average.toStringAsFixed(2)}/20');
          
          context = NanaContext(
            userId: userId,
            role: role,
            userName: userName,
            className: context.className,
            grades: grades,
            average: average,
            subjectAverages: subjectAverages,
            strengths: strengths,
            weaknesses: weaknesses,
          );
        } else {
          print('⚠️ Aucune note trouvée pour cet élève');
        }
      }
      
    } catch (e) {
      print('❌ Erreur récupération données: $e');
    }
    
    print('✅ Contexte final: ${context.userName}, ${context.average ?? "N/A"}');
    return context;
  }

  // ================================================================
  // ENVOI DE MESSAGE
  // ================================================================

  static Future<String> sendMessage({
    required String message,
    required String role,
    required String userId,
    required String userName,
    NanaContext? context,
  }) async {
    try {
      print('💬 Message reçu: "$message" (rôle: $role)');
      
      // 🔥 Utiliser le contexte fourni ou le contexte actuel
      final effectiveContext = context ?? _currentContext;
      
      if (effectiveContext == null) {
        print('⚠️ Contexte null, utilisation du fallback');
        return _getFallbackResponse(message, role);
      }
      
      print('📊 Contexte utilisateur: ${effectiveContext.userName}');
      
      // 🔥 Générer la réponse à partir des données Firestore
      final reply = await _generateResponseFromData(
        message: message,
        role: role,
        context: effectiveContext,
      );
      
      print('✅ Réponse générée: ${reply.substring(0, reply.length > 50 ? 50 : reply.length)}...');
      
      _conversationHistory.add({'role': 'user', 'content': message});
      _conversationHistory.add({'role': 'assistant', 'content': reply});
      await _saveHistory(userId);
      
      return reply;
      
    } catch (e) {
      print('❌ Erreur: $e');
      return _getFallbackResponse(message, role);
    }
  }

  // ================================================================
  // GÉNÉRATION DE RÉPONSE À PARTIR DES DONNÉES
  // ================================================================

  static Future<String> _generateResponseFromData({
    required String message,
    required String role,
    required NanaContext context,
  }) async {
    final msg = message.toLowerCase().trim();
    
    print('🔍 Analyse du message: "$msg"');
    
    // ============================================================
    // RÉPONSES POUR LES ÉLÈVES (STUDENTS)
    // ============================================================
    if (role == 'student') {
      
      // 📊 NOTES
      if (msg.contains('note') || msg.contains('moyenne') || msg.contains('résultat') || msg.contains('bulletin')) {
        print('📊 Génération réponse NOTES');
        
        if (context.average == null) {
          return '📊 **Aucune note enregistrée**\n\nVous n\'avez pas encore de notes. Contactez votre professeur pour plus d\'informations.';
        }
        
        String response = '📊 **Vos notes actuelles**\n\n';
        response += '📈 **Moyenne générale : ${context.average!.toStringAsFixed(2)}/20**\n';
        
        if (context.classRank != null && context.totalStudents != null && context.totalStudents! > 0) {
          response += '🏆 **Classement : ${context.classRank}/${context.totalStudents}**\n\n';
        }
        
        if (context.subjectAverages != null && context.subjectAverages!.isNotEmpty) {
          response += '📚 **Détail par matière :**\n';
          context.subjectAverages!.forEach((subject, avg) {
            String emoji = avg >= 15 ? '🌟' : (avg >= 12 ? '✅' : (avg >= 10 ? '📖' : '⚠️'));
            response += '$emoji $subject : ${avg.toStringAsFixed(2)}/20\n';
          });
        }
        
        if (context.strengths != null && context.strengths!.isNotEmpty) {
          response += '\n💪 **Points forts :** ${context.strengths!.join(', ')}';
        }
        
        if (context.weaknesses != null && context.weaknesses!.isNotEmpty) {
          response += '\n\n⚠️ **Points à améliorer :** ${context.weaknesses!.join(', ')}';
          response += '\n\n💡 **Conseil :** Concentre-toi sur ces matières pour progresser.';
        }
        
        return response;
      }
      
      // 📚 ÉTUDE
      if (msg.contains('étudier') || msg.contains('réviser') || msg.contains('conseil') || msg.contains('étude')) {
        print('📚 Génération réponse ÉTUDE');
        
        String response = '📚 **Conseils d\'étude personnalisés**\n\n';
        
        if (context.weaknesses != null && context.weaknesses!.isNotEmpty) {
          response += '🎯 **Priorité sur :** ${context.weaknesses!.join(', ')}\n';
          response += '⏰ Réviser 30 minutes par jour pour ces matières.\n\n';
        }
        
        response += '''
📝 **Méthode efficace :**
1. Fiches de révision : résume chaque chapitre
2. Exercices pratiques : fais les exercices proposés
3. Groupes d'étude : travaille en groupe pour partager
4. Technique Pomodoro : 25 min d'étude, 5 min de pause

💡 **Rappel :** La régularité est la clé du succès !
''';
        return response;
      }
      
      // 🎓 ORIENTATION
      if (msg.contains('orientation') || msg.contains('filière') || msg.contains('métier') || msg.contains('avenir')) {
        print('🎓 Génération réponse ORIENTATION');
        
        String response = '🎓 **Conseils d\'orientation**\n\n';
        
        if (context.strengths != null && context.strengths!.isNotEmpty) {
          response += '💪 **Vos points forts :** ${context.strengths!.join(', ')}\n\n';
          response += '🏛️ **Filières recommandées :**\n';
          for (var subject in context.strengths!) {
            if (subject.contains('Math') || subject.contains('Physique') || subject.contains('Sciences')) {
              response += '  • Sciences et technologies\n';
            } else if (subject.contains('Français') || subject.contains('Littérature') || subject.contains('Histoire')) {
              response += '  • Lettres et sciences humaines\n';
            } else if (subject.contains('Anglais') || subject.contains('Langue')) {
              response += '  • Langues et communication\n';
            }
          }
        }
        
        response += '''
\n🗣️ **Que faire maintenant ?**
1. Parle avec tes professeurs de tes ambitions
2. Participe aux journées portes ouvertes
3. Explore différents métiers en stage
4. Consulte le conseiller d'orientation

💡 Tu as du potentiel, continue à explorer !
''';
        return response;
      }
    }
    
    // ============================================================
    // RÉPONSES POUR LES ENSEIGNANTS (TEACHERS)
    // ============================================================
    if (role == 'teacher') {
      if (msg.contains('note') || msg.contains('moyenne') || msg.contains('ajouter')) {
        return '''
📝 **Gestion des notes**

Pour ajouter des notes :
1. Allez dans "Gestion des notes"
2. Sélectionnez votre classe
3. Choisissez l'évaluation (Devoir 1, Devoir 2, Examen)
4. Entrez les notes et validez

💡 **Conseil :** Utilisez des coefficients pour pondérer les notes.
📊 Les moyennes sont calculées automatiquement.
''';
      }
      
      if (msg.contains('examen') || msg.contains('test') || msg.contains('qcm')) {
        return '''
📋 **Création d'examen**

Pour créer un examen :
1. Allez dans "Examens en ligne"
2. Cliquez sur "Créer un examen"
3. Remplissez les informations (titre, date, durée)
4. Ajoutez les questions (QCM, vrai/faux, réponses courtes)
5. Publiez l'examen

✅ Les QCM sont automatiquement corrigés.
📊 Les résultats sont visibles instantanément.
''';
      }
    }
    
    // ============================================================
    // RÉPONSES POUR LES PARENTS (PARENTS)
    // ============================================================
    if (role == 'parent') {
      if (msg.contains('enfant') || msg.contains('suivi') || msg.contains('progrès')) {
        String response = '👶 **Suivi de votre enfant**\n\n';
        
        if (context.average != null) {
          response += '📊 **Moyenne : ${context.average!.toStringAsFixed(2)}/20**\n';
        }
        
        if (context.className != null) {
          response += '🏫 **Classe : ${context.className}**\n';
        }
        
        if (context.strengths != null && context.strengths!.isNotEmpty) {
          response += '\n💪 **Points forts :** ${context.strengths!.join(', ')}\n';
        }
        
        if (context.weaknesses != null && context.weaknesses!.isNotEmpty) {
          response += '\n⚠️ **Points à améliorer :** ${context.weaknesses!.join(', ')}\n';
        }
        
        response += '''
\n💡 **Comment aider votre enfant ?**
1. Encouragez-le à étudier régulièrement
2. Créez un espace de travail calme
3. Suivez ses résultats sur l'application
4. Communiquez avec ses professeurs

📱 Consultez toutes les infos dans "Suivi enfant".
''';
        return response;
      }
    }
    
    // ============================================================
    // SALUTATIONS
    // ============================================================
    if (msg.contains('bonjour') || msg.contains('salut') || msg.contains('coucou')) {
      final greetings = [
        '👋 Bonjour ! Comment puis-je vous aider aujourd\'hui ?',
        '🌟 Bonjour ! Je suis ravi(e) de vous voir !',
        '🌞 Bonjour ! Quelle belle journée pour apprendre !',
      ];
      return greetings[DateTime.now().second % greetings.length];
    }
    
    if (msg.contains('merci') || msg.contains('merci beaucoup')) {
      return '🙏 Avec plaisir ! Je suis là pour vous aider. N\'hésitez pas si vous avez d\'autres questions.';
    }
    
    if (msg.contains('qui es-tu') || msg.contains('qui es tu')) {
      return '🤖 Je suis Nana, votre assistant intelligent de EscaSchool. Je suis là pour vous aider dans votre parcours scolaire.';
    }
    
    // ============================================================
    // RÉPONSE GÉNÉRIQUE
    // ============================================================
    return '''
🤖 **Je suis Nana, votre assistant intelligent !**

Voici ce que je peux faire pour vous :

${role == 'student' ? '''
📊 **Voir mes notes**
📚 **Conseils d'étude**
🎓 **Orientation scolaire**
📅 **Emploi du temps**
''' : role == 'teacher' ? '''
📝 **Gérer les notes**
📋 **Créer des examens**
👨‍🎓 **Suivre les élèves**
📚 **Organiser les cours**
''' : role == 'parent' ? '''
👶 **Suivi de votre enfant**
📊 **Consulter les notes**
📝 **Aide aux devoirs**
💳 **Gérer les paiements**
''' : '''
📊 **Statistiques**
🏛️ **Gestion des écoles**
👥 **Gestion des utilisateurs**
⚙️ **Configuration**
'''}

💡 **Posez-moi une question précise pour obtenir une réponse personnalisée !**
''';
  }

  // ================================================================
  // RÉPONSES DE FALLBACK
  // ================================================================

  static String _getFallbackResponse(String message, String role) {
    final msg = message.toLowerCase();
    
    if (msg.contains('bonjour') || msg.contains('salut')) {
      return '👋 Bonjour ! Je suis Nana. Comment puis-je vous aider ?';
    }
    
    if (msg.contains('merci')) {
      return '🙏 Avec plaisir !';
    }
    
    if (role == 'student') {
      return '🎓 Bonjour ! Je suis Nana, votre assistante scolaire. ' + 
             'Je peux vous aider à consulter vos notes, étudier plus efficacement, ' +
             'ou vous orienter dans vos choix. Que voulez-vous savoir ?';
    }
    
    if (role == 'teacher') {
      return '👨‍🏫 Bonjour cher enseignant ! Je suis Nana. ' +
             'Je peux vous aider à gérer les notes, créer des examens, ' +
             'ou suivre vos élèves. Comment puis-je vous assister ?';
    }
    
    return '🤖 Bonjour ! Je suis Nana, votre assistant intelligent. ' +
           'Que puis-je faire pour vous aujourd\'hui ?';
  }

  // ================================================================
  // GESTION DE L'HISTORIQUE
  // ================================================================

  static Future<void> _saveHistory(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = jsonEncode(_conversationHistory);
      await prefs.setString('nana_history_$userId', historyJson);
    } catch (e) {
      print('⚠️ Erreur sauvegarde: $e');
    }
  }

  static Future<void> clearHistory(String userId) async {
    _conversationHistory.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('nana_history_$userId');
    } catch (e) {
      print('⚠️ Erreur suppression: $e');
    }
  }

  // ================================================================
  // SUGGESTIONS
  // ================================================================

  static List<String> getSuggestions(String role) {
    switch (role) {
      case 'student':
        return ['📊 Mes notes', '📚 Conseils d\'étude', '🎓 Orientation', '📅 Emploi du temps'];
      case 'teacher':
        return ['📝 Ajouter des notes', '📋 Créer un examen', '👨‍🎓 Suivi des élèves', '📊 Performance'];
      case 'parent':
        return ['👶 Suivi enfant', '📊 Notes', '📝 Aide', '💳 Paiements'];
      case 'admin':
        return ['📚 Gestion classes', '👨‍🏫 Professeurs', '📊 Rapports', '💰 Finances'];
      case 'super_admin':
        return ['📊 Statistiques', '🏛️ Écoles', '👥 Utilisateurs', '⚙️ Configuration'];
      default:
        return ['👋 Bonjour', '🤔 Aide', '💡 Conseils'];
    }
  }
}