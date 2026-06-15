// lib/screens/admin/admin_schedule.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/db_helper.dart';
import '../../models/class_model.dart';
import '../../providers/auth_provider.dart';

// ===================== PALETTE / THEME HELPERS =====================
class _AppColors {
  static const Color primary = Color(0xFF1E3A8A);
  static const Color primaryLight = Color(0xFF3B5BDB);
  static const Color background = Color(0xFFF4F6FB);
  static const Color cardBorder = Color(0xFFE6E9F2);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF6B7280);
}

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

  Future<void> _loadDataFromFirestore() async {
    setState(() => _loading = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
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
      _showSnackBar('Aucune classe disponible', const Color(0xFFEF4444));
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
                        border: Border.all(color: isSelected ? const Color(0xFF10B981) : _AppColors.cardBorder),
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
                        title: Text(cls.className, style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, color: _AppColors.textDark)),
                        subtitle: Text('Niveau: ${cls.level}', style: TextStyle(color: _AppColors.textMuted)),
                      ),
                    );
                  },
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(foregroundColor: _AppColors.textMuted),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: selectedClassFirestoreId == null
                      ? null
                      : () async {
                          Navigator.pop(context);
                          await _saveScheduleWithClass(selectedClassFirestoreId!, selectedClassName!);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

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

  Future<void> _deleteSchedule(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmation', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Voulez-vous vraiment supprimer cet horaire ?'),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: _AppColors.textMuted),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
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
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
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
      backgroundColor: _AppColors.background,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Horaire - ${widget.professorName}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 19, letterSpacing: 0.2),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_AppColors.primary, _AppColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: "Actualiser",
              onPressed: _loadDataFromFirestore,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_AppColors.primary),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // Formulaire d'ajout/modification
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _AppColors.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: (_isEditing ? const Color(0xFFF59E0B) : const Color(0xFF10B981)).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    _isEditing ? Icons.edit_rounded : Icons.add_rounded,
                                    color: _isEditing ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    _isEditing ? 'Modifier l\'horaire' : 'Ajouter un horaire',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _AppColors.textDark),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            DropdownButtonFormField<String>(
                              value: _selectedDay,
                              decoration: InputDecoration(
                                labelText: 'Jour *',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                prefixIcon: Icon(Icons.calendar_today_rounded, color: const Color(0xFF10B981)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              items: _days.map((day) => DropdownMenuItem(
                                value: day,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _getDayColor(day),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(day, style: TextStyle(color: _AppColors.textDark)),
                                  ],
                                ),
                              )).toList(),
                              onChanged: (value) => setState(() => _selectedDay = value!),
                            ),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _pickTime(true),
                                    borderRadius: BorderRadius.circular(14),
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'Heure début *',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                        prefixIcon: Icon(Icons.access_time_rounded, color: const Color(0xFF10B981)),
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                      child: Text(
                                        _startTime.format(context),
                                        style: TextStyle(fontSize: 16, color: _AppColors.textDark),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _pickTime(false),
                                    borderRadius: BorderRadius.circular(14),
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'Heure fin *',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                        prefixIcon: Icon(Icons.access_time_rounded, color: const Color(0xFF10B981)),
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                      child: Text(
                                        _endTime.format(context),
                                        style: TextStyle(fontSize: 16, color: _AppColors.textDark),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _subjectController,
                              decoration: InputDecoration(
                                labelText: 'Matière *',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                prefixIcon: Icon(Icons.book_rounded, color: const Color(0xFF10B981)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (value) => value!.isEmpty ? 'Champ requis' : null,
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _roomController,
                              decoration: InputDecoration(
                                labelText: 'Salle',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                prefixIcon: Icon(Icons.location_on_rounded, color: const Color(0xFF10B981)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 20),

                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _saveSchedule,
                                    icon: Icon(_isEditing ? Icons.update_rounded : Icons.save_rounded),
                                    label: Text(_isEditing ? 'Modifier' : 'Ajouter'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isEditing ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                  ),
                                ),
                                if (_isEditing) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _clearForm,
                                      icon: const Icon(Icons.clear_rounded),
                                      label: const Text('Annuler'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: _AppColors.textMuted,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        side: BorderSide(color: _AppColors.cardBorder),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      ),
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

                  const SizedBox(height: 20),

                  // Barre de recherche et filtre
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Rechercher...',
                              hintStyle: TextStyle(color: _AppColors.textMuted),
                              prefixIcon: Icon(Icons.search_rounded, color: _AppColors.primaryLight),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: _AppColors.cardBorder),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: _AppColors.primaryLight, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onChanged: (value) {
                              _searchQuery = value;
                              _filterSchedules();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _AppColors.cardBorder),
                          ),
                          child: DropdownButton<String>(
                            value: _filterDay,
                            underline: const SizedBox(),
                            icon: Icon(Icons.arrow_drop_down_rounded, color: _AppColors.primaryLight),
                            items: [
                              const DropdownMenuItem(value: 'Tous', child: Text('Tous', style: TextStyle(color: _AppColors.textDark))),
                              ..._days.map((day) => DropdownMenuItem(
                                value: day,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: _getDayColor(day)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(day, style: TextStyle(color: _AppColors.textDark)),
                                  ],
                                ),
                              )),
                            ],
                            onChanged: (value) {
                              setState(() => _filterDay = value!);
                              _filterSchedules();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Liste des horaires
                  if (_filteredSchedules.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: _AppColors.primary.withOpacity(0.06),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.schedule_rounded,
                                size: 56,
                                color: _AppColors.primary.withOpacity(0.4),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _schedules.isEmpty ? 'Aucun horaire programmé' : 'Aucun résultat',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _AppColors.textDark),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _schedules.isEmpty ? 'Commencez par ajouter un horaire' : 'Essayez avec d\'autres critères',
                              style: TextStyle(fontSize: 13, color: _AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: _filteredSchedules.length,
                      itemBuilder: (context, index) {
                        final schedule = _filteredSchedules[index];
                        final dayColor = _getDayColor(schedule['dayOfWeek']);
                        return FadeTransition(
                          opacity: _animationController,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: _AppColors.cardBorder),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [dayColor, dayColor.withOpacity(0.7)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Center(
                                      child: Text(
                                        schedule['dayOfWeek'][0],
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          schedule['subject'] ?? '',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                            color: _AppColors.textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.class_rounded, size: 14, color: _AppColors.textMuted),
                                            const SizedBox(width: 4),
                                            Text(
                                              schedule['className'] ?? '',
                                              style: TextStyle(fontSize: 12, color: _AppColors.textMuted),
                                            ),
                                            const SizedBox(width: 12),
                                            Icon(Icons.access_time_rounded, size: 14, color: _AppColors.textMuted),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${schedule['startTime']} - ${schedule['endTime']}',
                                              style: TextStyle(fontSize: 12, color: _AppColors.textMuted),
                                            ),
                                          ],
                                        ),
                                        if (schedule['room']?.isNotEmpty ?? false)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Row(
                                              children: [
                                                Icon(Icons.location_on_rounded, size: 14, color: _AppColors.textMuted),
                                                const SizedBox(width: 4),
                                                Text(
                                                  schedule['room'],
                                                  style: TextStyle(fontSize: 12, color: _AppColors.textMuted),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildActionButton(
                                        icon: Icons.edit_rounded,
                                        color: const Color(0xFFF59E0B),
                                        onPressed: () => _editSchedule(schedule),
                                      ),
                                      const SizedBox(width: 4),
                                      _buildActionButton(
                                        icon: Icons.delete_rounded,
                                        color: const Color(0xFFEF4444),
                                        onPressed: () => _deleteSchedule(schedule['id']),
                                      ),
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

  Widget _buildActionButton({required IconData icon, required Color color, required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onPressed,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }
}