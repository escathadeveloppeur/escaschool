// lib/screens/teacher/teacher_schedule.dart

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import 'teacher_attendance.dart';

class TeacherScheduleScreen extends StatefulWidget {
  final String teacherName;
  final String professorFirestoreId;
  
  const TeacherScheduleScreen({
    super.key,
    required this.teacherName,
    required this.professorFirestoreId,
  });

  @override
  _TeacherScheduleScreenState createState() => _TeacherScheduleScreenState();
}

class _TeacherScheduleScreenState extends State<TeacherScheduleScreen> {
  List<Map<String, dynamic>> schedules = [];
  
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final Map<DateTime, List<Map<String, dynamic>>> _events = {};
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadDataFromFirestore();
  }
  
  /// 🔥 Charger les horaires depuis Firestore
  Future<void> _loadDataFromFirestore() async {
    setState(() => _isLoading = true);
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      Query query = FirebaseFirestore.instance.collection('schedules');
      query = query.where('professorFirestoreId', isEqualTo: widget.professorFirestoreId);
      
      if (schoolId != null && !auth.isSuperAdmin) {
        query = query.where('schoolId', isEqualTo: schoolId);
      }
      
      final snapshot = await query.get();
      
final List<Map<String, dynamic>> schedulesData = [];
for (var doc in snapshot.docs) {
  final data = doc.data() as Map<String, dynamic>?;
  if (data == null) continue;
  
  schedulesData.add({
    'id': doc.id,
    'professorFirestoreId': data['professorFirestoreId'] ?? '',
    'classFirestoreId': data['classFirestoreId'] ?? '',
    'className': data['className'] ?? '',
    'dayOfWeek': data['dayOfWeek'] ?? '',
    'startTime': data['startTime'] ?? '',
    'endTime': data['endTime'] ?? '',
    'subject': data['subject'] ?? '',
    'room': data['room'] ?? '',
    'schoolId': data['schoolId'],
  });
}
      print('✅ ${schedulesData.length} horaires chargés pour prof ${widget.professorFirestoreId}');
      
      // Construire les événements pour le calendrier
      final eventsMap = <DateTime, List<Map<String, dynamic>>>{};
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      
      for (var schedule in schedulesData) {
        final dayIndex = _getDayIndex(schedule['dayOfWeek']);
        if (dayIndex >= 0) {
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
      }
      
      setState(() {
        schedules = schedulesData;
        _events.clear();
        _events.addAll(eventsMap);
        _isLoading = false;
      });
      
    } catch (e) {
      print('❌ Erreur chargement horaires: $e');
      setState(() {
        schedules = [];
        _isLoading = false;
      });
      _showSnackBar('Erreur de chargement: $e', const Color(0xFFEF4444));
    }
  }
  
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
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
      case 'dimanche': return 6;
      default: return -1;
    }
  }
  
  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final normalizedDate = DateTime(day.year, day.month, day.day);
    return _events[normalizedDate] ?? [];
  }
  
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Emploi du temps - ${widget.teacherName}'),
        backgroundColor: Colors.blue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDataFromFirestore,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
              ),
            )
          : Column(
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
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Calendrier
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.blue[50],
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
                        color: Colors.blue.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Colors.blue,
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
                  color: Colors.blue[50],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _legendDot(Colors.blue, 'Maths'),
                      _legendDot(Colors.green, 'Physique'),
                      _legendDot(Colors.orange, 'Chimie'),
                      _legendDot(Colors.purple, 'Français'),
                      _legendDot(Colors.red, 'Anglais'),
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
                      Icon(Icons.calendar_today, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 12),
                      Text(
                        _selectedDay != null 
                          ? _formatDate(_selectedDay!)
                          : "Aujourd'hui",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_getEventsForDay(_selectedDay ?? _focusedDay).length} cours',
                          style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w500),
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
            Text(
              "Aucun cours prévu",
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              "Profitez de votre journée !",
              style: TextStyle(color: Colors.grey[500]),
            ),
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
        final className = schedule['className'] ?? 'Classe inconnue';
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showClassDetails(schedule),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Heure
                    Container(
                      width: 70,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            startTime.split(':')[0],
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800],
                            ),
                          ),
                          Text(
                            'h${startTime.split(':')[1]}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[600],
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            height: 1,
                            width: 30,
                            color: Colors.blue[200],
                          ),
                          Text(
                            endTime.split(':')[0],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue[600],
                            ),
                          ),
                          Text(
                            'h${endTime.split(':')[1]}',
                            style: TextStyle(fontSize: 10, color: Colors.blue[400]),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Détails du cours
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subject,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.class_, size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(
                                className,
                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(
                                room,
                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Icône action
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  int _compareTime(String time1, String time2) {
    if (time1.isEmpty || time2.isEmpty) return 0;
    try {
      final parts1 = time1.split(':');
      final parts2 = time2.split(':');
      final hour1 = int.parse(parts1[0]);
      final minute1 = int.parse(parts1[1]);
      final hour2 = int.parse(parts2[0]);
      final minute2 = int.parse(parts2[1]);
      if (hour1 != hour2) return hour1 - hour2;
      return minute1 - minute2;
    } catch (e) {
      return 0;
    }
  }
  
  void _showClassDetails(Map<String, dynamic> schedule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.school, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              schedule['subject'],
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow(Icons.class_, 'Classe', schedule['className'] ?? 'Inconnue'),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _takeAttendance(schedule);
            },
            icon: const Icon(Icons.checklist),
            label: const Text('Prendre présences'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 12),
        SizedBox(
          width: 70,
          child: Text(label, style: TextStyle(color: Colors.grey[600])),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
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
  
  void _takeAttendance(Map<String, dynamic> schedule) {
    Navigator.push(
      context,
      MaterialPageRoute(
 builder: (context) => TeacherAttendanceScreen(
  teacherName: widget.teacherName,
  professorFirestoreId: widget.professorFirestoreId,
  assignedClasses: [schedule['className'] ?? ''],
  assignedSubjects: [schedule['subject']],
),
      ),
    );
  }
}