// lib/screens/student/student_attendance.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
// ✅ Supprimer l'import de date_utils.dart

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  _StudentAttendanceScreenState createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> attendances = [];
  Map<String, Map<String, int>> stats = {};
  bool _isLoading = true;
  late AnimationController _animationController;
  
  String selectedMonth = DateFormat('MMMM yyyy').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadDataFromFirestore();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// ✅ Fonction pour extraire la date de manière sécurisée
  DateTime _extractDate(dynamic dateField) {
    if (dateField == null) return DateTime.now();
    
    if (dateField is Timestamp) {
      return dateField.toDate();
    }
    
    if (dateField is String) {
      try {
        return DateTime.parse(dateField);
      } catch (e) {
        print('⚠️ Erreur parse date: $e');
        return DateTime.now();
      }
    }
    
    if (dateField is DateTime) {
      return dateField;
    }
    
    return DateTime.now();
  }

  /// ✅ Formater une date sans utiliser le locale 'fr_FR'
  String _formatDate(DateTime date, {String format = 'dd/MM/yyyy'}) {
    try {
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year;
      return '$day/$month/$year';
    } catch (e) {
      return 'Date inconnue';
    }
  }

  /// ✅ Formater le mois sans utiliser le locale 'fr_FR'
  String _formatMonth(DateTime date) {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  /// 🔥 Charger les présences depuis Firestore
  Future<void> _loadDataFromFirestore() async {
    setState(() => _isLoading = true);
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.id;
      final userEmail = authProvider.user?.email;
      
      if (userId != null || userEmail != null) {
        // Récupérer l'étudiant via son compte utilisateur
        Query studentQuery = FirebaseFirestore.instance.collection('students');
        
        if (userEmail != null) {
          studentQuery = studentQuery.where('userEmail', isEqualTo: userEmail);
        } else {
          studentQuery = studentQuery.where('userId', isEqualTo: userId);
        }
        
        final studentSnapshot = await studentQuery.limit(1).get();
        
        if (studentSnapshot.docs.isNotEmpty) {
          final studentData = studentSnapshot.docs.first.data() as Map<String, dynamic>;
          final studentName = studentData['fullName'] ?? '';
          
          print('✅ Étudiant trouvé: $studentName');
          
          // Charger les présences pour cet étudiant
          final attendancesSnapshot = await FirebaseFirestore.instance
              .collection('attendances')
              .where('studentName', isEqualTo: studentName)
              .get();
          
          attendances = [];
          for (var doc in attendancesSnapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            
            // ✅ Utiliser _extractDate pour gérer les deux types
            final date = _extractDate(data['date']);
            
            attendances.add({
              'id': doc.id,
              'studentName': data['studentName'] ?? '',
              'className': data['className'] ?? '',
              'subject': data['subject'] ?? '',
              'status': data['status'] ?? '',
              'date': date,
              'reason': data['reason'] ?? '',
            });
          }
          
          // Trier par date (plus récent en premier)
          attendances.sort((a, b) => b['date'].compareTo(a['date']));
          
          _calculateStats();
          print('✅ ${attendances.length} présences chargées');
        } else {
          print('⚠️ Aucun étudiant trouvé');
          attendances = [];
        }
      }
      
      _animationController.forward(from: 0);
    } catch (e) {
      print('❌ Erreur chargement présences: $e');
      _showSnackBar('Erreur de chargement: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _calculateStats() {
    stats.clear();
    
    for (var attendance in attendances) {
      final date = attendance['date'] as DateTime;
      // ✅ Utiliser _formatMonth au lieu de DateFormat avec locale
      final monthKey = _formatMonth(date);
      final status = attendance['status'] as String;
      
      if (!stats.containsKey(monthKey)) {
        stats[monthKey] = {
          'present': 0,
          'absent': 0,
          'late': 0,
          'excused': 0,
          'total': 0,
        };
      }
      
      stats[monthKey]![status] = (stats[monthKey]![status] ?? 0) + 1;
      stats[monthKey]!['total'] = (stats[monthKey]!['total'] ?? 0) + 1;
    }
  }

  double _getAttendanceRate(Map<String, int> monthStats) {
    final total = monthStats['total'] ?? 0;
    if (total == 0) return 0;
    
    final present = monthStats['present'] ?? 0;
    return (present / total) * 100;
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'present': return 'Présent';
      case 'absent': return 'Absent';
      case 'late': return 'En retard';
      case 'excused': return 'Excusé';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'present': return Colors.green;
      case 'absent': return Colors.red;
      case 'late': return Colors.orange;
      case 'excused': return Colors.blue;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))),
            SizedBox(height: 16),
            Text('Chargement des présences...'),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Mes présences',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDataFromFirestore,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (auth.currentSchoolId != null && !auth.isSuperAdmin)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.business, size: 18, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 8),
                    Text(
                      'École : ${auth.schoolName ?? auth.currentSchoolId}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),
              ),

            // Statistiques globales
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Statistiques de présence',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatCircle(
                          'Présent',
                          attendances.where((a) => a['status'] == 'present').length,
                          Colors.green,
                        ),
                        _buildStatCircle(
                          'Absent',
                          attendances.where((a) => a['status'] == 'absent').length,
                          Colors.red,
                        ),
                        _buildStatCircle(
                          'Retard',
                          attendances.where((a) => a['status'] == 'late').length,
                          Colors.orange,
                        ),
                        _buildStatCircle(
                          'Excusé',
                          attendances.where((a) => a['status'] == 'excused').length,
                          Colors.blue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Liste des présences par mois
            if (attendances.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.calendar_today, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Aucune présence enregistrée',
                      style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Les présences seront affichées ici',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                  ],
                ),
              )
            else
              ...stats.keys.map((month) {
                final monthStats = stats[month]!;
                final rate = _getAttendanceRate(monthStats);
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: rate >= 80 ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        rate >= 80 ? Icons.thumb_up : Icons.warning,
                        color: rate >= 80 ? Colors.green : Colors.orange,
                      ),
                    ),
                    title: Text(
                      month,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Taux de présence: ${rate.toStringAsFixed(1)}%'),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: rate / 100,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            rate >= 80 ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatChip('P', monthStats['present'] ?? 0, Colors.green),
                            _buildStatChip('A', monthStats['absent'] ?? 0, Colors.red),
                            _buildStatChip('R', monthStats['late'] ?? 0, Colors.orange),
                            _buildStatChip('E', monthStats['excused'] ?? 0, Colors.blue),
                          ],
                        ),
                      ),
                      ...attendances
                          .where((a) => _formatMonth(a['date'] as DateTime) == month)
                          .map((a) {
                            final date = a['date'] as DateTime;
                            return FadeTransition(
                              opacity: _animationController,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getStatusColor(a['status']),
                                  radius: 6,
                                ),
                                title: Text(
                                  _formatDate(date),
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                subtitle: Text(
                                  a['subject'] ?? '',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(a['status']).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _getStatusText(a['status']),
                                    style: TextStyle(
                                      color: _getStatusColor(a['status']),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCircle(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.1),
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 4),
          Text(
            '$label: $count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}