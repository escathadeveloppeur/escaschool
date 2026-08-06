// lib/services/nana_local_ai.dart
import 'dart:math';

class NanaLocalAI {
  // ✅ BASE DE CONNAISSANCES ENRICHIE
  static final Map<String, Map<String, List<String>>> _knowledgeBase = {
    'super_admin': {
      'ecole': [
        '🏛️ Pour créer une nouvelle école, allez dans "Gestion des écoles" depuis le tableau de bord.',
        '📊 Les statistiques globales sont disponibles dans le tableau de bord principal.',
        '👥 Vous pouvez gérer tous les utilisateurs de la plateforme depuis "Gestion des utilisateurs".',
        '⚙️ La configuration système est dans "Paramètres" > "Configuration globale".',
        '📋 Chaque école a un code unique pour l\'inscription des utilisateurs.',
      ],
      'utilisateur': [
        '👤 Pour ajouter un utilisateur, allez dans "Gestion des utilisateurs" et cliquez sur "Ajouter".',
        '🔑 Les rôles disponibles : Super Admin, Admin, Enseignant, Personnel, Élève, Parent.',
        '📧 Les utilisateurs reçoivent une notification par email lors de leur inscription.',
        '🔄 Vous pouvez désactiver ou supprimer un utilisateur depuis son profil.',
      ],
      'statistique': [
        '📈 Les statistiques globales montrent toutes les écoles de la plateforme.',
        '📊 Vous pouvez voir le nombre d\'élèves par école et par classe.',
        '💰 Les revenus sont affichés dans "Rapports financiers" > "Résumé global".',
        '📉 Les tendances de performance sont disponibles sur 12 mois.',
      ],
      'paiement': [
        '💳 Les paiements sont gérés dans "Gestion des paiements" > "Toutes les écoles".',
        '📊 Vous pouvez voir les statistiques de paiement par école.',
        '💰 Les frais de plateforme sont calculés automatiquement.',
      ],
    },
    'admin': {
      'classe': [
        '📚 Pour créer une classe, allez dans "Gestion des classes" et cliquez sur "Nouvelle classe".',
        '👨‍🏫 Vous pouvez assigner des professeurs aux classes depuis leur profil.',
        '📋 Les sections et niveaux sont configurables dans "Paramètres de la classe".',
        '👥 Les effectifs sont automatiquement comptés par le système.',
        '📅 Vous pouvez définir l\'emploi du temps par classe.',
      ],
      'professeur': [
        '👨‍🏫 Pour ajouter un professeur, allez dans "Gestion des professeurs" > "Ajouter".',
        '📝 Assignez les matières aux professeurs depuis "Gestion des matières".',
        '🔑 Gérez les permissions d\'accès dans "Rôles et permissions".',
        '📅 Consultez les plannings des professeurs dans "Emploi du temps".',
      ],
      'rapport': [
        '📊 Les rapports de performance sont disponibles dans "Rapports" > "Performance".',
        '📈 Suivez les résultats par classe, matière et professeur.',
        '📤 Exportez les données en PDF, Excel ou CSV.',
        '📉 Analysez les tendances sur l\'année scolaire.',
      ],
      'eleve': [
        '👨‍🎓 Gérez tous les élèves dans "Gestion des élèves".',
        '📝 Les inscriptions sont gérées dans "Inscriptions".',
        '📊 Suivez les performances par élève.',
        '📧 Les parents reçoivent les notifications automatiquement.',
      ],
    },
    'teacher': {
      'note': [
        '📝 Pour ajouter des notes, allez dans "Gestion des notes" et sélectionnez votre classe.',
        '📊 Vous pouvez ajouter des notes par élève ou pour toute la classe en une fois.',
        '📈 Les notes sont automatiquement sauvegardées dans Firestore.',
        '🎯 Utilisez des coefficients pour pondérer les notes (1, 2, 3...).',
        '📤 Exportez les notes en PDF ou Excel depuis le tableau des notes.',
        '📋 Les notes sont organisées par semestre (S1, S2) et par période (P1, P2, EX1, EX2).',
      ],
      'examen': [
        '📋 Créez des examens dans "Examens en ligne" > "Créer un examen".',
        '✅ Les QCM sont automatiquement corrigés par le système.',
        '📅 Programmez des examens à date fixe avec rappel automatique.',
        '📊 Les résultats sont visibles instantanément pour les élèves.',
        '📝 Vous pouvez créer des questions à choix multiples, vrai/faux, ou réponses courtes.',
      ],
      'eleve': [
        '👨‍🎓 Suivez la progression de chaque élève dans "Suivi des élèves".',
        '⚠️ Identifiez les élèves en difficulté grâce aux alertes automatiques.',
        '📈 Consultez l\'historique complet des notes et appréciations.',
        '💬 Communiquez avec les parents via le module "Messages".',
        '📊 Les rapports individuels sont disponibles en PDF.',
      ],
      'cours': [
        '📚 Créez des cours structurés par chapitres et sous-chapitres.',
        '📎 Ajoutez des ressources (PDF, vidéos, liens, images).',
        '💻 Les cours sont accessibles 24h/24 aux élèves.',
        '📝 Les élèves peuvent poser des questions sur chaque chapitre.',
        '📊 Suivez la consultation des cours par les élèves.',
      ],
      'presence': [
        '📋 Gérez les présences dans "Gestion des présences".',
        '✅ Faites l\'appel pour toute la classe en une fois.',
        '📊 Consultez les statistiques de présence par élève.',
        '📧 Les parents sont informés automatiquement des absences.',
      ],
    },
    'student': {
      'note': [
        '📊 Consultez vos notes dans "Mes notes" > "Voir mes résultats".',
        '🎯 Votre moyenne générale est calculée automatiquement par le système.',
        '📈 Voyez votre progression par matière avec des graphiques.',
        '💬 Les appréciations de vos professeurs sont disponibles.',
        '📋 Les notes sont détaillées par période (P1, P2, EX1, EX2).',
      ],
      'etude': [
        '📚 Révisez régulièrement (30 minutes par jour) pour de meilleurs résultats.',
        '📝 Faites des fiches de révision pour chaque matière.',
        '🎯 Pratiquez avec des exercices en ligne proposés par vos professeurs.',
        '😴 Dormez suffisamment (8h par nuit) pour une bonne concentration.',
        '⏰ Utilisez la technique Pomodoro : 25min d\'étude, 5min de pause.',
        '📖 Consultez les cours en ligne pour réviser à votre rythme.',
      ],
      'orientation': [
        '🎯 Identifiez vos matières fortes pour choisir votre filière.',
        '👨‍🏫 Parlez avec vos professeurs de vos projets d\'avenir.',
        '🏫 Explorez les différentes filières disponibles à l\'université.',
        '📅 Participez aux journées portes ouvertes des universités.',
        '💼 Faites des stages pour découvrir les métiers.',
        '📊 Consultez les statistiques de réussite par filière.',
      ],
      'examen': [
        '📅 Consultez le calendrier des examens dans "Examens" > "Calendrier".',
        '📝 Préparez-vous avec des examens blancs disponibles en ligne.',
        '📊 Consultez vos résultats dès leur publication.',
        '⏰ Arrivez à l\'heure aux examens (15 minutes avant).',
        '📚 Révisez les chapitres indiqués par vos professeurs.',
      ],
      'cours': [
        '📚 Accédez à tous vos cours dans "Mes cours".',
        '📎 Téléchargez les ressources mises à disposition par vos professeurs.',
        '💻 Les cours sont accessibles 24h/24, 7j/7.',
        '📝 Posez des questions sur les chapitres que vous ne comprenez pas.',
        '📊 Suivez votre progression dans la consultation des cours.',
      ],
    },
    'parent': {
      'enfant': [
        '👶 Consultez les notes de votre enfant dans "Suivi enfant" > "Notes".',
        '📊 Suivez les présences et absences dans "Présences".',
        '📅 Visualisez l\'emploi du temps de votre enfant.',
        '📧 Recevez les communications de l\'école et des professeurs.',
        '📈 Suivez l\'évolution des performances de votre enfant.',
      ],
      'aide': [
        '💪 Encouragez votre enfant à étudier régulièrement, pas seulement avant les examens.',
        '📚 Créez un espace de travail calme et bien éclairé.',
        '👨‍🏫 Soyez présent aux réunions parents-professeurs.',
        '📱 Utilisez l\'application pour suivre les devoirs et les résultats.',
        '🎯 Félicitez les efforts, pas seulement les résultats.',
      ],
      'paiement': [
        '💳 Consultez les frais scolaires dans "Paiements" > "Frais scolaires".',
        '📱 Effectuez les paiements en ligne en toute sécurité.',
        '📄 Recevez des reçus et factures par email.',
        '📊 Suivez l\'historique complet des paiements.',
        '⏰ Vous recevez un rappel avant chaque échéance.',
      ],
      'communication': [
        '📧 Consultez les messages des professeurs dans "Messages".',
        '💬 Répondez aux professeurs via l\'application.',
        '📅 Soyez informé des événements scolaires.',
        '📋 Consultez les bulletins de notes en PDF.',
      ],
    },
  };

  // ✅ MOTS-CLÉS ENRICHIS
  static final Map<String, List<String>> _keywords = {
    'bonjour': [
      'Bonjour ! 🌟 Comment puis-je vous aider aujourd\'hui ?',
      'Bonjour ! Quelle belle journée ! Je suis Nana, votre assistante. 😊',
      'Bonjour ! Je suis ravie de vous voir. Que puis-je faire pour vous ? 💙',
    ],
    'merci': [
      'Avec plaisir ! Je suis là pour vous aider. 😊',
      'Merci à vous pour votre confiance ! 🙏',
      'C\'est un honneur de vous assister ! 🌟',
    ],
    'aide': [
      'Je suis là pour vous aider ! 💪 Que voulez-vous savoir ?',
      'Je suis à votre disposition ! 🌟 Posez-moi n\'importe quelle question.',
      'Comment puis-je vous assister aujourd\'hui ? 🤔',
    ],
    'qui es tu': [
      'Je suis Nana, votre assistante intelligente de EscaSchool 🤖',
      'Je suis l\'IA de EscaSchool, conçue pour faciliter votre quotidien scolaire ! 💙',
      'Je suis Nana, votre guide dans l\'application EscaSchool. 🎯',
    ],
    'comment ca va': [
      'Je vais très bien, merci ! Et vous ? 😊',
      'Je suis en pleine forme ! Comment puis-je vous aider ? 🌟',
      'Super ! Je suis prête à vous assister ! 💪',
    ],
    'que fais tu': [
      'Je suis votre assistante ! Je vous aide à gérer vos notes, vos examens, et bien plus encore. 📚',
      'Je suis là pour faciliter votre expérience sur EscaSchool ! 🎯',
      'Je vous guide dans toutes les fonctionnalités de l\'application ! 🤖',
    ],
  };

  // ✅ Mots-clés avancés par rôle
  static final Map<String, Map<String, List<String>>> _advancedKeywords = {
    'teacher': {
      'ajouter note': [
        'Pour ajouter une note : 1. Allez dans "Gestion des notes" 2. Sélectionnez la classe 3. Choisissez l\'élève 4. Entrez la note et validez. 📝',
        'Les notes s\'ajoutent facilement depuis "Gestion des notes". Vous pouvez aussi ajouter pour toute la classe. 📊',
      ],
      'moyenne classe': [
        'La moyenne de la classe est calculée automatiquement. Vous la trouvez dans "Gestion des notes" > "Statistiques". 📊',
        'Consultez la moyenne par matière dans "Rapports" > "Performance de la classe". 📈',
      ],
      'creer examen': [
        'Pour créer un examen : 1. Allez dans "Examens en ligne" 2. Cliquez sur "Créer" 3. Remplissez les informations 4. Ajoutez les questions. 📋',
        'Les examens en ligne se créent facilement. Vous pouvez ajouter des QCM, des questions ouvertes, et des fichiers. 📝',
      ],
      'eleve difficile': [
        'Pour identifier les élèves en difficulté, allez dans "Suivi des élèves" et filtrez par moyenne. ⚠️',
        'Le système alerte automatiquement quand un élève est en dessous de 10/20. 📊',
      ],
    },
    'student': {
      'mes notes': [
        'Vos notes sont disponibles dans "Mes notes" > "Voir mes résultats". Vous y verrez toutes vos matières et périodes. 📊',
        'Consultez vos notes par matière et par période (P1, P2, EX1, EX2). 🎯',
      ],
      'comment reussir': [
        'Pour réussir : 1. Révisez régulièrement 2. Faites les exercices 3. Posez des questions 4. Dormez bien. 💪',
        'La clé du succès : régularité, organisation et motivation ! 🎯',
      ],
      'plan etude': [
        'Un bon plan d\'étude : 1. Priorisez les matières difficiles 2. Révisez 30 min par jour 3. Faites des pauses. 📚',
        'Organisez votre temps avec un emploi du temps d\'étude. ⏰',
      ],
    },
    'parent': {
      'suivi enfant': [
        'Pour suivre votre enfant : 1. Allez dans "Suivi enfant" 2. Consultez les notes, présences, et emploi du temps. 👶',
        'Toutes les informations sur votre enfant sont centralisées dans "Suivi enfant". 📊',
      ],
      'paiement ecole': [
        'Les paiements se font dans "Paiements" > "Frais scolaires". Vous pouvez payer en ligne. 💳',
        'Consultez les frais et effectuez les paiements en toute sécurité. 📱',
      ],
    },
  };

  static String getResponse({
    required String message,
    required String role,
    required String userName,
  }) {
    final msg = message.toLowerCase().trim();
    final random = Random();

    // 1️⃣ Vérifier les salutations de base
    for (final keyword in _keywords.keys) {
      if (msg.contains(keyword)) {
        final responses = _keywords[keyword]!;
        return responses[random.nextInt(responses.length)];
      }
    }

    // 2️⃣ Vérifier les mots-clés avancés par rôle
    final advanced = _advancedKeywords[role];
    if (advanced != null) {
      for (final keyword in advanced.keys) {
        if (msg.contains(keyword)) {
          final responses = advanced[keyword]!;
          return responses[random.nextInt(responses.length)];
        }
      }
    }

    // 3️⃣ Vérifier les mots-clés de la base de connaissances
    final knowledge = _knowledgeBase[role];
    if (knowledge != null) {
      for (final category in knowledge.keys) {
        if (msg.contains(category)) {
          final responses = knowledge[category]!;
          return responses[random.nextInt(responses.length)];
        }
      }
    }

    // 4️⃣ Vérifier les mots-clés génériques
    final genericKeywords = ['note', 'examen', 'cours', 'presence', 'classe', 'professeur', 'enfant', 'paiement'];
    for (final keyword in genericKeywords) {
      if (msg.contains(keyword)) {
        // Chercher dans tous les rôles
        for (final roleKey in _knowledgeBase.keys) {
          final roleKnowledge = _knowledgeBase[roleKey];
          if (roleKnowledge != null && roleKnowledge.containsKey(keyword)) {
            final responses = roleKnowledge[keyword]!;
            return responses[random.nextInt(responses.length)];
          }
        }
      }
    }

    // 5️⃣ Réponse générique
    return _getGenericResponse(role, userName);
  }

  static String _getGenericResponse(String role, String userName) {
    final random = Random();
    final responses = [
      _getRoleSpecificHelp(role),
      _getRoleSpecificSuggestion(role),
      _getEncouragement(userName),
      _getQuestionSuggestion(role),
    ];
    return responses[random.nextInt(responses.length)];
  }

  static String _getRoleSpecificHelp(String role) {
    switch (role) {
      case 'super_admin':
        return '🏛️ Je peux vous aider avec : les écoles, les utilisateurs, les statistiques globales, les paiements, ou la configuration système.';
      case 'admin':
        return '🏫 Je peux vous aider avec : les classes, les professeurs, les élèves, les rapports, ou les finances.';
      case 'teacher':
        return '👨‍🏫 Je peux vous aider avec : les notes, les examens, les élèves, les cours, ou les présences.';
      case 'student':
        return '🎓 Je peux vous aider avec : vos notes, l\'étude, l\'orientation, les examens, ou l\'emploi du temps.';
      case 'parent':
        return '👪 Je peux vous aider à suivre : les notes de votre enfant, les présences, les paiements, ou les communications.';
      default:
        return '🤖 Je suis Nana, votre assistante. Que puis-je faire pour vous ?';
    }
  }

  static String _getRoleSpecificSuggestion(String role) {
    switch (role) {
      case 'super_admin':
        return '💡 Je vous suggère de consulter les statistiques globales ou de gérer les écoles.';
      case 'admin':
        return '💡 Je vous suggère de vérifier les effectifs ou les rapports de performance.';
      case 'teacher':
        return '💡 Je vous suggère de consulter les notes de vos élèves ou de préparer vos cours.';
      case 'student':
        return '💡 Je vous suggère de réviser régulièrement ou de consulter vos résultats.';
      case 'parent':
        return '💡 Je vous suggère de suivre les progrès de votre enfant ou de communiquer avec l\'école.';
      default:
        return '💡 N\'hésitez pas à me poser une question précise.';
    }
  }

  static String _getQuestionSuggestion(String role) {
    switch (role) {
      case 'teacher':
        return '📝 Vous pouvez me poser des questions comme : "Comment ajouter des notes ?" ou "Quelle est la moyenne de la classe ?"';
      case 'student':
        return '📚 Vous pouvez me poser des questions comme : "Comment consulter mes notes ?" ou "Comment bien réviser ?"';
      case 'parent':
        return '👶 Vous pouvez me poser des questions comme : "Comment suivre mon enfant ?" ou "Comment payer les frais scolaires ?"';
      default:
        return '💡 Posez-moi une question, je vous répondrai avec plaisir !';
    }
  }

  static String _getEncouragement(String userName) {
    final encouragements = [
      '🌟 $userName, continuez votre excellent travail !',
      '💪 $userName, vous êtes sur la bonne voie !',
      '🎯 $userName, gardez cette motivation !',
      '✨ $userName, votre implication est remarquable !',
      '🏆 $userName, vous êtes un modèle !',
      '🌈 $userName, chaque jour est une nouvelle opportunité !',
      '🔥 $userName, vous brillez par votre détermination !',
    ];
    final random = Random();
    return encouragements[random.nextInt(encouragements.length)];
  }

  static List<String> getSuggestions(String role) {
    switch (role) {
      case 'super_admin':
        return ['📊 Statistiques globales', '🏛️ Gérer les écoles', '👥 Utilisateurs', '⚙️ Configuration'];
      case 'admin':
        return ['📚 Gérer les classes', '👨‍🏫 Professeurs', '📊 Rapports', '💰 Finances'];
      case 'teacher':
        return ['📝 Ajouter des notes', '📊 Moyenne de la classe', '📋 Créer un examen', '👨‍🎓 Élèves en difficulté'];
      case 'student':
        return ['📊 Mes notes', '📚 Comment réviser', '🎓 Orientation', '📅 Emploi du temps'];
      case 'parent':
        return ['👶 Suivi enfant', '📊 Notes de mon enfant', '📝 Aide aux devoirs', '💳 Paiements'];
      default:
        return ['👋 Bonjour', '🤔 Aide', '💡 Conseils'];
    }
  }
}