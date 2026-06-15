// lib/screens/staff/add_payment.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/db_helper.dart';
import '../../providers/auth_provider.dart';

class AddPaymentScreen extends StatefulWidget {
  final Map<String, dynamic>? payment;
  final String? firestoreId;
  const AddPaymentScreen({super.key, this.payment, this.firestoreId});

  @override
  _AddPaymentScreenState createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends State<AddPaymentScreen> {
  final DBHelper db = DBHelper();
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> allStudents = [];
  List<Map<String, dynamic>> filteredStudents = [];
  Map<String, dynamic>? selectedStudent;
  String feeType = "Frais de l'État";
  String month = '';
  TextEditingController amountController = TextEditingController();
  bool loading = true;
  int year = DateTime.now().year;
  
  bool isSemester = false;
  String selectedPeriod = '';
  String _selectedCycle = 'all'; // 'all', 'primaire', 'secondaire'
  
  final List<String> months = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
  ];
  
  final List<int> years = [2023, 2024, 2025, 2026, 2027];
  Map<String, List<String>> paidMonthsByStudent = {};

  final List<Map<String, dynamic>> _cycles = [
    {'id': 'all', 'name': 'Tous', 'icon': Icons.all_inclusive, 'color': Color(0xFF6366F1)},
    {'id': 'primaire', 'name': 'Primaire', 'icon': Icons.abc, 'color': Color(0xFF10B981)},
    {'id': 'secondaire', 'name': 'Secondaire', 'icon': Icons.school, 'color': Color(0xFF8B5CF6)},
  ];

  @override
  void initState() {
    super.initState();
    _loadDataFromFirestore();
  }

  int _getMonthNumber(String monthName) {
    switch (monthName.toLowerCase()) {
      case 'janvier': return 1;
      case 'février': return 2;
      case 'mars': return 3;
      case 'avril': return 4;
      case 'mai': return 5;
      case 'juin': return 6;
      case 'juillet': return 7;
      case 'août': return 8;
      case 'septembre': return 9;
      case 'octobre': return 10;
      case 'novembre': return 11;
      case 'décembre': return 12;
      case 'semestre 1': return 1;
      case 'semestre 2': return 2;
      default: return int.tryParse(monthName) ?? 1;
    }
  }

  /// 🔥 Charger les étudiants et paiements depuis Firestore
  Future<void> _loadDataFromFirestore() async {
    setState(() => loading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      // 1. Charger les étudiants depuis Firestore
      Query studentQuery = FirebaseFirestore.instance.collection('students');
      if (schoolId != null && !auth.isSuperAdmin) {
        studentQuery = studentQuery.where('schoolId', isEqualTo: schoolId);
      }
      
      final studentsSnapshot = await studentQuery.get();
      
      allStudents = studentsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'firestoreId': doc.id,
          'fullName': data['fullName'] ?? '',
          'className': data['className'] ?? '',
          'classCycleType': data['classCycleType'] ?? 'primaire',
          'sectionName': data['sectionName'],
          'schoolId': data['schoolId'],
        };
      }).toList();
      
      // Filtrer initialement
      _filterStudentsByCycle();
      
      // 2. Charger les paiements existants pour vérifier les mois déjà payés
      Query paymentQuery = FirebaseFirestore.instance.collection('payments');
      if (schoolId != null && !auth.isSuperAdmin) {
        paymentQuery = paymentQuery.where('schoolId', isEqualTo: schoolId);
      }
      
      final paymentsSnapshot = await paymentQuery.get();
      
      paidMonthsByStudent.clear();
      for (var doc in paymentsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final studentId = data['studentFirestoreId'];
        final monthValue = data['month'] ?? 0;
        final yearValue = data['year'] ?? 0;
        
        if (studentId != null) {
          if (!paidMonthsByStudent.containsKey(studentId)) {
            paidMonthsByStudent[studentId] = [];
          }
          final monthYearKey = '$monthValue-$yearValue';
          if (!paidMonthsByStudent[studentId]!.contains(monthYearKey)) {
            paidMonthsByStudent[studentId]!.add(monthYearKey);
          }
        }
      }
      
      // 3. Si en mode édition, charger les données du paiement
      if (widget.payment != null) {
        amountController.text = widget.payment!['amount']?.toString() ?? '';
        feeType = widget.payment!['feeType'] ?? "Frais de l'État";
        month = widget.payment!['month']?.toString() ?? '';
        year = widget.payment!['year'] ?? DateTime.now().year;
        
        selectedStudent = filteredStudents.firstWhere(
          (s) => s['firestoreId'] == widget.payment!['studentFirestoreId'],
          orElse: () => {},
        );
        
        if (month.contains('Semestre')) {
          isSemester = true;
          selectedPeriod = month;
        } else {
          selectedPeriod = month;
        }
      } else {
        month = months[DateTime.now().month - 1];
        selectedPeriod = month;
      }
    } catch (e) {
      debugPrint("❌ Erreur chargement: $e");
      _showSnackBar("Erreur de chargement", const Color(0xFFEF4444));
    } finally {
      setState(() => loading = false);
    }
  }

  void _filterStudentsByCycle() {
    setState(() {
      if (_selectedCycle == 'all') {
        filteredStudents = List.from(allStudents);
      } else {
        filteredStudents = allStudents.where((student) {
          final studentCycle = student['classCycleType'] ?? 'primaire';
          return studentCycle == _selectedCycle;
        }).toList();
      }
      
      // Réinitialiser la sélection si l'étudiant n'est plus dans la liste filtrée
      if (selectedStudent != null && 
          !filteredStudents.any((s) => s['firestoreId'] == selectedStudent!['firestoreId'])) {
        selectedStudent = null;
      }
    });
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

  bool _isAlreadyPaid() {
    if (selectedStudent == null || selectedPeriod.isEmpty) return false;
    
    final studentId = selectedStudent!['firestoreId'];
    final periodKey = isSemester 
        ? selectedPeriod 
        : '${_getMonthNumber(selectedPeriod)}-$year';
    
    return paidMonthsByStudent.containsKey(studentId) &&
           paidMonthsByStudent[studentId]!.contains(periodKey);
  }

  /// 🔥 Sauvegarder le paiement directement dans Firestore
 Future<void> _save() async {
  if (!_formKey.currentState!.validate() || selectedStudent == null) return;

  final auth = Provider.of<AuthProvider>(context, listen: false);
  final String? schoolId = auth.currentSchoolId;  // 🔥 String?

  // 🔥 Vérification que schoolId n'est pas null
  if (schoolId == null) {
    _showSnackBar("Erreur: École non identifiée", const Color(0xFFEF4444));
    return;
  }

  if (widget.payment == null && _isAlreadyPaid()) {
    final confirmed = await _showAlreadyPaidDialog();
    if (!confirmed) return;
  }

  final monthForDb = isSemester ? selectedPeriod : selectedPeriod;
  final monthNumber = _getMonthNumber(monthForDb);
  
  final paymentData = {
    'studentFirestoreId': selectedStudent!['firestoreId'],
    'fullName': selectedStudent!['fullName'],
    'className': selectedStudent!['className'],
    'classCycleType': selectedStudent!['classCycleType'] ?? 'primaire',
    'sectionName': selectedStudent!['sectionName'],
    'month': monthNumber,
    'monthName': monthForDb,
    'year': year,
    'feeType': feeType,
    'amount': double.tryParse(amountController.text) ?? 0.0,
    'paymentDate': FieldValue.serverTimestamp(),
    'schoolId': schoolId,  // 🔥 String
    'status': 'paid',
  };

  try {
   if (widget.payment == null) {
  await FirebaseFirestore.instance.collection('payments').add(paymentData);
  
  // Convertir String? en int? si addLog attend int?
  final int? schoolIdInt = int.tryParse(schoolId ?? '');
  await db.addLog("Ajout paiement: ${selectedStudent!['fullName']} - $monthForDb $year", schoolId: schoolIdInt);
  _showSnackBar("Paiement ajouté avec succès", const Color(0xFF10B981));
}else {
   if (widget.firestoreId != null) {
  await FirebaseFirestore.instance
      .collection('payments')
      .doc(widget.firestoreId)
      .update(paymentData);
  
  // Convertir String? en int? si addLog attend int?
  final int? schoolIdInt = int.tryParse(schoolId ?? '');
  await db.addLog("Modification paiement: ${selectedStudent!['fullName']}", schoolId: schoolIdInt);
  _showSnackBar("Paiement modifié avec succès", const Color(0xFF10B981));
}
    }
    Navigator.pop(context, true);
  } catch (e) {
    _showSnackBar("Erreur: $e", const Color(0xFFEF4444));
  }
}

  Future<bool> _showAlreadyPaidDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning, color: Color(0xFFF59E0B)),
            const SizedBox(width: 10),
            const Text("Paiement déjà existant", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          "${selectedStudent!['fullName']} a déjà payé pour "
          "${isSemester ? 'le' : 'le mois de'} $selectedPeriod ${isSemester ? '' : year}.\n\n"
          "Voulez-vous quand même ajouter ce paiement ?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Confirmer"),
          ),
        ],
      ),
    ) ?? false;
  }

  Widget _buildCycleSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: _cycles.map((cycle) {
          final isSelected = _selectedCycle == cycle['id'];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCycle = cycle['id'];
                  _filterStudentsByCycle();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isSelected ? cycle['color'] : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(cycle['icon'], color: isSelected ? Colors.white : cycle['color'], size: 18),
                    const SizedBox(width: 8),
                    Text(
                      cycle['name'],
                      style: TextStyle(
                        color: isSelected ? Colors.white : cycle['color'],
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    if (isSemester) {
      return DropdownButtonFormField<String>(
        value: selectedPeriod,
        decoration: const InputDecoration(
          labelText: "Semestre",
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.calendar_month),
        ),
        items: const [
          DropdownMenuItem(
            value: "Semestre 1",
            child: Text("Semestre 1 (Janvier - Juin)"),
          ),
          DropdownMenuItem(
            value: "Semestre 2",
            child: Text("Semestre 2 (Juillet - Décembre)"),
          ),
        ],
        onChanged: (value) {
          setState(() {
            selectedPeriod = value!;
            month = selectedPeriod;
          });
        },
        validator: (v) => v == null || v.isEmpty ? "Période requise" : null,
      );
    } else {
      return Column(
        children: [
          DropdownButtonFormField<String>(
            value: selectedPeriod,
            decoration: const InputDecoration(
              labelText: "Mois",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calendar_today),
            ),
            items: months.map((m) {
              final monthNum = _getMonthNumber(m);
              final isPaid = selectedStudent != null && 
                  selectedStudent!.isNotEmpty &&
                  paidMonthsByStudent.containsKey(selectedStudent!['firestoreId']) &&
                  paidMonthsByStudent[selectedStudent!['firestoreId']]!.contains('$monthNum-$year');
              
              return DropdownMenuItem(
                value: m,
                child: Row(
                  children: [
                    Text(m),
                    if (isPaid) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle, size: 14, color: Color(0xFF10B981)),
                    ],
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedPeriod = value!;
                month = selectedPeriod;
              });
            },
            validator: (v) => v == null || v.isEmpty ? "Mois requis" : null,
          ),
          
          const SizedBox(height: 12),
          
          DropdownButtonFormField<int>(
            value: year,
            decoration: const InputDecoration(
              labelText: "Année",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calendar_today),
            ),
            items: years.map((y) {
              return DropdownMenuItem(
                value: y,
                child: Text(y.toString()),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                year = value!;
              });
            },
          ),
        ],
      );
    }
  }

  Widget _buildPaidMonthsList() {
    if (selectedStudent == null || selectedStudent!.isEmpty) {
      return const SizedBox();
    }
    
    final studentId = selectedStudent!['firestoreId'];
    final paidMonths = paidMonthsByStudent[studentId] ?? [];
    
    if (paidMonths.isEmpty) {
      return Text(
        "Aucun paiement enregistré pour cet élève",
        style: TextStyle(color: Colors.grey[600], fontSize: 13),
      );
    }
    
    final currentYearMonths = paidMonths
        .where((monthYear) => monthYear.endsWith('-$year'))
        .toList();
    
    if (currentYearMonths.isEmpty) {
      return Text(
        "Aucun paiement pour $year",
        style: TextStyle(color: Colors.grey[600], fontSize: 13),
      );
    }
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: currentYearMonths.map((monthYear) {
        final monthNum = int.tryParse(monthYear.split('-')[0]) ?? 0;
        final monthName = months[monthNum - 1];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 12, color: Color(0xFF10B981)),
              const SizedBox(width: 4),
              Text(
                monthName,
                style: const TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.payment == null ? "Ajouter un paiement" : "Modifier le paiement",
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
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
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF3B82F6)),
                            ),
                          ],
                        ),
                      ),

                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.person, color: Color(0xFF3B82F6), size: 20),
                                ),
                                const SizedBox(width: 12),
                                const Text("Élève", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Sélecteur de cycle
                            _buildCycleSelector(),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<Map<String, dynamic>>(
                              value: selectedStudent,
                              hint: filteredStudents.isEmpty 
                                  ? Text(_selectedCycle == 'all' 
                                      ? "Aucun étudiant disponible" 
                                      : "Aucun étudiant en $_selectedCycle")
                                  : const Text("Choisir l'élève"),
                              items: filteredStudents.map((s) {
                                final isSecondary = s['classCycleType'] == 'secondaire';
                                return DropdownMenuItem(
                                  value: s,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s['fullName'],
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            isSecondary ? Icons.school : Icons.abc,
                                            size: 12,
                                            color: isSecondary ? Colors.purple : Colors.green,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            s['className'],
                                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                          ),
                                          if (isSecondary && s['sectionName'] != null && s['sectionName'].isNotEmpty) ...[
                                            const SizedBox(width: 4),
                                            Text(
                                              ' - ${s['sectionName']}',
                                              style: TextStyle(fontSize: 11, color: Colors.purple[600]),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) {
                                setState(() => selectedStudent = v);
                              },
                              validator: (v) => v == null ? "Élève requis" : null,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.school),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.receipt, color: Color(0xFF10B981), size: 20),
                                ),
                                const SizedBox(width: 12),
                                const Text("Type de frais", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: feeType,
                              items: const [
                                DropdownMenuItem(value: "Frais de l'État", child: Text("Frais de l'État")),
                                DropdownMenuItem(value: "Minervale", child: Text("Minervale")),
                                DropdownMenuItem(value: "Autre", child: Text("Autre")),
                              ],
                              onChanged: (v) => setState(() {
                                feeType = v ?? feeType;
                                if (feeType == "Frais de l'État") {
                                  isSemester = true;
                                  selectedPeriod = "Semestre 1";
                                  month = selectedPeriod;
                                } else {
                                  isSemester = false;
                                  selectedPeriod = month.isNotEmpty ? month : months[DateTime.now().month - 1];
                                }
                              }),
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.category),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.euro, color: Color(0xFFF59E0B), size: 20),
                                ),
                                const SizedBox(width: 12),
                                const Text("Montant", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: amountController,
                              decoration: const InputDecoration(
                                labelText: "Montant",
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.euro_symbol),
                                hintText: "0.00",
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.isEmpty) return "Montant requis";
                                final amount = double.tryParse(v);
                                if (amount == null || amount <= 0) return "Montant invalide";
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.calendar_month, color: Color(0xFF8B5CF6), size: 20),
                                ),
                                const SizedBox(width: 12),
                                const Text("Période de paiement", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            if (feeType == "Frais de l'État")
                              AbsorbPointer(
                                absorbing: true,
                                child: Opacity(opacity: 0.7, child: _buildPeriodSelector()),
                              )
                            else
                              _buildPeriodSelector(),
                            
                            if (selectedStudent != null && _isAlreadyPaid())
                              Container(
                                margin: const EdgeInsets.only(top: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning, color: Color(0xFFF59E0B)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "${selectedStudent!['fullName']} a déjà payé pour cette période",
                                        style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            
                            if (selectedStudent != null && selectedStudent!.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Mois déjà payés en $year:",
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildPaidMonthsList(),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        widget.payment == null ? "Ajouter le paiement" : "Modifier le paiement",
                        style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text("Annuler"),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}