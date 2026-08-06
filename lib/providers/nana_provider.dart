// lib/providers/nana_provider.dart
import 'package:flutter/material.dart';
import '../services/nana_ai_service.dart';
import '../models/nana_context.dart';

class NanaProvider extends ChangeNotifier {
  List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  bool _isChatOpen = false;
  String? _errorMessage;
  String _currentMessage = '';
  
  // 🔥 Contexte utilisateur (pour suivre l'état)
  NanaContext? _userContext;
  
  // Getters
  List<Map<String, String>> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isChatOpen => _isChatOpen;
  String? get errorMessage => _errorMessage;
  String get currentMessage => _currentMessage;
  NanaContext? get userContext => _userContext;
  
  // Initialisation
  Future<void> initialize({
    required String role,
    required String userId,
    required String userName,
    String? schoolId,
  }) async {
    // 🔥 Initialiser le contexte avec les données
    await NanaAIService.initializeContext(
      role: role,
      userId: userId,
      userName: userName,
      schoolId: schoolId,
    );
    
    // 🔥 Récupérer le contexte enrichi
    _userContext = await NanaAIService.getUserContext();
    
    // Message de bienvenue personnalisé
    _messages.clear();
    _addSystemMessage('👋 Bonjour ! Je suis Nana, votre assistant intelligent.');
    
    String welcomeMessage = _buildWelcomeMessage(role, _userContext);
    _addSystemMessage(welcomeMessage);
    
    // 🔥 Ajouter un résumé si disponible
    if (_userContext != null && role == 'student') {
      final summary = _userContext!.getSummary();
      _addSystemMessage(summary);
    }
    
    notifyListeners();
  }
  
  // 🎯 Construire le message de bienvenue personnalisé
  String _buildWelcomeMessage(String role, NanaContext? context) {
    String baseMessage = '';
    
    switch (role) {
      case 'super_admin':
        baseMessage = '🏛️ Bonjour Super Admin ! Je suis Nana.';
        if (context != null) {
          baseMessage += '\n\n📊 Je vois que vous gérez plusieurs écoles. Que voulez-vous analyser aujourd\'hui ?';
        }
        break;
      case 'admin':
        baseMessage = '🏫 Bonjour Admin ! Je suis Nana.';
        if (context != null && context.className != null) {
          baseMessage += '\n\n📚 Vous gérez la classe ${context.className}. Comment puis-je vous aider ?';
        }
        break;
      case 'teacher':
        baseMessage = '👨‍🏫 Bonjour cher enseignant ! Je suis Nana.';
        if (context != null && context.className != null) {
          baseMessage += '\n\n📚 Vous enseignez en ${context.className}. Je suis là pour vous aider avec vos élèves.';
        } else {
          baseMessage += '\n\n📚 Je suis là pour vous aider avec vos élèves, vos notes et vos examens.';
        }
        break;
      case 'student':
        baseMessage = '🎓 Bonjour ! Je suis Nana.';
        if (context != null && context.average != null) {
          final avg = context.average!;
          String emoji = avg >= 15 ? '🌟' : (avg >= 12 ? '📈' : '💪');
          baseMessage += '\n\n$emoji Votre moyenne est de ${avg.toStringAsFixed(2)}/20.';
          
          if (context.strengths != null && context.strengths!.isNotEmpty) {
            baseMessage += '\n💪 Vos points forts : ${context.strengths!.join(', ')}.';
          }
          if (context.weaknesses != null && context.weaknesses!.isNotEmpty) {
            baseMessage += '\n⚠️ Points à améliorer : ${context.weaknesses!.join(', ')}.';
          }
          baseMessage += '\n\nComment puis-je vous aider à progresser ?';
        } else {
          baseMessage += '\n\n🎯 Je suis là pour vous aider à réussir. N\'hésitez pas à me poser des questions !';
        }
        break;
      case 'parent':
        baseMessage = '👪 Bonjour ! Je suis Nana.';
        if (context != null && context.className != null) {
          baseMessage += '\n\n👶 Vous suivez un enfant en ${context.className}.';
          if (context.average != null) {
            baseMessage += ' Sa moyenne est de ${context.average!.toStringAsFixed(2)}/20.';
          }
          baseMessage += '\n\nQue voulez-vous savoir aujourd\'hui ?';
        } else {
          baseMessage += '\n\n👶 Je suis là pour vous aider à suivre la scolarité de votre enfant.';
        }
        break;
      default:
        baseMessage = '👋 Bonjour ! Je suis Nana, votre assistant. Comment puis-je vous aider ?';
    }
    
    return baseMessage;
  }
  
  // Envoyer un message
  Future<void> sendMessage({
    required String message,
    required String role,
    required String userId,
    required String userName,
  }) async {
    if (message.trim().isEmpty) return;
    
    _currentMessage = message;
    _addUserMessage(message);
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      // 🔥 Passer le contexte utilisateur
      final reply = await NanaAIService.sendMessage(
        message: message,
        role: role,
        userId: userId,
        userName: userName,
        context: _userContext, // 🔥 Passer le contexte
      );
      _addAssistantMessage(reply);
      
      // 🔥 Mettre à jour le contexte après la réponse
      _userContext = await NanaAIService.getUserContext();
      
    } catch (e) {
      _errorMessage = 'Erreur: $e';
      _addAssistantMessage('😅 Désolé, une erreur s\'est produite. Veuillez réessayer.');
    } finally {
      _isLoading = false;
      _currentMessage = '';
      notifyListeners();
    }
  }
  
  void _addUserMessage(String content) {
    _messages.add({
      'role': 'user',
      'content': content,
      'timestamp': DateTime.now().toString(),
    });
  }
  
  void _addAssistantMessage(String content) {
    _messages.add({
      'role': 'assistant',
      'content': content,
      'timestamp': DateTime.now().toString(),
    });
  }
  
  void _addSystemMessage(String content) {
    _messages.add({
      'role': 'system',
      'content': content,
      'timestamp': DateTime.now().toString(),
    });
  }
  
  List<String> getSuggestions(String role) {
    // 🔥 Suggestions personnalisées selon le contexte
    if (_userContext != null && role == 'student') {
      final context = _userContext!;
      
      // Suggestions basées sur les points faibles
      if (context.weaknesses != null && context.weaknesses!.isNotEmpty) {
        final weakSubject = context.weaknesses!.first;
        return [
          '📊 Comment améliorer mes notes en $weakSubject ?',
          '📚 Conseils pour réviser efficacement',
          '🎯 Suivre ma progression',
          '📝 Voir mes examens à venir',
        ];
      }
    }
    
    if (_userContext != null && role == 'teacher') {
      return [
        '📝 Ajouter des notes rapidement',
        '📊 Analyser les performances de la classe',
        '📋 Créer un examen',
        '👨‍🎓 Identifier les élèves en difficulté',
      ];
    }
    
    return NanaAIService.getSuggestions(role);
  }
  
  void toggleChat() {
    _isChatOpen = !_isChatOpen;
    notifyListeners();
  }
  
  Future<void> clearHistory(String userId) async {
    await NanaAIService.clearHistory(userId);
    _messages.clear();
    _addSystemMessage('🧹 Historique effacé. Une nouvelle conversation commence !');
    notifyListeners();
  }
  
  // 🔥 Rafraîchir le contexte utilisateur
  Future<void> refreshContext({
    required String role,
    required String userId,
    required String userName,
  }) async {
    _userContext = await NanaAIService.getUserContext();
    notifyListeners();
  }
}