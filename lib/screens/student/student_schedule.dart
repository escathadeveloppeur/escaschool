// lib/screens/student/student_schedule.dart

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';

class StudentScheduleScreen extends StatefulWidget {
  const StudentScheduleScreen({super.key});

  @override
  _StudentScheduleScreenState createState() => _StudentScheduleScreenState();
}

class _StudentScheduleScreenState extends State<StudentScheduleScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> schedules = [];
  String studentClassName = '';
  String studentClassFirestoreId = '';
  
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final Map<DateTime, List<Map<String, dynamic>>> _events = {};
  bool _isLoading = true;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _selectedDay = _focusedDay;
    _loadDataFromFirestore();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 🔥 Charger les données depuis Firestore
  Future<void> _loadDataFromFirestore() async {
    setState(() => _isLoading = true);
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.id;
      final userEmail = authProvider.user?.email;
      
      if (userId != null || userEmail != null) {
        // 1. Récupérer l'étudiant via son compte utilisateur
        Query studentQuery = FirebaseFirestore.instance.collection('students');
        
        if (userEmail != null) {
          studentQuery = studentQuery.where('userEmail', isEqualTo: userEmail);
        } else {
          studentQuery = studentQuery.where('userId', isEqualTo: userId);
        }
        
        final studentSnapshot = await studentQuery.limit(1).get();
        
        if (studentSnapshot.docs.isNotEmpty) {
          final studentData = studentSnapshot.docs.first.data() as Map<String, dynamic>;
          studentClassName = studentData['className'] ?? '';
          studentClassFirestoreId = studentData['classFirestoreId'] ?? '';
          
          print('✅ Étudiant trouvé: Classe = $studentClassName');
          
          // 2. Charger les horaires pour cette classe
          if (studentClassFirestoreId.isNotEmpty) {
            final schedulesSnapshot = await FirebaseFirestore.instance
                .collection('schedules')
                .where('classFirestoreId', isEqualTo: studentClassFirestoreId)
                .get();
            
            schedules = [];
            for (var doc in schedulesSnapshot.docs) {
              final data = doc.data() as Map<String, dynamic>;
              schedules.add({
                'id': doc.id,
                'className': data['className'] ?? '',
                'subject': data['subject'] ?? '',
                'dayOfWeek': data['dayOfWeek'] ?? '',
                'startTime': data['startTime'] ?? '',
                'endTime': data['endTime'] ?? '',
                'room': data['room'] ?? '',
                'teacher': data['teacher'] ?? '',
              });
            }
            
            print('✅ ${schedules.length} horaires chargés pour la classe $studentClassName');
          }
        } else {
          print('⚠️ Aucun étudiant trouvé pour userId: $userId');
        }
      }
      
      // Organiser les événements par date
      final eventsMap = <DateTime, List<Map<String, dynamic>>>{};
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      
      for (var schedule in schedules) {
        final dayIndex = _getDayIndex(schedule['dayOfWeek']);
        final eventDate = DateTime(
          startOfWeek.year,
          startOfWeek.month,
          startOfWeek.day + dayIndex,
        );
        
        if (!eventsMap.containsKey(eventDate)) {
          eventsMap[eventDate] = [];
        }
        eventsMap[eventDate]!.add(schedule);
      }
      
      setState(() {
        _events.clear();
        _events.addAll(eventsMap);
        _isLoading = false;
      });
      
      _animationController.forward(from: 0);
      
    } catch (e) {
      print('❌ Erreur chargement: $e');
      setState(() {
        schedules = [];
        _isLoading = false;
      });
      _showSnackBar('Erreur de chargement: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }
  
  int _getDayIndex(String day) {
    switch (day.toLowerCase()) {
      case 'lundi': return 0;
      case 'mardi': return 1;
      case 'mercredi': return 2;
      case 'jeudi': return 3;
      case 'vendredi': return 4;
      case 'samedi': return 5;
      default: return 0;
    }
  }
  
  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final normalizedDate = DateTime(day.year, day.month, day.day);
    return _events[normalizedDate] ?? [];
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
            Text('Chargement de l\'emploi du temps...'),
          ],
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Mon emploi du temps',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
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
      body: Column(
        children: [
          if (auth.currentSchoolId != null && !auth.isSuperAdmin)
            Container(
              margin: const EdgeInsets.all(16),
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
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF3B82F6)),
                  ),
                ],
              ),
            ),

          // En-tête avec la classe de l'étudiant
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF8B5CF6).withOpacity(0.1),
            child: Row(
              children: [
                Icon(Icons.class_, color: const Color(0xFF8B5CF6)),
                const SizedBox(width: 8),
                Text(
                  'Classe: ${studentClassName.isNotEmpty ? studentClassName : 'Non définie'}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
          ),
          
          // Calendrier
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF8B5CF6).withOpacity(0.05),
            child: TableCalendar<Map<String, dynamic>>(
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (format) {
                setState(() => _calendarFormat = format);
              },
              onPageChanged: (focusedDay) => _focusedDay = focusedDay,
              eventLoader: _getEventsForDay,
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: Color(0xFF8B5CF6),
                  shape: BoxShape.circle,
                ),
                markerDecoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                markerSize: 6,
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
              ),
            ),
          ),
          
          // Légende rapide
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            color: const Color(0xFF8B5CF6).withOpacity(0.05),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _legendDot(const Color(0xFF3B82F6), 'Maths'),
                _legendDot(const Color(0xFF10B981), 'Physique'),
                _legendDot(const Color(0xFFF59E0B), 'Chimie'),
                _legendDot(const Color(0xFF8B5CF6), 'Français'),
                _legendDot(const Color(0xFFEF4444), 'Anglais'),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Titre du jour
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: const Color(0xFF8B5CF6), size: 20),
                const SizedBox(width: 12),
                Text(
                  _selectedDay != null 
                    ? _formatDate(_selectedDay!)
                    : "Aujourd'hui",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_getEventsForDay(_selectedDay ?? _focusedDay).length} cours',
                    style: TextStyle(color: const Color(0xFF8B5CF6), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          
          // Liste des cours
          Expanded(
            child: _buildDaySchedule(),
          ),
        ],
      ),
    );
  }
  
  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }
  
  String _formatDate(DateTime date) {
    final days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    final months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
    return '${days[date.weekday - 1]} ${date.day} ${months[date.month - 1]} ${date.year}';
  }
  
  Widget _buildDaySchedule() {
    final selectedDate = _selectedDay ?? _focusedDay;
    final events = _getEventsForDay(selectedDate);
    
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text("Aucun cours prévu", style: TextStyle(fontSize: 18, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text("Profitez de votre journée !", style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }
    
    events.sort((a, b) => _compareTime(a['startTime'], b['startTime']));
    
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final schedule = events[index];
        final startTime = schedule['startTime'];
        final endTime = schedule['endTime'];
        final subject = schedule['subject'];
        final room = schedule['room'] ?? 'Salle non spécifiée';
        final className = schedule['className'] ?? studentClassName;
        
        return FadeTransition(
          opacity: _animationController,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8)],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showClassDetails(schedule),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 70,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(startTime.split(':')[0], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6))),
                            Text('h${startTime.split(':')[1]}', style: TextStyle(fontSize: 12, color: const Color(0xFF8B5CF6))),
                            Container(margin: const EdgeInsets.symmetric(vertical: 4), height: 1, width: 30, color: const Color(0xFF8B5CF6).withOpacity(0.3)),
                            Text(endTime.split(':')[0], style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: const Color(0xFF8B5CF6))),
                            Text('h${endTime.split(':')[1]}', style: TextStyle(fontSize: 10, color: const Color(0xFF8B5CF6).withOpacity(0.7))),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(subject, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.class_, size: 14, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Text(className, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Text(room, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.arrow_forward_ios, size: 16, color: const Color(0xFF8B5CF6)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  int _compareTime(String time1, String time2) {
    final parts1 = time1.split(':');
    final parts2 = time2.split(':');
    final hour1 = int.parse(parts1[0]);
    final minute1 = int.parse(parts1[1]);
    final hour2 = int.parse(parts2[0]);
    final minute2 = int.parse(parts2[1]);
    if (hour1 != hour2) return hour1 - hour2;
    return minute1 - minute2;
  }
  
  void _showClassDetails(Map<String, dynamic> schedule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.school, color: const Color(0xFF8B5CF6))),
            const SizedBox(width: 8),
            Text(schedule['subject'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow(Icons.class_, 'Classe', schedule['className'] ?? studentClassName),
            const SizedBox(height: 8),
            _detailRow(Icons.calendar_today, 'Jour', schedule['dayOfWeek']),
            const SizedBox(height: 8),
            _detailRow(Icons.access_time, 'Horaires', '${schedule['startTime']} - ${schedule['endTime']}'),
            const SizedBox(height: 8),
            _detailRow(Icons.location_on, 'Salle', schedule['room'] ?? 'Non spécifiée'),
            const SizedBox(height: 8),
            _detailRow(Icons.timer, 'Durée', _calculateDuration(schedule['startTime'], schedule['endTime'])),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        ],
      ),
    );
  }
  
  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 12),
        SizedBox(width: 70, child: Text(label, style: TextStyle(color: Colors.grey[600]))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
      ],
    );
  }
  
  String _calculateDuration(String startTime, String endTime) {
    if (startTime.isEmpty || endTime.isEmpty) return 'Durée inconnue';
    try {
      final startParts = startTime.split(':');
      final endParts = endTime.split(':');
      final startHour = int.parse(startParts[0]);
      final startMinute = int.parse(startParts[1]);
      final endHour = int.parse(endParts[0]);
      final endMinute = int.parse(endParts[1]);
      final totalStart = startHour * 60 + startMinute;
      final totalEnd = endHour * 60 + endMinute;
      final duration = totalEnd - totalStart;
      final hours = duration ~/ 60;
      final minutes = duration % 60;
      if (hours > 0 && minutes > 0) return '${hours}h ${minutes}min';
      if (hours > 0) return '${hours}h';
      return '${minutes}min';
    } catch (e) {
      return 'Durée inconnue';
    }
  }
}