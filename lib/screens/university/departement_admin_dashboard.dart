// lib/screens/university/departement_admin_dashboard.dart

import 'package:flutter/material.dart';
import '../../services/db_helper.dart';
import '../../models/university/departement_model.dart';
import '../../models/university/niveau_model.dart';
import '../../models/university/module_model.dart';

class DepartementAdminDashboard extends StatefulWidget {
  final int departementId;
  final String departementNom;
  
  const DepartementAdminDashboard({
    super.key,
    required this.departementId,
    required this.departementNom,
  });

  @override
  _DepartementAdminDashboardState createState() => _DepartementAdminDashboardState();
}

class _DepartementAdminDashboardState extends State<DepartementAdminDashboard> with SingleTickerProviderStateMixin {
  final DBHelper db = DBHelper();
  List<NiveauModel> _niveaux = [];
  bool _isLoading = true;
  final int _selectedTabIndex = 0;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _niveaux = await db.getNiveauxByDepartement(widget.departementId);
    setState(() => _isLoading = false);
    _animationController.forward(from: 0);
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

  // ==================== GESTION DES NIVEAUX ====================
  void _showAddNiveauDialog() {
    final nomController = TextEditingController();
    final ordreController = TextEditingController();
    final dureeController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Ajouter un niveau',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomController,
                decoration: InputDecoration(
                  labelText: 'Nom du niveau *',
                  hintText: 'Ex: Licence 1, Master 2, Doctorat',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.school),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ordreController,
                decoration: InputDecoration(
                  labelText: 'Ordre *',
                  hintText: '1, 2, 3...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.numbers),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dureeController,
                decoration: InputDecoration(
                  labelText: 'Durée (années) *',
                  hintText: '3, 4, 5...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.calendar_today),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.description),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nomController.text.isEmpty) {
                _showSnackBar('Le nom du niveau est requis', const Color(0xFFF59E0B));
                return;
              }
              
              final newNiveau = NiveauModel(
                id: DateTime.now().millisecondsSinceEpoch,
                departementId: widget.departementId,
                nom: nomController.text,
                ordre: int.tryParse(ordreController.text) ?? 1,
                duree: int.tryParse(dureeController.text) ?? 3,
                description: descriptionController.text.isNotEmpty ? descriptionController.text : null,
              );
              
              await db.addNiveau(newNiveau);
              await _loadData();
              _showSnackBar('Niveau ajouté avec succès', const Color(0xFF10B981));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _editNiveau(NiveauModel niveau) {
    final nomController = TextEditingController(text: niveau.nom);
    final ordreController = TextEditingController(text: niveau.ordre.toString());
    final dureeController = TextEditingController(text: niveau.duree.toString());
    final descriptionController = TextEditingController(text: niveau.description ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Modifier le niveau',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomController,
                decoration: InputDecoration(
                  labelText: 'Nom du niveau *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.school),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ordreController,
                decoration: InputDecoration(
                  labelText: 'Ordre *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.numbers),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dureeController,
                decoration: InputDecoration(
                  labelText: 'Durée (années) *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.calendar_today),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.description),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nomController.text.isEmpty) {
                _showSnackBar('Le nom du niveau est requis', const Color(0xFFF59E0B));
                return;
              }
              
              final updatedNiveau = NiveauModel(
                id: niveau.id,
                departementId: widget.departementId,
                nom: nomController.text,
                ordre: int.tryParse(ordreController.text) ?? 1,
                duree: int.tryParse(dureeController.text) ?? 3,
                description: descriptionController.text.isNotEmpty ? descriptionController.text : null,
              );
              
              await db.updateNiveau(updatedNiveau);
              await _loadData();
              _showSnackBar('Niveau modifié avec succès', const Color(0xFF10B981));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Modifier'),
          ),
        ],
      ),
    );
  }

  void _deleteNiveau(NiveauModel niveau) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Confirmer la suppression',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('Voulez-vous vraiment supprimer le niveau "${niveau.nom}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              await db.deleteNiveau(niveau.id);
              await _loadData();
              _showSnackBar('Niveau supprimé avec succès', const Color(0xFF10B981));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  // ==================== GESTION DES MODULES ====================
  void _showAddModuleDialog(int niveauId, String niveauNom) {
    final codeController = TextEditingController();
    final nomController = TextEditingController();
    final creditsController = TextEditingController();
    final heuresCMController = TextEditingController();
    final heuresTDController = TextEditingController();
    final heuresTPController = TextEditingController();
    final coefficientController = TextEditingController();
    final semestreController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Ajouter un module à $niveauNom',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: InputDecoration(
                  labelText: 'Code du module *',
                  hintText: 'Ex: UE101, MATH201',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.code),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nomController,
                decoration: InputDecoration(
                  labelText: 'Nom du module *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.book),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: creditsController,
                      decoration: InputDecoration(
                        labelText: 'Crédits ECTS',
                        hintText: '6',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.star),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: coefficientController,
                      decoration: InputDecoration(
                        labelText: 'Coefficient',
                        hintText: '1',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.calculate),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: heuresCMController,
                      decoration: InputDecoration(
                        labelText: 'Heures CM',
                        hintText: '30',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.person),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: heuresTDController,
                      decoration: InputDecoration(
                        labelText: 'Heures TD',
                        hintText: '20',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.group),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: heuresTPController,
                      decoration: InputDecoration(
                        labelText: 'Heures TP',
                        hintText: '10',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.computer),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: semestreController,
                      decoration: InputDecoration(
                        labelText: 'Semestre',
                        hintText: 'S1, S2, S3...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.timeline),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (codeController.text.isEmpty || nomController.text.isEmpty) {
                _showSnackBar('Le code et le nom sont requis', const Color(0xFFF59E0B));
                return;
              }
              
              final newModule = ModuleModel(
                id: DateTime.now().millisecondsSinceEpoch,
                niveauId: niveauId,
                code: codeController.text,
                nom: nomController.text,
                creditsECTS: int.tryParse(creditsController.text) ?? 6,
                heuresCM: int.tryParse(heuresCMController.text) ?? 0,
                heuresTD: int.tryParse(heuresTDController.text) ?? 0,
                heuresTP: int.tryParse(heuresTPController.text) ?? 0,
                coefficient: double.tryParse(coefficientController.text) ?? 1.0,
                semestre: semestreController.text.isNotEmpty ? semestreController.text : 'S1',
                professeurId: 0, // À assigner plus tard
              );
              
              await db.addModule(newModule);
              await _loadData();
              _showSnackBar('Module ajouté avec succès', const Color(0xFF10B981));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _viewModules(NiveauModel niveau) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ModulesSheet(
        niveauId: niveau.id,
        niveauNom: niveau.nom,
        onModuleAdded: () => _loadData(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.departementNom,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
              style: IconButton.styleFrom(
                backgroundColor: Colors.grey[100],
              ),
              tooltip: 'Actualiser',
            ),
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
                // Statistiques
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF0F766E),
                        const Color(0xFF14B8A6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _statCard(Icons.school, "Niveaux", _niveaux.length, Colors.white),
                      _statCard(Icons.book, "Modules", 0, Colors.white),
                      _statCard(Icons.people, "Étudiants", 0, Colors.white),
                    ],
                  ),
                ),
                
                // En-tête avec bouton ajout
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.school, color: Color(0xFF10B981), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Niveaux d\'études',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF10B981),
                              const Color(0xFF059669),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _showAddNiveauDialog,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Ajouter'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Liste des niveaux
                Expanded(
                  child: _niveaux.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.school, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                'Aucun niveau',
                                style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ajoutez un niveau (Licence 1, Master 2...)',
                                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _showAddNiveauDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('Ajouter un niveau'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _niveaux.length,
                          itemBuilder: (context, index) {
                            final niveau = _niveaux[index];
                            return FadeTransition(
                              opacity: _animationController,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ExpansionTile(
                                  leading: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          const Color(0xFF0F766E),
                                          const Color(0xFF14B8A6),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Center(
                                      child: Text(
                                        niveau.ordre.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    niveau.nom,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        'Durée: ${niveau.duree} an(s)',
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                      ),
                                      if (niveau.description != null && niveau.description!.isNotEmpty)
                                        Text(
                                          niveau.description!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                        ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF3B82F6).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(Icons.book, color: Color(0xFF3B82F6), size: 20),
                                          onPressed: () => _viewModules(niveau),
                                          tooltip: 'Voir modules',
                                        ),
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF59E0B).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(Icons.add, color: Color(0xFFF59E0B), size: 20),
                                          onPressed: () => _showAddModuleDialog(niveau.id, niveau.nom),
                                          tooltip: 'Ajouter module',
                                        ),
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(Icons.delete, color: Color(0xFFEF4444), size: 20),
                                          onPressed: () => _deleteNiveau(niveau),
                                          tooltip: 'Supprimer',
                                        ),
                                      ),
                                    ],
                                  ),
                                  children: [
                                    // Aperçu des modules
                                    FutureBuilder<List<ModuleModel>>(
                                      future: db.getModulesByNiveau(niveau.id),
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                          return const Padding(
                                            padding: EdgeInsets.all(32),
                                            child: Center(
                                              child: Text(
                                                'Aucun module pour ce niveau',
                                                style: TextStyle(color: Colors.grey),
                                              ),
                                            ),
                                          );
                                        }
                                        return ListView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: snapshot.data!.length,
                                          itemBuilder: (context, i) {
                                            final module = snapshot.data![i];
                                            return Container(
                                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF3B82F6).withOpacity(0.05),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 40,
                                                    height: 40,
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        module.code,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                          color: Color(0xFF3B82F6),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          module.nom,
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.w600,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                        Text(
                                                          '${module.creditsECTS} crédits • ${module.semestre}',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors.grey[600],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF10B981).withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(20),
                                                    ),
                                                    child: Text(
                                                      'Coef: ${module.coefficient}',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Color(0xFF10B981),
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 8),
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

  Widget _statCard(IconData icon, String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
        ),
      ],
    );
  }
}

// ==================== FEUILLE DES MODULES ====================
class ModulesSheet extends StatefulWidget {
  final int niveauId;
  final String niveauNom;
  final VoidCallback onModuleAdded;

  const ModulesSheet({
    super.key,
    required this.niveauId,
    required this.niveauNom,
    required this.onModuleAdded,
  });

  @override
  _ModulesSheetState createState() => _ModulesSheetState();
}

class _ModulesSheetState extends State<ModulesSheet> {
  final DBHelper db = DBHelper();
  List<ModuleModel> _modules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadModules();
  }

  Future<void> _loadModules() async {
    setState(() => _isLoading = true);
    _modules = await db.getModulesByNiveau(widget.niveauId);
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.book, color: Color(0xFF3B82F6), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Modules - ${widget.niveauNom}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _modules.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.book, size: 48, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'Aucun module',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _modules.length,
                            itemBuilder: (context, index) {
                              final module = _modules[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6).withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF3B82F6),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            module.code,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            '${module.creditsECTS} ECTS',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF10B981),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      module.nom,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _infoChip(Icons.person, 'CM: ${module.heuresCM}h'),
                                        _infoChip(Icons.group, 'TD: ${module.heuresTD}h'),
                                        _infoChip(Icons.computer, 'TP: ${module.heuresTP}h'),
                                        _infoChip(Icons.calculate, 'Coef: ${module.coefficient}'),
                                        _infoChip(Icons.timeline, module.semestre),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
        ],
      ),
    );
  }
}