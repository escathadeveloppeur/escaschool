// lib/screens/parent/parent_attendance.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/student_model.dart';
import '../../providers/auth_provider.dart';

class ParentAttendanceScreen extends StatefulWidget {
  const ParentAttendanceScreen({super.key});

  @override
  _ParentAttendanceScreenState createState() => _ParentAttendanceScreenState();
}

class _ParentAttendanceScreenState extends State<ParentAttendanceScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> children = [];
  Map<String, dynamic>? selectedChild;
  List<Map<String, dynamic>> attendances = [];
  Map<String, Map<String, int>> stats = {};
  bool _isLoading = true;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadChildrenAndAttendances();
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
  String _formatDate(DateTime date) {
    try {
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year;
      return '$day/$month/$year';
    } catch (e) {
      return 'Date inconnue';
    }
  }

  /// ✅ Formater la date avec le jour de la semaine en français
  String _formatDateLong(DateTime date) {
    const weekdays = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    
    try {
      final weekday = weekdays[date.weekday - 1];
      final day = date.day.toString().padLeft(2, '0');
      final month = months[date.month - 1];
      final year = date.year;
      return '$weekday $day $month $year';
    } catch (e) {
      return _formatDate(date);
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

  /// 🔥 Charger les enfants et leurs présences depuis Firestore
  Future<void> _loadChildrenAndAttendances() async {
    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id;
    final userEmail = authProvider.user?.email;
    final schoolId = authProvider.currentSchoolId;

    if (userId != null || userEmail != null) {
      try {
        // Charger les liens parent-enfant depuis Firestore
        Query parentLinksQuery = FirebaseFirestore.instance
            .collection('parent_student_links');
        
        if (userEmail != null) {
          parentLinksQuery = parentLinksQuery.where('parentEmail', isEqualTo: userEmail);
        } else {
          parentLinksQuery = parentLinksQuery.where('parentUserId', isEqualTo: userId);
        }
        
        final linksSnapshot = await parentLinksQuery.get();
        
        final List<String> childNames = [];
        for (var linkDoc in linksSnapshot.docs) {
          final data = linkDoc.data() as Map<String, dynamic>;
          final childName = data['studentName'];
          if (childName != null) {
            childNames.add(childName);
          }
        }
        
        // Charger les étudiants depuis Firestore
        if (childNames.isNotEmpty) {
          final studentsSnapshot = await FirebaseFirestore.instance
              .collection('students')
              .where('fullName', whereIn: childNames)
              .get();
          
          children = studentsSnapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'firestoreId': doc.id,
              'fullName': data['fullName'] ?? '',
              'className': data['className'] ?? '',
              'schoolId': data['schoolId'],
            };
          }).toList();
          
          if (schoolId != null) {
            children = children.where((s) => s['schoolId'] == schoolId).toList();
          }
        }

        if (children.isNotEmpty) {
          selectedChild = children.first;
          await _loadAttendancesFromFirestore(selectedChild!);
        }
      } catch (e) {
        print('❌ Erreur chargement: $e');
      }
    }

    setState(() => _isLoading = false);
    _animationController.forward(from: 0);
  }

  /// 🔥 Charger présences depuis Firestore
  Future<void> _loadAttendancesFromFirestore(Map<String, dynamic> child) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('attendances')
        .where('studentName', isEqualTo: child['fullName'])
        .orderBy('date', descending: true)
        .get();
    
    attendances = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'studentName': data['studentName'] ?? '',
        'status': data['status'] ?? 'absent',
        'date': _extractDate(data['date']),
        'subject': data['subject'] ?? '',
        'reason': data['reason'] ?? '',
      };
    }).toList();
    
    _calculateStats();
  }

  void _calculateStats() {
    stats.clear();

    for (var attendance in attendances) {
      final date = attendance['date'] as DateTime;
      // ✅ Utiliser _formatMonth au lieu de DateFormat avec locale
      final monthKey = _formatMonth(date);
      final status = attendance['status'] as String;

      stats.putIfAbsent(monthKey, () => {
            'present': 0,
            'absent': 0,
            'late': 0,
            'excused': 0,
            'total': 0,
          });

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
      case 'late': return 'Retard';
      case 'excused': return 'Excusé';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'present': return const Color(0xFF10B981);
      case 'absent': return const Color(0xFFEF4444);
      case 'late': return const Color(0xFFF59E0B);
      case 'excused': return const Color(0xFF3B82F6);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Assiduité de mes enfants', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadChildrenAndAttendances),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))))
          : Column(
              children: [
                if (auth.currentSchoolId != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [const Icon(Icons.business, size: 18, color: Color(0xFF3B82F6)), const SizedBox(width: 8), Text('Établissement : ${auth.schoolName ?? 'Votre école'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF3B82F6)))]),
                  ),

                if (children.length > 1)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
                    child: DropdownButtonFormField<Map<String, dynamic>>(
                      value: selectedChild,
                      decoration: const InputDecoration(border: InputBorder.none, prefixIcon: Icon(Icons.child_care, color: Color(0xFF10B981)), labelText: 'Choisir un enfant'),
                      items: children.map((child) {
                        return DropdownMenuItem(
                          value: child,
                          child: Text(child['fullName']),
                        );
                      }).toList(),
                      onChanged: (value) async {
                        setState(() => _isLoading = true);
                        selectedChild = value;
                        await _loadAttendancesFromFirestore(value!);
                        setState(() => _isLoading = false);
                      },
                    ),
                  ),

                Expanded(
                  child: selectedChild == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.child_care, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(children.isEmpty ? 'Aucun enfant enregistré' : 'Sélectionnez un enfant', style: TextStyle(color: Colors.grey[500])),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              FadeTransition(
                                opacity: _animationController,
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF14B8A6)]), borderRadius: BorderRadius.circular(20)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [const Icon(Icons.person, color: Colors.white, size: 28), const SizedBox(width: 12), Expanded(child: Text(selectedChild!['fullName'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)))]),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                                          children: [
                                            _buildStatCircle('Présent', attendances.where((a) => a['status'] == 'present').length, const Color(0xFF10B981)),
                                            _buildStatCircle('Absent', attendances.where((a) => a['status'] == 'absent').length, const Color(0xFFEF4444)),
                                            _buildStatCircle('Retard', attendances.where((a) => a['status'] == 'late').length, const Color(0xFFF59E0B)),
                                            _buildStatCircle('Excusé', attendances.where((a) => a['status'] == 'excused').length, const Color(0xFF3B82F6)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              if (attendances.isEmpty)
                                Center(
                                  child: Column(
                                    children: [
                                      const SizedBox(height: 60),
                                      Icon(Icons.calendar_today, size: 64, color: Colors.grey[300]),
                                      const SizedBox(height: 16),
                                      Text('Aucune présence enregistrée', style: TextStyle(color: Colors.grey[500])),
                                    ],
                                  ),
                                )
                              else
                                ...stats.keys.map((month) {
                                  final monthStats = stats[month]!;
                                  final rate = _getAttendanceRate(monthStats);
                                  return FadeTransition(
                                    opacity: _animationController,
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
                                      child: ExpansionTile(
                                        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.calendar_month, color: Color(0xFF3B82F6))),
                                        title: Text(month, style: const TextStyle(fontWeight: FontWeight.w600)),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 4),
                                            LinearProgressIndicator(value: rate / 100, backgroundColor: Colors.grey[200], valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981))),
                                            const SizedBox(height: 4),
                                            Text('Taux de présence : ${rate.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                          ],
                                        ),
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                              children: [
                                                _buildStatChip('Présent', monthStats['present'] ?? 0, const Color(0xFF10B981)),
                                                _buildStatChip('Absent', monthStats['absent'] ?? 0, const Color(0xFFEF4444)),
                                                _buildStatChip('Retard', monthStats['late'] ?? 0, const Color(0xFFF59E0B)),
                                                _buildStatChip('Excusé', monthStats['excused'] ?? 0, const Color(0xFF3B82F6)),
                                              ],
                                            ),
                                          ),
                                          ...attendances
                                              .where((a) => _formatMonth(a['date'] as DateTime) == month)
                                              .map((a) {
                                                final date = a['date'] as DateTime;
                                                return Container(
                                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                                  decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
                                                  child: ListTile(
                                                    leading: Container(
                                                      width: 40, height: 40,
                                                      decoration: BoxDecoration(color: _getStatusColor(a['status']).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                                      child: Center(child: Icon(a['status'] == 'present' ? Icons.check_circle : a['status'] == 'absent' ? Icons.cancel : a['status'] == 'late' ? Icons.access_time : Icons.assignment_turned_in, color: _getStatusColor(a['status']), size: 20)),
                                                    ),
                                                    title: Text(_formatDateLong(date), style: const TextStyle(fontWeight: FontWeight.w500)),
                                                    subtitle: Text(a['subject']),
                                                    trailing: Chip(label: Text(_getStatusText(a['status'])), backgroundColor: _getStatusColor(a['status']).withOpacity(0.1), labelStyle: TextStyle(color: _getStatusColor(a['status']))),
                                                  ),
                                                );
                                              }),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCircle(String label, int count, Color color) {
    return Column(
      children: [
        Container(width: 50, height: 50, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.2), border: Border.all(color: color, width: 2)), child: Center(child: Text(count.toString(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)))),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 6),
          Text('$label : $count', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color)),
        ],
      ),
    );
  }
}