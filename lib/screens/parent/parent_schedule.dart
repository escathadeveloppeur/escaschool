// lib/screens/parent/parent_schedule.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';

class ParentScheduleScreen extends StatefulWidget {
  const ParentScheduleScreen({super.key});

  @override
  _ParentScheduleScreenState createState() => _ParentScheduleScreenState();
}

class _ParentScheduleScreenState extends State<ParentScheduleScreen> {
  List<Map<String, dynamic>> children = [];
  Map<String, dynamic>? selectedChild;
  List<Map<String, dynamic>> schedules = [];
  bool _isLoading = true;
  
  final List<String> days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
  int selectedDay = DateTime.now().weekday - 1;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id;
    final userEmail = authProvider.user?.email;
    final schoolId = authProvider.currentSchoolId;
    
    if (userId != null || userEmail != null) {
      try {
        // Récupérer les enfants via parent_student_links
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
        
        // Récupérer les étudiants
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
          await _loadSchedule(selectedChild!);
        }
      } catch (e) {
        print('❌ Erreur chargement: $e');
      }
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _loadSchedule(Map<String, dynamic> child) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('schedules')
          .where('className', isEqualTo: child['className'])
          .get();
      
      schedules = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'className': data['className'] ?? '',
          'subject': data['subject'] ?? '',
          'dayOfWeek': data['dayOfWeek'] ?? '',
          'startTime': data['startTime'] ?? '',
          'endTime': data['endTime'] ?? '',
          'room': data['room'] ?? '',
          'teacher': data['teacher'] ?? '',
        };
      }).toList();
    } catch (e) {
      print('❌ Erreur chargement emploi du temps: $e');
      schedules = [];
    }
  }

  List<Map<String, dynamic>> get _schedulesForSelectedDay {
    return schedules
        .where((s) => s['dayOfWeek'] == days[selectedDay])
        .toList()
      ..sort((a, b) => (a['startTime'] as String).compareTo(b['startTime'] as String));
  }

  String _formatTime(String time) {
    try {
      final parts = time.split(':');
      if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
      return time;
    } catch (e) {
      return time;
    }
  }

  Color _getSubjectColor(String subject) {
    switch (subject) {
      case 'Mathématiques': return Colors.red;
      case 'Français': return Colors.blue;
      case 'Anglais': return Colors.green;
      case 'Physique': return Colors.orange;
      case 'Chimie': return Colors.purple;
      case 'Histoire': return Colors.brown;
      case 'Géographie': return Colors.teal;
      case 'SVT': return Colors.lightGreen;
      case 'EPS': return Colors.cyan;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Emploi du temps', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData, tooltip: 'Actualiser'),
        ],
      ),
      body: Column(
        children: [
          if (auth.currentSchoolId != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.business, size: 18, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  Text(auth.schoolName ?? 'Établissement scolaire', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF3B82F6))),
                ],
              ),
            ),

          if (children.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.child_care, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text('Aucun enfant associé', style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
              ),
            )
          else if (children.length == 1)
            Expanded(
              child: _buildScheduleContent(children.first),
            )
          else
            Expanded(
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
                    child: DropdownButtonFormField<Map<String, dynamic>>(
                      value: selectedChild,
                      decoration: const InputDecoration(border: InputBorder.none, prefixIcon: Icon(Icons.child_care, color: Color(0xFF10B981))),
                      items: children.map((child) {
                        return DropdownMenuItem(
                          value: child,
                          child: Text(child['fullName']),
                        );
                      }).toList(),
                      onChanged: (value) async {
                        setState(() => _isLoading = true);
                        selectedChild = value;
                        await _loadSchedule(value!);
                        setState(() => _isLoading = false);
                      },
                    ),
                  ),
                  Expanded(child: selectedChild == null ? const SizedBox() : _buildScheduleContent(selectedChild!)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScheduleContent(Map<String, dynamic> child) {
    final schedulesForDay = _schedulesForSelectedDay;
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.purple[50],
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.purple, 
                child: Text((child['fullName'] as String)[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    Text(child['fullName'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), 
                    Text('Classe: ${child['className']}'),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            itemCount: days.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(days[index]),
                  selected: selectedDay == index,
                  onSelected: (selected) => setState(() => selectedDay = index),
                  backgroundColor: Colors.grey[100],
                  selectedColor: Colors.purple,
                  labelStyle: TextStyle(color: selectedDay == index ? Colors.white : Colors.black),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: schedulesForDay.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.schedule, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('Aucun cours ce jour', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: schedulesForDay.length,
                  itemBuilder: (context, index) {
                    final schedule = schedulesForDay[index];
                    final subjectColor = _getSubjectColor(schedule['subject']);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: subjectColor, 
                          child: Text((schedule['subject'] as String).isNotEmpty ? schedule['subject'][0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text(schedule['subject'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_formatTime(schedule['startTime'])} - ${_formatTime(schedule['endTime'])}'),
                            Text('Salle: ${schedule['room']}', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(color: Colors.purple[50], borderRadius: BorderRadius.circular(12)),
                          child: Text(schedule['startTime'], style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}