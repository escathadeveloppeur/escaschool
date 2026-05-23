// lib/screens/admin/admin_schedule.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/db_helper.dart';
import '../../models/class_model.dart';
import '../../providers/auth_provider.dart';

class AdminSchedule extends StatefulWidget {
  final String professorFirestoreId;
  final String professorName;
  final VoidCallback? onScheduleChanged;

  const AdminSchedule({
    super.key,
    required this.professorFirestoreId,
    required this.professorName,
    this.onScheduleChanged,
  });

  @override
  _AdminScheduleState createState() => _AdminScheduleState();
}

class _AdminScheduleState extends State<AdminSchedule>
    with SingleTickerProviderStateMixin {
  final DBHelper db = DBHelper();
  List<Map<String, dynamic>> _schedules = [];
  List<ClassModel> _availableClasses = [];
  List<Map<String, dynamic>> _filteredSchedules = [];
  bool _loading = true;
  bool _isEditing = false;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();
  String _selectedDay = 'Lundi';
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 0);
  String? _editingScheduleId;

  String _filterDay = 'Tous';
  String _searchQuery = '';

  late AnimationController _animationController;
  final List<String> _days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];

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
    _subjectController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  /// 🔥 Charger les horaires et classes depuis Firestore
  Future<void> _loadDataFromFirestore() async {
    setState(() => _loading = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      // Charger les horaires du professeur
      final schedulesSnapshot = await FirebaseFirestore.instance
          .collection('schedules')
          .where('professorFirestoreId', isEqualTo: widget.professorFirestoreId)
          .get();
      
      final List<Map<String, dynamic>> schedulesList = [];
      for (var doc in schedulesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        schedulesList.add({
          'id': doc.id,
          'professorFirestoreId': data['professorFirestoreId'],
          'classFirestoreId': data['classFirestoreId'],
          'className': data['className'] ?? '',
          'dayOfWeek': data['dayOfWeek'] ?? '',
          'startTime': data['startTime'] ?? '',
          'endTime': data['endTime'] ?? '',
          'subject': data['subject'] ?? '',
          'room': data['room'] ?? '',
        });
      }
      
      // Charger les classes disponibles
      Query classQuery = FirebaseFirestore.instance.collection('classes');
      if (!auth.isSuperAdmin && schoolId != null) {
        classQuery = classQuery.where('schoolId', isEqualTo: schoolId);
      }
      
      final classesSnapshot = await classQuery.get();
      final List<ClassModel> classesList = [];
      for (var doc in classesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        classesList.add(ClassModel(
          firestoreId: doc.id,
          className: data['className'] ?? '',
          level: data['level'] ?? '',
          year: data['year'] ?? '',
          subjects: List<Map<String, dynamic>>.from(data['subjects'] ?? []),
          schoolId: data['schoolId'],
        ));
      }

      setState(() {
        _schedules = schedulesList;
        _availableClasses = classesList;
        _filteredSchedules = schedulesList;
        _loading = false;
      });
      _animationController.forward(from: 0);
      
      print('✅ ${schedulesList.length} horaires chargés depuis Firestore');
    } catch (e) {
      print('❌ Erreur chargement: $e');
      setState(() => _loading = false);
    }
  }

  void _filterSchedules() {
    setState(() {
      _filteredSchedules = _schedules.where((schedule) {
        final matchesDay = _filterDay == 'Tous' || schedule['dayOfWeek'] == _filterDay;
        final matchesSearch = _searchQuery.isEmpty ||
            (schedule['subject']?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
            (schedule['room']?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
        return matchesDay && matchesSearch;
      }).toList();
    });
  }

  Future<void> _pickTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF10B981), onPrimary: Colors.white),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _showClassSelectionDialog() {
    if (_availableClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune classe disponible'), backgroundColor: Color(0xFFEF4444)),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        String? selectedClassFirestoreId;
        String? selectedClassName;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Sélectionner une classe', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                height: 350,
                child: ListView.builder(
                  itemCount: _availableClasses.length,
                  itemBuilder: (context, index) {
                    final cls = _availableClasses[index];
                    final isSelected = selectedClassFirestoreId == cls.firestoreId;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF10B981).withOpacity(0.1) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? const Color(0xFF10B981) : Colors.grey[200]!),
                      ),
                      child: ListTile(
                        leading: Radio<String>(
                          value: cls.firestoreId ?? '',
                          groupValue: selectedClassFirestoreId,
                          onChanged: (value) {
                            setStateDialog(() {
                              selectedClassFirestoreId = value;
                              selectedClassName = cls.className;
                            });
                          },
                          activeColor: const Color(0xFF10B981),
                        ),
                        title: Text(cls.className, style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                        subtitle: Text('Niveau: ${cls.level}'),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                ElevatedButton(
                  onPressed: selectedClassFirestoreId == null
                      ? null
                      : () async {
                          Navigator.pop(context);
                          await _saveScheduleWithClass(selectedClassFirestoreId!, selectedClassName!);
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 🔥 Sauvegarder l'horaire dans Firestore
  Future<void> _saveScheduleWithClass(String classFirestoreId, String className) async {
    final startStr = '${_startTime.hour}:${_startTime.minute.toString().padLeft(2, '0')}';
    final endStr = '${_endTime.hour}:${_endTime.minute.toString().padLeft(2, '0')}';

    final scheduleData = {
      'professorFirestoreId': widget.professorFirestoreId,
      'classFirestoreId': classFirestoreId,
      'className': className,
      'dayOfWeek': _selectedDay,
      'startTime': startStr,
      'endTime': endStr,
      'subject': _subjectController.text.trim(),
      'room': _roomController.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (_editingScheduleId != null) {
        await FirebaseFirestore.instance
            .collection('schedules')
            .doc(_editingScheduleId)
            .update(scheduleData);
        await db.addLog("Modification horaire: ${_subjectController.text}");
        _showSnackBar('Horaire modifié avec succès', const Color(0xFF10B981));
      } else {
        await FirebaseFirestore.instance.collection('schedules').add(scheduleData);
        await db.addLog("Ajout horaire: ${_subjectController.text}");
        _showSnackBar('Horaire ajouté avec succès', const Color(0xFF10B981));
      }

      _clearForm();
      await _loadDataFromFirestore();
      widget.onScheduleChanged?.call();
    } catch (e) {
      _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
    }
  }

  Future<void> _saveSchedule() async {
    if (!_formKey.currentState!.validate()) return;
    _showClassSelectionDialog();
  }

  void _clearForm() {
    _subjectController.clear();
    _roomController.clear();
    _selectedDay = 'Lundi';
    _startTime = const TimeOfDay(hour: 8, minute: 0);
    _endTime = const TimeOfDay(hour: 9, minute: 0);
    _editingScheduleId = null;
    setState(() => _isEditing = false);
  }

  void _editSchedule(Map<String, dynamic> schedule) {
    _editingScheduleId = schedule['id'];
    _subjectController.text = schedule['subject'] ?? '';
    _roomController.text = schedule['room'] ?? '';
    _selectedDay = schedule['dayOfWeek'] ?? 'Lundi';

    final startParts = (schedule['startTime'] ?? '8:00').split(':');
    _startTime = TimeOfDay(hour: int.tryParse(startParts[0]) ?? 8, minute: int.tryParse(startParts[1]) ?? 0);

    final endParts = (schedule['endTime'] ?? '9:00').split(':');
    _endTime = TimeOfDay(hour: int.tryParse(endParts[0]) ?? 9, minute: int.tryParse(endParts[1]) ?? 0);

    setState(() => _isEditing = true);
  }

  /// 🔥 Supprimer l'horaire de Firestore
  Future<void> _deleteSchedule(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmation', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Voulez-vous vraiment supprimer cet horaire ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('schedules').doc(id).delete();
        await _loadDataFromFirestore();
        widget.onScheduleChanged?.call();
        _showSnackBar('Horaire supprimé', const Color(0xFF10B981));
      } catch (e) {
        _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Color _getDayColor(String day) {
    switch (day) {
      case 'Lundi': return const Color(0xFF3B82F6);
      case 'Mardi': return const Color(0xFF10B981);
      case 'Mercredi': return const Color(0xFFF59E0B);
      case 'Jeudi': return const Color(0xFF8B5CF6);
      case 'Vendredi': return const Color(0xFF06B6D4);
      case 'Samedi': return const Color(0xFF6366F1);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Horaire - ${widget.professorName}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDataFromFirestore),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))))
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Formulaire d'ajout
                  Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: (_isEditing ? const Color(0xFFF59E0B) : const Color(0xFF10B981)).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                  child: Icon(_isEditing ? Icons.edit : Icons.add, color: _isEditing ? const Color(0xFFF59E0B) : const Color(0xFF10B981), size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(_isEditing ? 'Modifier l\'horaire' : 'Ajouter un horaire', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                              ],
                            ),
                            const SizedBox(height: 20),

                            DropdownButtonFormField<String>(
                              value: _selectedDay,
                              decoration: InputDecoration(labelText: 'Jour *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF10B981)), filled: true, fillColor: Colors.white),
                              items: _days.map((day) => DropdownMenuItem(value: day, child: Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: _getDayColor(day))), const SizedBox(width: 8), Text(day)]))).toList(),
                              onChanged: (value) => setState(() => _selectedDay = value!),
                            ),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _pickTime(true),
                                    child: InputDecorator(
                                      decoration: InputDecoration(labelText: 'Heure début *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), prefixIcon: const Icon(Icons.access_time, color: Color(0xFF10B981)), filled: true, fillColor: Colors.white),
                                      child: Text(_startTime.format(context), style: const TextStyle(fontSize: 16)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _pickTime(false),
                                    child: InputDecorator(
                                      decoration: InputDecoration(labelText: 'Heure fin *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), prefixIcon: const Icon(Icons.access_time, color: Color(0xFF10B981)), filled: true, fillColor: Colors.white),
                                      child: Text(_endTime.format(context), style: const TextStyle(fontSize: 16)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _subjectController,
                              decoration: InputDecoration(labelText: 'Matière *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), prefixIcon: const Icon(Icons.book, color: Color(0xFF10B981)), filled: true, fillColor: Colors.white),
                              validator: (value) => value!.isEmpty ? 'Champ requis' : null,
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _roomController,
                              decoration: InputDecoration(labelText: 'Salle', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), prefixIcon: const Icon(Icons.location_on, color: Color(0xFF10B981)), filled: true, fillColor: Colors.white),
                            ),
                            const SizedBox(height: 20),

                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _saveSchedule,
                                    icon: Icon(_isEditing ? Icons.update : Icons.save),
                                    label: Text(_isEditing ? 'Modifier' : 'Ajouter'),
                                    style: ElevatedButton.styleFrom(backgroundColor: _isEditing ? const Color(0xFFF59E0B) : const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                                  ),
                                ),
                                if (_isEditing) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _clearForm,
                                      icon: const Icon(Icons.clear),
                                      label: const Text('Annuler'),
                                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: Colors.grey[300]!), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Barre de recherche et filtre
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(hintText: 'Rechercher...', prefixIcon: const Icon(Icons.search, color: Color(0xFF10B981)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)), filled: true, fillColor: Colors.white),
                            onChanged: (value) { _searchQuery = value; _filterSchedules(); },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey[200]!)),
                          child: DropdownButton<String>(
                            value: _filterDay,
                            underline: const SizedBox(),
                            items: [const DropdownMenuItem(value: 'Tous', child: Text('Tous')), ..._days.map((day) => DropdownMenuItem(value: day, child: Text(day)))],
                            onChanged: (value) { setState(() => _filterDay = value!); _filterSchedules(); },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Liste des horaires
                  _filteredSchedules.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Icon(Icons.schedule, size: 64, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text(_schedules.isEmpty ? 'Aucun horaire programmé' : 'Aucun résultat', style: TextStyle(color: Colors.grey[500])),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredSchedules.length,
                          itemBuilder: (context, index) {
                            final schedule = _filteredSchedules[index];
                            final dayColor = _getDayColor(schedule['dayOfWeek']);
                            return FadeTransition(
                              opacity: _animationController,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: Container(width: 50, height: 50, decoration: BoxDecoration(gradient: LinearGradient(colors: [dayColor, dayColor.withOpacity(0.7)]), borderRadius: BorderRadius.circular(14)), child: Center(child: Text(schedule['dayOfWeek'][0], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)))),
                                  title: Text(schedule['subject'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.class_, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(schedule['className'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                          const SizedBox(width: 12),
                                          const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text('${schedule['startTime']} - ${schedule['endTime']}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                        ],
                                      ),
                                      if (schedule['room']?.isNotEmpty ?? false)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Row(children: [const Icon(Icons.location_on, size: 14, color: Colors.grey), const SizedBox(width: 4), Text(schedule['room'], style: TextStyle(fontSize: 12, color: Colors.grey[600]))]),
                                        ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                        child: IconButton(icon: const Icon(Icons.edit, color: Color(0xFFF59E0B), size: 20), onPressed: () => _editSchedule(schedule)),
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                        child: IconButton(icon: const Icon(Icons.delete, color: Color(0xFFEF4444), size: 20), onPressed: () => _deleteSchedule(schedule['id'])),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}