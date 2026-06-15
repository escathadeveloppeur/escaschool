// lib/screens/admin/admin_logs.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/db_helper.dart';
import '../../providers/auth_provider.dart';

class AdminLogs extends StatefulWidget {
  const AdminLogs({super.key});

  @override
  _AdminLogsState createState() => _AdminLogsState();
}

class _AdminLogsState extends State<AdminLogs> {
  final DBHelper db = DBHelper();
  List<Map<String, dynamic>> logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogsFromFirestore();
  }

  /// 🔥 Charger les logs depuis Firestore
  Future<void> _loadLogsFromFirestore() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final schoolId = auth.currentSchoolId;
    
    try {
      Query query = FirebaseFirestore.instance
          .collection('system_logs')
          .orderBy('timestamp', descending: true);
      
      if (!auth.isSuperAdmin && schoolId != null) {
        query = query.where('schoolId', isEqualTo: schoolId);
      }
      
      final snapshot = await query.limit(500).get();
      
      final List<Map<String, dynamic>> loadedLogs = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        loadedLogs.add({
          'id': doc.id,
          'action': data['action'] ?? '',
          'description': data['description'] ?? '',
          'level': data['level'] ?? 'info',
          'timestamp': data['timestamp'] != null
              ? (data['timestamp'] as Timestamp).toDate().toIso8601String()
              : DateTime.now().toIso8601String(),
          'schoolId': data['schoolId']?.toString(),
          'userId': data['userId'],
        });
      }
      
      setState(() {
        logs = loadedLogs;
      });
      
      print('✅ ${loadedLogs.length} logs chargés depuis Firestore');
    } catch (e) {
      print('❌ Erreur chargement logs: $e');
      // Fallback vers Hive
      final allLogs = await db.getAllLogs();
      setState(() {
      logs = allLogs.reversed.toList().cast<Map<String, dynamic>>();
      });
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  Color _getLogColor(String log) {
    final l = log.toLowerCase();
    if (l.contains('ajout') || l.contains('cré')) return Colors.green;
    if (l.contains('supprim') || l.contains('effac')) return Colors.red;
    if (l.contains('modif') || l.contains('mis à jour')) return Colors.orange;
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Historique des actions",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (!auth.isSuperAdmin && auth.hasSchool)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "École ID: ${auth.currentSchoolId}",
                    style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadLogsFromFirestore,
                tooltip: "Actualiser",
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: logs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _getEmptyMessage(auth),
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (_, i) {
                      final log = logs[i];
                      final color = _getLogColor(log['action'] ?? '');
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withOpacity(0.1),
                            child: Icon(Icons.history, color: color, size: 20),
                          ),
                          title: Text(
                            log['action'] ?? '',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log['description'] ?? '',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(log['timestamp']),
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
                            ],
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

  String _getEmptyMessage(AuthProvider auth) {
    if (auth.isSuperAdmin) {
      return "Aucune action enregistrée pour le moment";
    } else if (auth.hasSchool ) {
      return "Aucune action enregistrée pour votre école";
    } else {
      return "Aucune action disponible";
    }
  }
}