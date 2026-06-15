// lib/screens/super_admin/system_logs_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SystemLogsScreen extends StatefulWidget {
  const SystemLogsScreen({super.key});

  @override
  _SystemLogsScreenState createState() => _SystemLogsScreenState();
}

class _SystemLogsScreenState extends State<SystemLogsScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _filteredLogs = [];
  List<Map<String, dynamic>> _connectedUsers = [];
  bool _isLoading = true;
  String _filterLevel = 'all';
  String _filterType = 'all';
  String _selectedSchoolFilter = 'all';
  late AnimationController _animationController;
  
  final List<String> _logTypes = ['all', 'connexion', 'deconnexion', 'ajout_eleve', 'modification', 'suppression'];
  
  // Liste des écoles pour le filtre
  List<Map<String, dynamic>> _schools = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadSchools();
    _loadLogsFromFirestore();
    _loadConnectedUsers();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 🔥 Charger les écoles pour le filtre
  Future<void> _loadSchools() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('schools')
          .where('isActive', isEqualTo: true)
          .get();
      
      _schools = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'École sans nom',
          'code': data['schoolCode'] ?? '',
        };
      }).toList();
      
      setState(() {});
    } catch (e) {
      print('❌ Erreur chargement écoles: $e');
    }
  }

  /// 🔥 Récupérer les utilisateurs connectés en temps réel
  Future<void> _loadConnectedUsers() async {
    // Écouter les sessions actives
    FirebaseFirestore.instance
        .collection('active_sessions')
        .snapshots()
        .listen((snapshot) {
      final users = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'userId': doc.id,
          'userName': data['userName'] ?? '',
          'userEmail': data['userEmail'] ?? '',
          'role': data['role'] ?? '',
          'schoolId': data['schoolId'],
          'schoolName': data['schoolName'] ?? '',
          'loginTime': data['loginTime'] != null 
              ? (data['loginTime'] as Timestamp).toDate() 
              : DateTime.now(),
          'lastActivity': data['lastActivity'] != null 
              ? (data['lastActivity'] as Timestamp).toDate() 
              : DateTime.now(),
        };
      }).toList();
      
      setState(() {
        _connectedUsers = users;
      });
    });
  }

  /// 🔥 Charger les logs depuis Firestore avec tous les types d'actions
  Future<void> _loadLogsFromFirestore() async {
    setState(() => _isLoading = true);
    
    try {
      Query query = FirebaseFirestore.instance
          .collection('system_logs')
          .orderBy('timestamp', descending: true)
          .limit(500);
      
      if (_filterLevel != 'all') {
        query = query.where('level', isEqualTo: _filterLevel);
      }
      
      if (_filterType != 'all') {
        query = query.where('actionType', isEqualTo: _filterType);
      }
      
      if (_selectedSchoolFilter != 'all') {
        query = query.where('schoolId', isEqualTo: _selectedSchoolFilter);
      }
      
      final snapshot = await query.get();
      
     _logs = snapshot.docs.map((doc) {
  final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
  return {
    'id': doc.id,
    'action': data['action']?.toString() ?? '',
    'actionType': data['actionType']?.toString() ?? 'autre',
    'description': data['description']?.toString() ?? '',
    'level': data['level']?.toString() ?? 'info',
    'timestamp': (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    'schoolId': data['schoolId'],
    'schoolName': data['schoolName'],
    'userId': data['userId'],
    'userName': data['userName'],
    'userRole': data['userRole'],
    'ipAddress': data['ipAddress'],
    'details': data['details'],
  };
}).toList();
      _filteredLogs = _logs;
      print('✅ ${_logs.length} logs chargés depuis Firestore');
      
      // Ajouter un log pour la consultation
      await _addLog(
        action: 'Consultation logs',
        actionType: 'consultation',
        description: 'Le Super Admin a consulté les logs système',
        level: 'info',
      );
      
    } catch (e) {
      print('❌ Erreur chargement logs: $e');
      _logs = [];
      _filteredLogs = [];
    } finally {
      setState(() => _isLoading = false);
      _animationController.forward(from: 0);
    }
  }

  /// 🔥 Ajouter un log (appelé par les autres services)
  Future<void> _addLog({
    required String action,
    required String actionType,
    required String description,
    required String level,
    String? schoolId,
    String? schoolName,
    String? userId,
    String? userName,
    String? userRole,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('system_logs').add({
        'action': action,
        'actionType': actionType,
        'description': description,
        'level': level,
        'timestamp': FieldValue.serverTimestamp(),
        'schoolId': schoolId,
        'schoolName': schoolName,
        'userId': userId,
        'userName': userName,
        'userRole': userRole,
      });
    } catch (e) {
      print('❌ Erreur ajout log: $e');
    }
  }

  /// 🔥 Compter les utilisateurs connectés par école
  Map<String, int> _getConnectedUsersBySchool() {
    final Map<String, int> countBySchool = {};
    
    for (var user in _connectedUsers) {
      final schoolName = user['schoolName'] ?? 'Sans école';
      countBySchool[schoolName] = (countBySchool[schoolName] ?? 0) + 1;
    }
    
    return countBySchool;
  }

  /// 🔥 Compter les connexions par heure
  Map<String, int> _getConnectionsByHour() {
    final Map<String, int> countByHour = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    for (var log in _logs) {
      if (log['actionType'] == 'connexion' && log['timestamp'] is DateTime) {
        final timestamp = log['timestamp'] as DateTime;
        if (timestamp.isAfter(today)) {
          final hour = '${timestamp.hour.toString().padLeft(2, '0')}:00';
          countByHour[hour] = (countByHour[hour] ?? 0) + 1;
        }
      }
    }
    
    return countByHour;
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'info': return const Color(0xFF3B82F6);
      case 'warning': return const Color(0xFFF59E0B);
      case 'error': return const Color(0xFFEF4444);
      case 'success': return const Color(0xFF10B981);
      default: return Colors.grey;
    }
  }

  IconData _getLevelIcon(String level) {
    switch (level) {
      case 'info': return Icons.info_outline;
      case 'warning': return Icons.warning_amber;
      case 'error': return Icons.error_outline;
      case 'success': return Icons.check_circle_outline;
      default: return Icons.info_outline;
    }
  }

  IconData _getActionIcon(String actionType) {
    switch (actionType) {
      case 'connexion': return Icons.login;
      case 'deconnexion': return Icons.logout;
      case 'ajout_eleve': return Icons.person_add;
      case 'modification': return Icons.edit;
      case 'suppression': return Icons.delete;
      case 'ajout_ecole': return Icons.business;
      default: return Icons.notifications;
    }
  }

  Color _getActionColor(String actionType) {
    switch (actionType) {
      case 'connexion': return const Color(0xFF3B82F6);
      case 'deconnexion': return const Color(0xFF6B7280);
      case 'ajout_eleve': return const Color(0xFF10B981);
      case 'modification': return const Color(0xFFF59E0B);
      case 'suppression': return const Color(0xFFEF4444);
      case 'ajout_ecole': return const Color(0xFF8B5CF6);
      default: return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm:ss').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final connectedBySchool = _getConnectedUsersBySchool();
    final connectionsByHour = _getConnectionsByHour();
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Logs système',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadLogsFromFirestore();
              _loadConnectedUsers();
            },
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // SECTION 1: STATISTIQUES DES CONNEXIONS
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.people, color: Colors.blue, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Utilisateurs connectés',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_connectedUsers.length} actif(s)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Liste des utilisateurs connectés par école
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: connectedBySchool.entries.map((entry) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${entry.key}: ${entry.value}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue[800],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (connectedBySchool.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'Aucun utilisateur connecté',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ),
                    ),
                  
                  const Divider(height: 24),
                  
                  // Graphique des connexions par heure
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.schedule, color: Colors.orange, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Connexions aujourd\'hui par heure',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 24,
                      itemBuilder: (context, hour) {
                        final hourStr = '${hour.toString().padLeft(2, '0')}:00';
                        final count = connectionsByHour[hourStr] ?? 0;
                        final height = count > 0 ? (count / 10) * 80 : 4;
                        return Container(
                          width: 40,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (count > 0)
                                Text(
                                  count.toString(),
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              const SizedBox(height: 4),
                              Container(
                                height: height.clamp(4.0, 80.0).toDouble(),                                
                                width: 30,
                                decoration: BoxDecoration(
                                  color: count > 0 ? Colors.orange : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                hourStr,
                                style: const TextStyle(fontSize: 9),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            // SECTION 2: FILTRES
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filtres par niveau
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildFilterChip('Tous', 'all'),
                      _buildFilterChip('Info', 'info'),
                      _buildFilterChip('Succès', 'success'),
                      _buildFilterChip('Warning', 'warning'),
                      _buildFilterChip('Error', 'error'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Filtres par type d'action
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildActionFilterChip('Tous', 'all'),
                      _buildActionFilterChip('Connexion', 'connexion'),
                      _buildActionFilterChip('Ajout élève', 'ajout_eleve'),
                      _buildActionFilterChip('Modification', 'modification'),
                      _buildActionFilterChip('Suppression', 'suppression'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Filtre par école
                  DropdownButtonFormField<String>(
                    value: _selectedSchoolFilter,
                    decoration: InputDecoration(
                      labelText: 'Filtrer par école',
                      prefixIcon: const Icon(Icons.business),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('Toutes les écoles')),
                      ..._schools.map((school) => DropdownMenuItem(
                        value: school['id'],
                        child: Text(school['name']),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedSchoolFilter = value ?? 'all';
                        _loadLogsFromFirestore();
                      });
                    },
                  ),
                ],
              ),
            ),
            
            // SECTION 3: LISTE DES LOGS
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.list, size: 16, color: Color(0xFF3B82F6)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_logs.length} log(s)',
                    style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            
            // Liste des logs
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'Aucun log disponible',
                                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          final levelColor = _getLevelColor(log['level']);
                          final actionColor = _getActionColor(log['actionType']);
                          
                          return FadeTransition(
                            opacity: _animationController,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: levelColor.withOpacity(0.2)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: actionColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _getActionIcon(log['actionType']),
                                    color: actionColor,
                                    size: 22,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        log['action'],
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: levelColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        log['level'].toUpperCase(),
                                        style: TextStyle(fontSize: 10, color: levelColor, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 6),
                                    Text(
                                      log['description'],
                                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 4,
                                      children: [
                                        _buildInfoChip(Icons.access_time, _formatDate(log['timestamp']), Colors.grey),
                                        if (log['userName'] != null && log['userName'].isNotEmpty)
                                          _buildInfoChip(Icons.person, log['userName'], Colors.blue),
                                        if (log['userRole'] != null && log['userRole'].isNotEmpty)
                                          _buildInfoChip(Icons.work, log['userRole'], Colors.purple),
                                        if (log['schoolName'] != null && log['schoolName'].isNotEmpty)
                                          _buildInfoChip(Icons.business, log['schoolName'], Colors.green),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterLevel == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterLevel = value;
          _loadLogsFromFirestore();
        });
      },
      backgroundColor: Colors.grey[100],
      selectedColor: const Color(0xFF10B981).withOpacity(0.1),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF10B981) : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: isSelected
            ? BorderSide.none
            : BorderSide(color: Colors.grey[300]!),
      ),
    );
  }

  Widget _buildActionFilterChip(String label, String value) {
    final isSelected = _filterType == value;
    final color = _getActionColor(value);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterType = value;
          _loadLogsFromFirestore();
        });
      },
      backgroundColor: Colors.grey[100],
      selectedColor: color.withOpacity(0.15),
      labelStyle: TextStyle(
        color: isSelected ? color : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: isSelected
            ? BorderSide.none
            : BorderSide(color: Colors.grey[300]!),
      ),
    );
  }
}