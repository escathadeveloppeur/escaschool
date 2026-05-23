// lib/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000/api';
  
  // ================= AUTHENTIFICATION =================
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      await prefs.setString('user_id', data['user']['id'].toString());
      await prefs.setString('user_role', data['user']['user_type']);
      return data;
    } else {
      throw Exception('Login failed: ${response.body}');
    }
  }
  
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user_id');
    await prefs.remove('user_role');
  }
  
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }
  
  Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
  
  // ================= TEST CONNEXION =================
  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/test'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('Erreur connexion: $e');
      return false;
    }
  }
  
  // ================= CLASSES =================
  Future<List<dynamic>> getClasses() async {
    final headers = await _getHeaders();
    
    final response = await http.get(
      Uri.parse('$baseUrl/classes'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    } else {
      throw Exception('Failed to load classes: ${response.statusCode}');
    }
  }
  
  Future<Map<String, dynamic>> createClass(Map<String, dynamic> classData) async {
    final headers = await _getHeaders();
    
    final response = await http.post(
      Uri.parse('$baseUrl/classes'),
      headers: headers,
      body: jsonEncode(classData),
    );
    
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create class: ${response.statusCode}');
    }
  }
  
  Future<Map<String, dynamic>> getClass(int id) async {
    final headers = await _getHeaders();
    
    final response = await http.get(
      Uri.parse('$baseUrl/classes/$id'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    } else {
      throw Exception('Failed to get class: ${response.statusCode}');
    }
  }
  
  Future<Map<String, dynamic>> updateClass(int id, Map<String, dynamic> classData) async {
    final headers = await _getHeaders();
    
    final response = await http.put(
      Uri.parse('$baseUrl/classes/$id'),
      headers: headers,
      body: jsonEncode(classData),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update class: ${response.statusCode}');
    }
  }
  
  Future<void> deleteClass(int id) async {
    final headers = await _getHeaders();
    
    final response = await http.delete(
      Uri.parse('$baseUrl/classes/$id'),
      headers: headers,
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to delete class: ${response.statusCode}');
    }
  }
  
  // ================= PROFESSEURS =================
  Future<List<dynamic>> getProfesseurs() async {
    final headers = await _getHeaders();
    
    final response = await http.get(
      Uri.parse('$baseUrl/professeurs'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    } else {
      throw Exception('Failed to load professeurs: ${response.statusCode}');
    }
  }
  
  Future<Map<String, dynamic>> createProfesseur(Map<String, dynamic> professeurData) async {
    final headers = await _getHeaders();
    
    final response = await http.post(
      Uri.parse('$baseUrl/professeurs'),
      headers: headers,
      body: jsonEncode(professeurData),
    );
    
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create professeur: ${response.statusCode}');
    }
  }
  
  Future<Map<String, dynamic>> getProfesseur(int id) async {
    final headers = await _getHeaders();
    
    final response = await http.get(
      Uri.parse('$baseUrl/professeurs/$id'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    } else {
      throw Exception('Failed to get professeur: ${response.statusCode}');
    }
  }
  
  Future<Map<String, dynamic>> updateProfesseur(int id, Map<String, dynamic> professeurData) async {
    final headers = await _getHeaders();
    
    final response = await http.put(
      Uri.parse('$baseUrl/professeurs/$id'),
      headers: headers,
      body: jsonEncode(professeurData),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update professeur: ${response.statusCode}');
    }
  }
  
  Future<void> deleteProfesseur(int id) async {
    final headers = await _getHeaders();
    
    final response = await http.delete(
      Uri.parse('$baseUrl/professeurs/$id'),
      headers: headers,
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to delete professeur: ${response.statusCode}');
    }
  }
  
  // ================= ÉTUDIANTS =================
  Future<List<dynamic>> getEtudiants() async {
    final headers = await _getHeaders();
    
    final response = await http.get(
      Uri.parse('$baseUrl/etudiants'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    } else {
      throw Exception('Failed to load etudiants: ${response.statusCode}');
    }
  }
  
  Future<Map<String, dynamic>> createEtudiant(Map<String, dynamic> etudiantData) async {
    final headers = await _getHeaders();
    
    final response = await http.post(
      Uri.parse('$baseUrl/etudiants'),
      headers: headers,
      body: jsonEncode(etudiantData),
    );
    
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create etudiant: ${response.statusCode}');
    }
  }
  
  Future<Map<String, dynamic>> getEtudiant(int id) async {
    final headers = await _getHeaders();
    
    final response = await http.get(
      Uri.parse('$baseUrl/etudiants/$id'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    } else {
      throw Exception('Failed to get etudiant: ${response.statusCode}');
    }
  }
  
  Future<Map<String, dynamic>> updateEtudiant(int id, Map<String, dynamic> etudiantData) async {
    final headers = await _getHeaders();
    
    final response = await http.put(
      Uri.parse('$baseUrl/etudiants/$id'),
      headers: headers,
      body: jsonEncode(etudiantData),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update etudiant: ${response.statusCode}');
    }
  }
  
  Future<void> deleteEtudiant(int id) async {
    final headers = await _getHeaders();
    
    final response = await http.delete(
      Uri.parse('$baseUrl/etudiants/$id'),
      headers: headers,
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to delete etudiant: ${response.statusCode}');
    }
  }
  
  // ================= NOTES =================
  Future<List<dynamic>> getNotes() async {
    final headers = await _getHeaders();
    
    final response = await http.get(
      Uri.parse('$baseUrl/notes'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    } else {
      throw Exception('Failed to load notes: ${response.statusCode}');
    }
  }
  
  Future<Map<String, dynamic>> createNote(Map<String, dynamic> noteData) async {
    final headers = await _getHeaders();
    
    final response = await http.post(
      Uri.parse('$baseUrl/notes'),
      headers: headers,
      body: jsonEncode(noteData),
    );
    
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create note: ${response.statusCode}');
    }
  }
  
  Future<Map<String, dynamic>> getNote(int id) async {
    final headers = await _getHeaders();
    
    final response = await http.get(
      Uri.parse('$baseUrl/notes/$id'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    } else {
      throw Exception('Failed to get note: ${response.statusCode}');
    }
  }
  
  Future<Map<String, dynamic>> updateNote(int id, Map<String, dynamic> noteData) async {
    final headers = await _getHeaders();
    
    final response = await http.put(
      Uri.parse('$baseUrl/notes/$id'),
      headers: headers,
      body: jsonEncode(noteData),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update note: ${response.statusCode}');
    }
  }
  
  Future<void> deleteNote(int id) async {
    final headers = await _getHeaders();
    
    final response = await http.delete(
      Uri.parse('$baseUrl/notes/$id'),
      headers: headers,
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to delete note: ${response.statusCode}');
    }
  }
  
  Future<List<dynamic>> getNotesByEtudiant(int etudiantId) async {
    final headers = await _getHeaders();
    
    final response = await http.get(
      Uri.parse('$baseUrl/etudiants/$etudiantId/notes'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    } else {
      throw Exception('Failed to load notes by etudiant: ${response.statusCode}');
    }
  }
  
  // ================= PRÉSENCES =================
  Future<List<dynamic>> getPresences() async {
    final headers = await _getHeaders();
    
    final response = await http.get(
      Uri.parse('$baseUrl/presences'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    } else {
      throw Exception('Failed to load presences: ${response.statusCode}');
    }
  }
  
  Future<Map<String, dynamic>> createPresence(Map<String, dynamic> presenceData) async {
    final headers = await _getHeaders();
    
    final response = await http.post(
      Uri.parse('$baseUrl/presences'),
      headers: headers,
      body: jsonEncode(presenceData),
    );
    
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create presence: ${response.statusCode}');
    }
  }
  
  Future<Map<String, dynamic>> getPresence(int id) async {
    final headers = await _getHeaders();
    
    final response = await http.get(
      Uri.parse('$baseUrl/presences/$id'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    } else {
      throw Exception('Failed to get presence: ${response.statusCode}');
    }
  }
  
  Future<Map<String, dynamic>> updatePresence(int id, Map<String, dynamic> presenceData) async {
    final headers = await _getHeaders();
    
    final response = await http.put(
      Uri.parse('$baseUrl/presences/$id'),
      headers: headers,
      body: jsonEncode(presenceData),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update presence: ${response.statusCode}');
    }
  }
  
  Future<void> deletePresence(int id) async {
    final headers = await _getHeaders();
    
    final response = await http.delete(
      Uri.parse('$baseUrl/presences/$id'),
      headers: headers,
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to delete presence: ${response.statusCode}');
    }
  }
  
  // ================= PAIEMENTS =================
  Future<List<dynamic>> getPaiements() async {
    final headers = await _getHeaders();
    
    final response = await http.get(
      Uri.parse('$baseUrl/paiements'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    } else {
      throw Exception('Failed to load paiements: ${response.statusCode}');
    }
  }
  
  Future<Map<String, dynamic>> createPaiement(Map<String, dynamic> paiementData) async {
    final headers = await _getHeaders();
    
    final response = await http.post(
      Uri.parse('$baseUrl/paiements'),
      headers: headers,
      body: jsonEncode(paiementData),
    );
    
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create paiement: ${response.statusCode}');
    }
  }
  
  // ================= MATIÈRES =================
  Future<List<dynamic>> getMatieres() async {
    final headers = await _getHeaders();
    
    final response = await http.get(
      Uri.parse('$baseUrl/matieres'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    } else {
      throw Exception('Failed to load matieres: ${response.statusCode}');
    }
  }
  
  Future<Map<String, dynamic>> createMatiere(Map<String, dynamic> matiereData) async {
    final headers = await _getHeaders();
    
    final response = await http.post(
      Uri.parse('$baseUrl/matieres'),
      headers: headers,
      body: jsonEncode(matiereData),
    );
    
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create matiere: ${response.statusCode}');
    }
  }
  
  // ================= ANNONCES =================
  Future<List<dynamic>> getAnnonces() async {
    final headers = await _getHeaders();
    
    final response = await http.get(
      Uri.parse('$baseUrl/annonces'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    } else {
      throw Exception('Failed to load annonces: ${response.statusCode}');
    }
  }
  
  Future<Map<String, dynamic>> createAnnonce(Map<String, dynamic> annonceData) async {
    final headers = await _getHeaders();
    
    final response = await http.post(
      Uri.parse('$baseUrl/annonces'),
      headers: headers,
      body: jsonEncode(annonceData),
    );
    
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create annonce: ${response.statusCode}');
    }
  }
  
  // ================= EMPLOIS DU TEMPS =================
  Future<List<dynamic>> getEmplois() async {
    final headers = await _getHeaders();
    
    final response = await http.get(
      Uri.parse('$baseUrl/emplois'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    } else {
      throw Exception('Failed to load emplois: ${response.statusCode}');
    }
  }
  
  Future<Map<String, dynamic>> createEmploi(Map<String, dynamic> emploiData) async {
    final headers = await _getHeaders();
    
    final response = await http.post(
      Uri.parse('$baseUrl/emplois'),
      headers: headers,
      body: jsonEncode(emploiData),
    );
    
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create emploi: ${response.statusCode}');
    }
  }
  
  // ================= STATISTIQUES =================
  Future<Map<String, dynamic>> getDashboardStats() async {
    final headers = await _getHeaders();
    
    final response = await http.get(
      Uri.parse('$baseUrl/dashboard/stats'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load dashboard stats: ${response.statusCode}');
    }
  }
  
  Future<Map<String, dynamic>> getStatistiques() async {
    final headers = await _getHeaders();
    
    final response = await http.get(
      Uri.parse('$baseUrl/statistiques'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load statistiques: ${response.statusCode}');
    }
  }
  
  // ================= SYNCHRONISATION COMPLÈTE =================
  Future<Map<String, dynamic>> pullAllData() async {
    final results = {
      'success': true,
      'classes': [],
      'etudiants': [],
      'professeurs': [],
      'notes': [],
      'presences': [],
      'paiements': [],
      'messages': []
    };
    
    try {
      // Récupérer les classes
      try {
        final classes = await getClasses();
        results['classes'] = classes;
        (results['messages']as List<String>).add('✅ Classes récupérées: ${classes.length}');
        print('✅ Classes récupérées: ${classes.length}');
      } catch (e) {
        (results['messages']as List<String>).add('❌ Erreur classes: $e');
        print('❌ Erreur classes: $e');
      }
      
      // Récupérer les étudiants
      try {
        final etudiants = await getEtudiants();
        results['etudiants'] = etudiants;
     (results['messages'] as List<String>).add('✅ Étudiants récupérés: ${etudiants.length}');
        print('✅ Étudiants récupérés: ${etudiants.length}');
      } catch (e) {
        (results['messages'] as List<String>).add('❌ Erreur étudiants: $e');
        print('❌ Erreur étudiants: $e');
      }
      
      // Récupérer les professeurs
      try {
        final professeurs = await getProfesseurs();
        results['professeurs'] = professeurs;
        (results['messages'] as List<String>).add('✅ Professeurs récupérés: ${professeurs.length}');
        print('✅ Professeurs récupérés: ${professeurs.length}');
      } catch (e) {
        (results['messages'] as List<String>).add('❌ Erreur professeurs: $e');
        print('❌ Erreur professeurs: $e');
      }
      
      // Récupérer les notes
      try {
        final notes = await getNotes();
        results['notes'] = notes;
        (results['messages'] as List<String>).add('✅ Notes récupérées: ${notes.length}');
        print('✅ Notes récupérées: ${notes.length}');
      } catch (e) {
        (results['messages'] as List<String>).add('❌ Erreur notes: $e');
        print('❌ Erreur notes: $e');
      }
      
      // Récupérer les présences
      try {
        final presences = await getPresences();
        results['presences'] = presences;
        (results['messages'] as List<String>).add('✅ Présences récupérées: ${presences.length}');
        print('✅ Présences récupérées: ${presences.length}');
      } catch (e) {
        (results['messages']as List<String>).add('❌ Erreur présences: $e');
        print('❌ Erreur présences: $e');
      }
      
      // Récupérer les paiements
      try {
        final paiements = await getPaiements();
        results['paiements'] = paiements;
        (results['messages']as List<String>).add('✅ Paiements récupérés: ${paiements.length}');
        print('✅ Paiements récupérés: ${paiements.length}');
      } catch (e) {
        (results['messages']as List<String>).add('❌ Erreur paiements: $e');
        print('❌ Erreur paiements: $e');
      }
      
      results['success'] = true;
      return results;
    } catch (e) {
      results['success'] = false;
      (results['messages']as List<String>).add('❌ Échec de la synchronisation: $e');
      return results;
    }
  }
  
  // Récupérer les données depuis une date spécifique
  Future<Map<String, dynamic>> pullDataSince(DateTime since) async {
    final headers = await _getHeaders();
    final sinceStr = since.toIso8601String();
    
    final response = await http.get(
      Uri.parse('$baseUrl/sync/pull?since=$sinceStr'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to pull data: ${response.statusCode}');
    }
  }
  
  // Envoyer les données modifiées localement
  Future<Map<String, dynamic>> pushLocalChanges(Map<String, dynamic> changes) async {
    final headers = await _getHeaders();
    
    final response = await http.post(
      Uri.parse('$baseUrl/sync/push'),
      headers: headers,
      body: jsonEncode(changes),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to push changes: ${response.statusCode}');
    }
  }
  
  // ================= UTILISATEUR COURANT =================
  Future<Map<String, dynamic>?> getCurrentUser() async {
    final headers = await _getHeaders();
    
    final response = await http.get(
      Uri.parse('$baseUrl/user'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['user'];
    } else {
      return null;
    }
  }
  
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> userData) async {
    final headers = await _getHeaders();
    
    final response = await http.put(
      Uri.parse('$baseUrl/user/profile'),
      headers: headers,
      body: jsonEncode(userData),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update profile: ${response.statusCode}');
    }
  }
  // ================= MESSAGES PROFESSEUR =================
Future<List<Map<String, dynamic>>> getMessagesForProfessor(int professorId) async {
  final headers = await _getHeaders();
  
  final response = await http.get(
    Uri.parse('$baseUrl/professors/$professorId/messages'),
    headers: headers,
  );
  
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return List<Map<String, dynamic>>.from(data['data']);
  } else {
    throw Exception('Failed to load messages: ${response.statusCode}');
  }
}

Future<Map<String, dynamic>> sendMessageToParent({
  required int parentId,
  required String subject,
  required String content,
}) async {
  final headers = await _getHeaders();
  
  final response = await http.post(
    Uri.parse('$baseUrl/messages'),
    headers: headers,
    body: jsonEncode({
      'receiver_id': parentId,
      'subject': subject,
      'content': content,
    }),
  );
  
  if (response.statusCode == 201) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to send message: ${response.statusCode}');
  }
}

Future<void> markMessageAsRead(int messageId) async {
  final headers = await _getHeaders();
  
  final response = await http.put(
    Uri.parse('$baseUrl/messages/$messageId/read'),
    headers: headers,
  );
  
  if (response.statusCode != 200) {
    throw Exception('Failed to mark message as read');
  }
}

Future<void> markMessageAsResponded(int messageId) async {
  final headers = await _getHeaders();
  
  final response = await http.put(
    Uri.parse('$baseUrl/messages/$messageId/responded'),
    headers: headers,
  );
  
  if (response.statusCode != 200) {
    throw Exception('Failed to mark message as responded');
  }
}
}