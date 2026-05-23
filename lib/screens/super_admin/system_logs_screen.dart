// lib/screens/super_admin/system_logs_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SystemLogsScreen extends StatefulWidget {
  const SystemLogsScreen({super.key});

  @override
  _SystemLogsScreenState createState() => _SystemLogsScreenState();
}

class _SystemLogsScreenState extends State<SystemLogsScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  String _filterLevel = 'all';
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadLogsFromFirestore();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 🔥 Charger les logs depuis Firestore
  Future<void> _loadLogsFromFirestore() async {
    setState(() => _isLoading = true);
    
    try {
      Query query = FirebaseFirestore.instance
          .collection('system_logs')
          .orderBy('timestamp', descending: true)
          .limit(200);
      
      if (_filterLevel != 'all') {
        query = query.where('level', isEqualTo: _filterLevel);
      }
      
      final snapshot = await query.get();
      
_logs = snapshot.docs.map((doc) {
  final data = doc.data() as Map<String, dynamic>;
  return {
    'id': doc.id,
    'action': data['action'] ?? '',
    'description': data['description'] ?? '',
    'level': data['level'] ?? 'info',
    'timestamp': data['timestamp'] != null 
        ? (data['timestamp'] as Timestamp).toDate().toIso8601String() 
        : DateTime.now().toIso8601String(),
    'schoolId': data['schoolId'],
    'userId': data['userId'],
  };
}).toList();
      
      print('✅ ${_logs.length} logs chargés depuis Firestore');
    } catch (e) {
      print('❌ Erreur chargement logs: $e');
      // Logs mockés si Firestore n'a pas la collection
      _logs = [
        {'action': 'Connexion', 'description': 'Super Admin connecté', 'level': 'info', 'timestamp': DateTime.now().toIso8601String()},
        {'action': 'Ajout école', 'description': 'Nouvelle école ajoutée', 'level': 'info', 'timestamp': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String()},
      ];
    } finally {
      setState(() => _isLoading = false);
      _animationController.forward(from: 0);
    }
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'info': return const Color(0xFF3B82F6);
      case 'warning': return const Color(0xFFF59E0B);
      case 'error': return const Color(0xFFEF4444);
      default: return Colors.grey;
    }
  }

  IconData _getLevelIcon(String level) {
    switch (level) {
      case 'info': return Icons.info_outline;
      case 'warning': return Icons.warning_amber;
      case 'error': return Icons.error_outline;
      default: return Icons.info_outline;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy HH:mm:ss').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
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
            onPressed: _loadLogsFromFirestore,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                _buildFilterChip('Tous', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Info', 'info'),
                const SizedBox(width: 8),
                _buildFilterChip('Warning', 'warning'),
                const SizedBox(width: 8),
                _buildFilterChip('Error', 'error'),
              ],
            ),
          ),
          
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
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? Center(
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
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          final levelColor = _getLevelColor(log['level']);
                          
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
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: levelColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(_getLevelIcon(log['level']), color: levelColor, size: 20),
                                ),
                                title: Text(
                                  log['action'],
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      log['description'],
                                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatDate(log['timestamp']),
                                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                        ),
                                        if (log['schoolId'] != null) ...[
                                          const SizedBox(width: 12),
                                          Icon(Icons.business, size: 12, color: Colors.grey[500]),
                                          const SizedBox(width: 4),
                                          Text(
                                            'École ID: ${log['schoolId']}',
                                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
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
}