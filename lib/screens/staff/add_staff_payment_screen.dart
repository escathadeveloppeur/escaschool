// lib/screens/staff/add_staff_payment_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/db_helper.dart';
import '../../providers/auth_provider.dart';

class AddStaffPaymentScreen extends StatefulWidget {
  final Map<String, dynamic> staff;
  const AddStaffPaymentScreen({super.key, required this.staff});

  @override
  _AddStaffPaymentScreenState createState() => _AddStaffPaymentScreenState();
}

class _AddStaffPaymentScreenState extends State<AddStaffPaymentScreen> {
  final _formKey = GlobalKey<FormState>();

  TextEditingController _bonusController = TextEditingController();
  TextEditingController _deductionController = TextEditingController();
  TextEditingController _notesController = TextEditingController();

  String _selectedMonth = '';
  int _selectedYear = DateTime.now().year;
  String _selectedMethod = 'Espèces';
  double _netSalary = 0;

  final List<String> _months = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
  final List<String> _paymentMethods = ['Espèces', 'Virement', 'Mobile Money'];

  @override
  void initState() {
    super.initState();
    _selectedMonth = _months[DateTime.now().month - 1];
    _calculateNetSalary();
    _bonusController.addListener(_calculateNetSalary);
    _deductionController.addListener(_calculateNetSalary);
  }

  void _calculateNetSalary() {
    double bonus = double.tryParse(_bonusController.text) ?? 0;
    double deduction = double.tryParse(_deductionController.text) ?? 0;
    _netSalary = (widget.staff['salary'] ?? 0.0) + bonus - deduction;
    setState(() {});
  }

  /// 🔥 Sauvegarder directement dans Firestore
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    final paymentData = {
      'staffFirestoreId': widget.staff['firestoreId'],
      'staffName': widget.staff['fullName'],
      'position': widget.staff['position'],
      'month': _selectedMonth,
      'year': _selectedYear,
      'baseSalary': widget.staff['salary'] ?? 0,
      'bonus': double.tryParse(_bonusController.text) ?? 0,
      'deduction': double.tryParse(_deductionController.text) ?? 0,
      'netSalary': _netSalary,
      'paymentDate': FieldValue.serverTimestamp(),
      'paymentMethod': _selectedMethod,
      'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      'schoolId': auth.currentSchoolId,
    };

    try {
      await FirebaseFirestore.instance.collection('staff_payments').add(paymentData);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paiement enregistré'), backgroundColor: Colors.green));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Paiement - ${widget.staff['fullName']}'), backgroundColor: Colors.white, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                DropdownButtonFormField<String>(value: _selectedMonth, items: _months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(), onChanged: (v) => setState(() => _selectedMonth = v!), decoration: const InputDecoration(labelText: 'Mois', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(value: _selectedYear, items: [2023,2024,2025,2026].map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(), onChanged: (v) => setState(() => _selectedYear = v!), decoration: const InputDecoration(labelText: 'Année', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextFormField(controller: _bonusController, decoration: const InputDecoration(labelText: 'Prime (FCFA)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.add)), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextFormField(controller: _deductionController, decoration: const InputDecoration(labelText: 'Déduction (FCFA)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.remove)), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(value: _selectedMethod, items: _paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(), onChanged: (v) => setState(() => _selectedMethod = v!), decoration: const InputDecoration(labelText: 'Mode de paiement', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextFormField(controller: _notesController, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()), maxLines: 2),
                const Divider(height: 24),
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Net à payer:', style: TextStyle(fontWeight: FontWeight.bold)), Text('${_netSalary.toStringAsFixed(0)} FCFA', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF10B981)))])),
              ]))),
              const SizedBox(height: 24),
              ElevatedButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Enregistrer le paiement'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
            ],
          ),
        ),
      ),
    );
  }
}