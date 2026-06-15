// lib/screens/staff/add_staff_payment_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/db_helper.dart';
import '../../providers/auth_provider.dart';
import 'staff_pay_slip_screen.dart'; // Nouvel écran pour le bulletin

// ===================== PALETTE / THEME HELPERS =====================
class _AppColors {
  static const Color primary = Color(0xFF1E3A8A);
  static const Color primaryLight = Color(0xFF3B5BDB);
  static const Color background = Color(0xFFF4F6FB);
  static const Color cardBorder = Color(0xFFE6E9F2);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  static const Color secondary = Color(0xFF8B5CF6);
}

class AddStaffPaymentScreen extends StatefulWidget {
  final Map<String, dynamic> staff;
  const AddStaffPaymentScreen({super.key, required this.staff});

  @override
  _AddStaffPaymentScreenState createState() => _AddStaffPaymentScreenState();
}

class _AddStaffPaymentScreenState extends State<AddStaffPaymentScreen> {
  final DBHelper db = DBHelper();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _bonusController;
  late TextEditingController _deductionController;
  late TextEditingController _notesController;

  String _selectedMonth = '';
  int _selectedYear = DateTime.now().year;
  String _selectedMethod = 'Espèces';
  double _netSalary = 0;
  bool _isLoading = false;

  final List<String> _months = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
  ];
  
  final List<String> _paymentMethods = ['Espèces', 'Virement', 'Mobile Money'];
  final List<int> _years = [2023, 2024, 2025, 2026, 2027, 2028];

  @override
  void initState() {
    super.initState();
    _selectedMonth = _months[DateTime.now().month - 1];
    _bonusController = TextEditingController();
    _deductionController = TextEditingController();
    _notesController = TextEditingController();
    _calculateNetSalary();
    _bonusController.addListener(_calculateNetSalary);
    _deductionController.addListener(_calculateNetSalary);
  }

  @override
  void dispose() {
    _bonusController.dispose();
    _deductionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _calculateNetSalary() {
    double baseSalary = (widget.staff['salary'] ?? 0.0).toDouble();
    double bonus = double.tryParse(_bonusController.text) ?? 0;
    double deduction = double.tryParse(_deductionController.text) ?? 0;
    _netSalary = baseSalary + bonus - deduction;
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final String? schoolId = auth.currentSchoolId;

      if (schoolId == null || schoolId.isEmpty) {
        _showSnackBar('Erreur: École non identifiée', _AppColors.danger);
        setState(() => _isLoading = false);
        return;
      }

      final double bonus = double.tryParse(_bonusController.text) ?? 0;
      final double deduction = double.tryParse(_deductionController.text) ?? 0;
      final double baseSalary = (widget.staff['salary'] ?? 0.0).toDouble();

      final paymentData = {
        'staffFirestoreId': widget.staff['firestoreId'],
        'staffName': widget.staff['fullName'],
        'position': widget.staff['position'],
        'month': _selectedMonth,
        'year': _selectedYear,
        'baseSalary': baseSalary,
        'bonus': bonus,
        'deduction': deduction,
        'netSalary': _netSalary,
        'paymentDate': FieldValue.serverTimestamp(),
        'paymentMethod': _selectedMethod,
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'schoolId': schoolId,
        'status': 'paid',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Ajouter le paiement à Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('staff_payments')
          .add(paymentData);

      // Ajouter le log
      await db.addLog(
        "Ajout paiement personnel: ${widget.staff['fullName']} - $_selectedMonth $_selectedYear (${_netSalary.toStringAsFixed(0)} FCFA)",
        schoolId: int.tryParse(schoolId),
      );

      _showSnackBar('Paiement enregistré avec succès', _AppColors.success);

      if (mounted) {
        // ✅ Demander si l'utilisateur veut générer le bulletin
        final shouldGeneratePayslip = await _showGeneratePayslipDialog();
        
        if (shouldGeneratePayslip) {
          // Préparer les données pour le bulletin
          final payslipData = {
            'paymentId': docRef.id,
            'staffName': widget.staff['fullName'],
            'position': widget.staff['position'],
            'month': _selectedMonth,
            'year': _selectedYear,
            'baseSalary': baseSalary,
            'bonus': bonus,
            'deduction': deduction,
            'netSalary': _netSalary,
            'paymentMethod': _selectedMethod,
            'paymentDate': DateTime.now(),
            'schoolId': schoolId,
            'notes': _notesController.text.trim(),
          };
          
          // Naviguer vers l'écran du bulletin
          Navigator.pop(context, true);
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StaffPaySlipScreen(paymentData: payslipData),
            ),
          );
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      print('❌ Erreur sauvegarde paiement: $e');
      _showSnackBar('Erreur: $e', _AppColors.danger);
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showGeneratePayslipDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.receipt_long_rounded, color: _AppColors.success, size: 28),
            const SizedBox(width: 10),
            const Text('Générer le bulletin?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Voulez-vous générer le bulletin de paie pour ${widget.staff['fullName']}?\n\n'
          'Vous pourrez le partager, l\'imprimer ou le sauvegarder.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non, merci'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.receipt_long_rounded),
            label: const Text('Générer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _AppColors.success,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    ) ?? false;
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

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final baseSalary = (widget.staff['salary'] ?? 0.0).toDouble();

    return Scaffold(
      backgroundColor: _AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paiement personnel',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            Text(
              widget.staff['fullName'] ?? '',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: _AppColors.textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ... (tout le reste du build reste identique)
              
              // Indicateur d'école
              if (auth.currentSchoolId != null && !auth.isSuperAdmin)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.business, size: 18, color: _AppColors.info),
                      const SizedBox(width: 8),
                      Text(
                        auth.schoolName ?? 'Gestion du personnel',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _AppColors.info),
                      ),
                    ],
                  ),
                ),

              // Carte informations du personnel
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _AppColors.secondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.person_rounded, size: 22, color: _AppColors.secondary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.staff['fullName'] ?? '',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _AppColors.textDark),
                                ),
                                Text(
                                  widget.staff['position'] ?? '',
                                  style: TextStyle(fontSize: 13, color: _AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Salaire de base:', style: TextStyle(fontWeight: FontWeight.w500)),
                            Text(
                              '${baseSalary.toStringAsFixed(0)} FCFA',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _AppColors.success),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Carte période
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _AppColors.info.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.calendar_month_rounded, size: 18, color: _AppColors.info),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Période de paiement',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _AppColors.textDark),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedMonth,
                        decoration: const InputDecoration(
                          labelText: 'Mois',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today_rounded),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                        onChanged: (v) => setState(() => _selectedMonth = v!),
                        validator: (v) => v == null ? 'Mois requis' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: _selectedYear,
                        decoration: const InputDecoration(
                          labelText: 'Année',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_view_month_rounded),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                        onChanged: (v) => setState(() => _selectedYear = v!),
                        validator: (v) => v == null ? 'Année requise' : null,
                      ),
                    ],
                  ),
                ),
              ),

              // Carte primes et déductions
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _AppColors.warning.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.calculate_rounded, size: 18, color: _AppColors.warning),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Primes et déductions',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _AppColors.textDark),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _bonusController,
                        decoration: const InputDecoration(
                          labelText: 'Prime (FCFA)',
                          hintText: '0',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.add_circle_rounded, color: _AppColors.success),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v != null && v.isNotEmpty && double.tryParse(v) == null) {
                            return 'Montant invalide';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _deductionController,
                        decoration: const InputDecoration(
                          labelText: 'Déduction (FCFA)',
                          hintText: '0',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.remove_circle_rounded, color: _AppColors.danger),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v != null && v.isNotEmpty && double.tryParse(v) == null) {
                            return 'Montant invalide';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Carte mode de paiement
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.payment_rounded, size: 18, color: _AppColors.success),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Mode de paiement',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _AppColors.textDark),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedMethod,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.credit_card_rounded),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _paymentMethods.map((m) {
                          IconData icon;
                          switch (m) {
                            case 'Espèces':
                              icon = Icons.money_rounded;
                              break;
                            case 'Virement':
                              icon = Icons.account_balance_rounded;
                              break;
                            case 'Mobile Money':
                              icon = Icons.phone_android_rounded;
                              break;
                            default:
                              icon = Icons.payment_rounded;
                          }
                          return DropdownMenuItem(
                            value: m,
                            child: Row(
                              children: [
                                Icon(icon, size: 20, color: _AppColors.success),
                                const SizedBox(width: 8),
                                Text(m),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedMethod = v!),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optionnel)',
                          hintText: 'Ajouter une remarque...',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.note_rounded),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),

              // Total net à payer
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_AppColors.success, Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _AppColors.success.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NET À PAYER',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Salaire + Prime - Déduction',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                    Text(
                      '${_netSalary.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Boutons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Annuler'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _save,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(_isLoading ? 'Enregistrement...' : 'Enregistrer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}