// lib/screens/staff/staff_card_management_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/staff_model.dart';
import '../../models/staff_card_model.dart';
import '../../services/staff_card_service.dart';
import '../../providers/auth_provider.dart';

class StaffCardManagementScreen extends StatefulWidget {
  final String schoolId;
  final String schoolName;

  const StaffCardManagementScreen({
    Key? key,
    required this.schoolId,
    required this.schoolName,
  }) : super(key: key);

  @override
  State<StaffCardManagementScreen> createState() => _StaffCardManagementScreenState();
}

class _StaffCardManagementScreenState extends State<StaffCardManagementScreen> {
  List<StaffModel> _staffList = [];
  List<StaffModel> _filteredStaff = [];
  bool _isLoading = true;
  bool _isGenerating = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedPosition = 'Tous';

  final List<String> _positions = [
    'Tous',
    'Ménage',
    'Sentinelle / Sécurité',
    'Chauffeur',
    'Cuisinier',
    'Jardinier',
    'Infirmier',
    'Bibliothécaire',
    'Secrétaire',
    'Comptable',
    'Magasinier',
    'Autre',
  ];

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('staff')
          .where('schoolId', isEqualTo: widget.schoolId)
          .get();

      _staffList = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return StaffModel(
          id: data['localId'],
          firestoreId: doc.id,
          fullName: data['fullName'] ?? '',
          position: data['position'] ?? '',
          phone: data['phone'],
          email: data['email'],
          address: data['address'],
          hireDate: data['hireDate'] != null ? DateTime.parse(data['hireDate']) : DateTime.now(),
          salary: (data['salary'] ?? 0.0).toDouble(),
          isActive: data['isActive'] ?? true,
          schoolId: data['schoolId'] ?? widget.schoolId,
          createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
          updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
        );
      }).toList();

      _filterStaff();
      setState(() {
        _isLoading = false;
        if (_staffList.isEmpty) {
          _errorMessage = 'Aucun membre du personnel trouvé.';
        }
      });
    } catch (e) {
      print('❌ Erreur chargement personnel: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors du chargement: $e';
      });
    }
  }

  void _filterStaff() {
    setState(() {
      _filteredStaff = _staffList.where((staff) {
        final matchesSearch = _searchQuery.isEmpty ||
            staff.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            staff.position.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (staff.phone?.contains(_searchQuery) ?? false);

        final matchesPosition = _selectedPosition == 'Tous' ||
            staff.position == _selectedPosition;

        return matchesSearch && matchesPosition;
      }).toList();
    });
  }

  Future<void> _generateStaffCard(StaffModel staff) async {
    setState(() {
      _isGenerating = true;
    });

    try {
      final cardData = StaffCardData(
        staffId: staff.firestoreId!,
        fullName: staff.fullName,
        position: staff.position,
        schoolId: widget.schoolId,
        schoolName: widget.schoolName,
        phone: staff.phone,
        email: staff.email,
        address: staff.address,
        salary: staff.salary,
        hireDate: staff.hireDate,
        isActive: staff.isActive,
      );

      final cardImage = await StaffCardService.generateStaffCard(
        data: cardData,
        width: 800,
        height: 550,
        pixelRatio: 2.0,
      );

      await StaffCardService.saveCardToDevice(cardImage, staff.fullName);

      setState(() {
        _isGenerating = false;
      });

      _showStaffCardDialog(cardImage, staff);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Carte générée avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showStaffCardDialog(Uint8List cardImage, StaffModel staff) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🆔 Carte de service',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    cardImage,
                    width: 400,
                    height: 280,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                staff.fullName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                staff.position,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Fermer'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _shareCard(cardImage, staff.fullName);
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('Partager'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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

  Future<void> _shareCard(Uint8List cardImage, String staffName) async {
    try {
      await StaffCardService.shareCard(cardImage, staffName);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Carte partagée avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showCardDetail(StaffModel staff) async {
    try {
      final cardData = StaffCardData(
        staffId: staff.firestoreId!,
        fullName: staff.fullName,
        position: staff.position,
        schoolId: widget.schoolId,
        schoolName: widget.schoolName,
        phone: staff.phone,
        email: staff.email,
        address: staff.address,
        salary: staff.salary,
        hireDate: staff.hireDate,
        isActive: staff.isActive,
      );

      final cardImage = await StaffCardService.generateStaffCard(
        data: cardData,
        width: 600,
        height: 400,
        pixelRatio: 1.5,
      );

      _showStaffCardDialog(cardImage, staff);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteStaff(StaffModel staff) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmation'),
        content: Text('Voulez-vous vraiment supprimer ${staff.fullName} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('staff')
            .doc(staff.firestoreId)
            .delete();
        
        await _loadStaff();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Personnel supprimé'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des cartes de service'),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStaff,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) {
                _searchQuery = value;
                _filterStaff();
              },
              decoration: InputDecoration(
                hintText: 'Rechercher par nom, poste ou téléphone...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF0F766E)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchQuery = '';
                          _filterStaff();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF0F766E), width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          // Filtres par poste
          Container(
            height: 45,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _positions.length,
              itemBuilder: (context, index) {
                final position = _positions[index];
                final isSelected = _selectedPosition == position;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(position),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedPosition = position;
                        _filterStaff();
                      });
                    },
                    backgroundColor: Colors.grey[100],
                    selectedColor: const Color(0xFF0F766E).withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? const Color(0xFF0F766E) : Colors.grey[700],
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),

          // Statistiques
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.people, size: 16, color: Color(0xFF0F766E)),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_filteredStaff.length} membre(s) du personnel',
                  style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Liste
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredStaff.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage ?? 'Aucun personnel trouvé',
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ajoutez d\'abord des membres du personnel',
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _loadStaff,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Recharger'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F766E),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filteredStaff.length,
                        itemBuilder: (context, index) {
                          final staff = _filteredStaff[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: staff.isActive
                                        ? [const Color(0xFF0F766E), const Color(0xFF14B8A6)]
                                        : [Colors.grey[400]!, Colors.grey[500]!],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(
                                    staff.fullName.isNotEmpty ? staff.fullName[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                staff.fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F766E).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      staff.position,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF0F766E),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (staff.phone != null && staff.phone!.isNotEmpty)
                                    Text(
                                      '📞 ${staff.phone}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                  Text(
                                    staff.isActive ? '✅ Actif' : '❌ Inactif',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: staff.isActive ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Bouton Voir la carte
                                  IconButton(
                                    icon: const Icon(Icons.visibility, color: Color(0xFF0F766E)),
                                    onPressed: _isGenerating ? null : () => _showCardDetail(staff),
                                    tooltip: 'Voir la carte',
                                  ),
                                  // Bouton Générer
                                  IconButton(
                                    icon: const Icon(Icons.credit_card, color: Color(0xFF10B981)),
                                    onPressed: _isGenerating ? null : () => _generateStaffCard(staff),
                                    tooltip: 'Générer la carte',
                                  ),
                                  // Bouton Supprimer
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteStaff(staff),
                                    tooltip: 'Supprimer',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}