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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLogsFromFirestore();
  }

  /// 🔥 Charger les logs depuis Firestore (uniquement ceux de l'école)
  Future<void> _loadLogsFromFirestore() async {
    setState(() => _loading = true);
    
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final schoolId = auth.currentSchoolId;
    
    try {
      Query query = FirebaseFirestore.instance
          .collection('system_logs')
          .orderBy('timestamp', descending: true);
      
      // 🔥 Filtrer par schoolId si ce n'est pas un Super Admin
      if (!auth.isSuperAdmin && schoolId != null && schoolId.isNotEmpty) {
        query = query.where('schoolId', isEqualTo: schoolId);
        print('🔍 Filtrage des logs pour l\'école: $schoolId');
      } else if (!auth.isSuperAdmin) {
        // L'utilisateur n'est pas Super Admin et n'a pas de schoolId
        setState(() {
          logs = [];
          _loading = false;
        });
        print('⚠️ Aucun schoolId disponible pour filtrer les logs');
        return;
      } else {
        print('👑 Super Admin: affichage de tous les logs');
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
          'schoolId': data['schoolId']?.toString() ?? '',
          'userId': data['userId'],
        });
      }
      
      setState(() {
        logs = loadedLogs;
        _loading = false;
      });
      
      print('✅ ${loadedLogs.length} logs chargés depuis Firestore');
      
    } catch (e) {
      print('❌ Erreur chargement logs: $e');
      // Fallback vers Hive
      try {
        final allLogs = await db.getAllLogs();
        final filteredLogs = allLogs.where((log) {
          if (auth.isSuperAdmin) return true;
          return log['schoolId'] == schoolId;
        }).toList();
        setState(() {
          logs = filteredLogs.reversed.toList().cast<Map<String, dynamic>>();
          _loading = false;
        });
      } catch (e2) {
        print('❌ Erreur fallback Hive: $e2');
        setState(() => _loading = false);
      }
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

  String _getLevelLabel(String level) {
    switch (level) {
      case 'error': return '❌ Erreur';
      case 'warning': return '⚠️ Avertissement';
      case 'success': return '✅ Succès';
      default: return 'ℹ️ Info';
    }
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'error': return Colors.red;
      case 'warning': return Colors.orange;
      case 'success': return Colors.green;
      default: return Colors.blue;
    }
  }

  IconData _getLevelIcon(String level) {
    switch (level) {
      case 'error': return Icons.error_outline;
      case 'warning': return Icons.warning_amber_outlined;
      case 'success': return Icons.check_circle_outline;
      default: return Icons.info_outline;
    }
  }

  String _getEmptyMessage(AuthProvider auth) {
    if (auth.isSuperAdmin) {
      return "Aucune action enregistrée dans le système";
    } else if (auth.hasSchool) {
      return "Aucune action enregistrée pour votre école";
    } else {
      return "Aucune action disponible";
    }
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
                    "📍 ${auth.schoolName ?? auth.currentSchoolId}",
                    style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                  ),
                ),
              if (auth.isSuperAdmin)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "👑 Super Admin",
                    style: TextStyle(fontSize: 12, color: Colors.purple),
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
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    ),
                  )
                : logs.isEmpty
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
                            const SizedBox(height: 8),
                            if (!auth.isSuperAdmin && auth.hasSchool)
                              Text(
                                "Aucune action enregistrée pour ${auth.schoolName ?? 'votre école'}",
                                style: TextStyle(color: Colors.grey[500], fontSize: 14),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: logs.length,
                        itemBuilder: (_, i) {
                          final log = logs[i];
                          final color = _getLogColor(log['action'] ?? '');
                          final levelColor = _getLevelColor(log['level'] ?? 'info');
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: levelColor.withOpacity(0.1),
                                child: Icon(
                                  _getLevelIcon(log['level'] ?? 'info'),
                                  color: levelColor,
                                  size: 20,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      log['action'] ?? '',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: levelColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _getLevelLabel(log['level'] ?? 'info'),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w500,
                                        color: levelColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    log['description'] ?? '',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 12,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatDate(log['timestamp']),
                                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                      ),
                                      if (log['schoolId'] != null && log['schoolId']!.isNotEmpty && auth.isSuperAdmin) ...[
                                        const SizedBox(width: 12),
                                        Icon(
                                          Icons.business,
                                          size: 12,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          log['schoolId']!,
                                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                        ),
                                      ],
                                    ],
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
}