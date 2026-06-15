// lib/screens/super_admin/dialogs/add_school_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/db_helper.dart';
import '../../../services/school_service.dart';
import '../../../models/university/etablissement_model.dart';
import '../../../providers/auth_provider.dart';

class AddSchoolDialog extends StatefulWidget {
  final VoidCallback onSchoolAdded;

  const AddSchoolDialog({super.key, required this.onSchoolAdded});

  @override
  _AddSchoolDialogState createState() => _AddSchoolDialogState();
}

class _AddSchoolDialogState extends State<AddSchoolDialog> {
  final DBHelper db = DBHelper();
  final SchoolService _schoolService = SchoolService();
  final _formKey = GlobalKey<FormState>();

  // Contrôleurs pour les champs
  final _nomController = TextEditingController();
  final _typeController = TextEditingController();
  final _adresseController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _siteWebController = TextEditingController();
  
  // NOUVEAUX CHAMPS
  final _codePostalController = TextEditingController();
  final _villeController = TextEditingController();
  final _communeController = TextEditingController();
  final _provinceController = TextEditingController();
  final _paysController = TextEditingController();
  final _directeurNomController = TextEditingController();
  final _directeurEmailController = TextEditingController();
  final _directeurTelephoneController = TextEditingController();
  final _anneeCreationController = TextEditingController();
  final _capaciteController = TextEditingController();
  final _langueEnseignementController = TextEditingController();
  
  // Dropdown selections
  String? _selectedPays;
  String? _selectedProvince;
  String? _selectedTypeEcole;
  String? _selectedStatut;
  String? _selectedLangue;
  
  bool _isLoading = false;

  // Listes pour les dropdowns
  final List<String> _paysList = [
    'République Démocratique du Congo',
    'Congo-Brazzaville',
    'France',
    'Belgique',
    'Canada',
    'Suisse',
    'Sénégal',
    'Côte d\'Ivoire',
    'Cameroun',
    'Maroc',
    'Tunisie',
    'Algérie',
    'Autre'
  ];
  
  final List<String> _provincesRDC = [
    'Kinshasa',
    'Kongo Central',
    'Kwilu',
    'Kwango',
    'Mai-Ndombe',
    'Équateur',
    'Tshuapa',
    'Mongala',
    'Nord-Ubangi',
    'Sud-Ubangi',
    'Bas-Uélé',
    'Haut-Uélé',
    'Ituri',
    'Tshopo',
    'Nord-Kivu',
    'Sud-Kivu',
    'Maniema',
    'Tanganyika',
    'Haut-Lomami',
    'Lualaba',
    'Haut-Katanga',
    'Lomami',
    'Sankuru',
    'Kasaï',
    'Kasaï-Central',
    'Kasaï-Oriental'
  ];
  
  final List<String> _typeEcoleList = [
    'École maternelle',
    'École primaire',
    'École secondaire',
    'Complexe scolaire (maternel+primaire+secondaire)',
    'Lycée',
    'Collège',
    'Institut technique',
    'Université',
    'Centre de formation professionnelle',
    'Autre'
  ];
  
  final List<String> _statutList = [
    'Public',
    'Privé laïc',
    'Privé confessionnel',
    'Conventionné catholique',
    'Conventionné protestant',
    'Conventionné kimbanguiste',
    'Communautaire',
    'International'
  ];
  
  final List<String> _langueList = [
    'Français',
    'Anglais',
    'Français et Anglais',
    'Français et Lingala',
    'Français et Swahili',
    'Français et Tshiluba',
    'Français et Kikongo',
    'Autre'
  ];

  @override
  void dispose() {
    _nomController.dispose();
    _typeController.dispose();
    _adresseController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    _siteWebController.dispose();
    _codePostalController.dispose();
    _villeController.dispose();
    _communeController.dispose();
    _provinceController.dispose();
    _paysController.dispose();
    _directeurNomController.dispose();
    _directeurEmailController.dispose();
    _directeurTelephoneController.dispose();
    _anneeCreationController.dispose();
    _capaciteController.dispose();
    _langueEnseignementController.dispose();
    super.dispose();
  }

  Future<void> _saveSchool() async {
    if (!_formKey.currentState!.validate()) return;
    if (_nomController.text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      
      // Construire l'adresse complète
      String adresseComplete = _adresseController.text;
      if (_villeController.text.isNotEmpty) {
        adresseComplete += ', ${_villeController.text}';
      }
      if (_communeController.text.isNotEmpty) {
        adresseComplete += ', ${_communeController.text}';
      }
      if (_provinceController.text.isNotEmpty) {
        adresseComplete += ', ${_provinceController.text}';
      }
      if (_codePostalController.text.isNotEmpty) {
        adresseComplete += ' (${_codePostalController.text})';
      }
      if (_selectedPays != null && _selectedPays!.isNotEmpty) {
        adresseComplete += ', ${_selectedPays!}';
      }
      
      // Créer l'école avec toutes les informations
      final newSchool = EtablissementModel(
        id: 0,
        nom: _nomController.text,
        type: _selectedTypeEcole ?? _typeController.text,
        adresse: adresseComplete,
        telephone: _telephoneController.text,
        email: _emailController.text,
        siteWeb: _siteWebController.text,
        createdAt: DateTime.now(),
        isActive: true,
        schoolCode: EtablissementModel.generateSchoolCode(_nomController.text),
        
        // NOUVEAUX CHAMPS
        pays: _selectedPays,
        province: _provinceController.text.isNotEmpty ? _provinceController.text : _selectedProvince,
        ville: _villeController.text,
        commune: _communeController.text,
        codePostal: _codePostalController.text,
        statut: _selectedStatut,
        directeurNom: _directeurNomController.text,
        directeurEmail: _directeurEmailController.text,
        directeurTelephone: _directeurTelephoneController.text,
        anneeCreation: _anneeCreationController.text.isNotEmpty ? int.tryParse(_anneeCreationController.text) : null,
        capacite: _capaciteController.text.isNotEmpty ? int.tryParse(_capaciteController.text) : null,
        langueEnseignement: _selectedLangue ?? _langueEnseignementController.text,
      );

      print('📝 Création de l\'école: ${newSchool.nom}');
      print('📍 Pays: ${newSchool.pays}');
      print('📍 Province: ${newSchool.province}');
      
      final localId = await db.addEtablissement(newSchool);
      print('✅ École créée localement avec ID: $localId');
      
      // Synchroniser dans Firebase
      if (auth.isFirebaseConnected) {
        print('☁️ Synchronisation vers Firebase...');
        final firestoreId = await _schoolService.createSchool(newSchool);
        print('✅ École synchronisée dans Firestore');
        await db.updateEtablissementFirestoreId(localId, firestoreId);
      }
      
      await db.addLog("Super Admin a ajouté l'école: ${newSchool.nom} (${newSchool.pays})");
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('École ajoutée avec succès'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onSchoolAdded();
        Navigator.pop(context);
      }
    } catch (e) {
      print('❌ Erreur: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.business, color: Color(0xFF10B981)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Ajouter une école',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SECTION 1: INFORMATIONS GÉNÉRALES
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info, size: 20, color: Colors.blue),
                                const SizedBox(width: 8),
                                const Text(
                                  'Informations générales',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _nomController,
                              decoration: const InputDecoration(
                                labelText: 'Nom de l\'école *',
                                prefixIcon: Icon(Icons.business),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(12)),
                                ),
                              ),
                              validator: (v) => v == null || v.isEmpty ? 'Nom requis' : null,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _selectedTypeEcole,
                              decoration: const InputDecoration(
                                labelText: 'Type d\'établissement *',
                                prefixIcon: Icon(Icons.category),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(12)),
                                ),
                              ),
                              items: _typeEcoleList.map((type) {
                                return DropdownMenuItem(value: type, child: Text(type));
                              }).toList(),
                              onChanged: (value) => setState(() => _selectedTypeEcole = value),
                              validator: (v) => v == null ? 'Type requis' : null,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _selectedStatut,
                              decoration: const InputDecoration(
                                labelText: 'Statut',
                                prefixIcon: Icon(Icons.verified),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(12)),
                                ),
                              ),
                              items: _statutList.map((statut) {
                                return DropdownMenuItem(value: statut, child: Text(statut));
                              }).toList(),
                              onChanged: (value) => setState(() => _selectedStatut = value),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _anneeCreationController,
                              decoration: const InputDecoration(
                                labelText: 'Année de création',
                                prefixIcon: Icon(Icons.calendar_today),
                                hintText: 'Ex: 2000',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(12)),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _capaciteController,
                              decoration: const InputDecoration(
                                labelText: 'Capacité (nombre d\'élèves)',
                                prefixIcon: Icon(Icons.people),
                                hintText: 'Ex: 1500',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(12)),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // SECTION 2: LOCALISATION
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 20, color: Colors.green),
                                const SizedBox(width: 8),
                                const Text(
                                  'Localisation',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _selectedPays,
                              decoration: const InputDecoration(
                                labelText: 'Pays *',
                                prefixIcon: Icon(Icons.public),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(12)),
                                ),
                              ),
                              items: _paysList.map((pays) {
                                return DropdownMenuItem(value: pays, child: Text(pays));
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedPays = value;
                                  if (value != 'République Démocratique du Congo') {
                                    _selectedProvince = null;
                                    _provinceController.clear();
                                  }
                                });
                              },
                              validator: (v) => v == null ? 'Pays requis' : null,
                            ),
                            const SizedBox(height: 12),
                            
                            // Province - conditionnel selon le pays
                            if (_selectedPays == 'République Démocratique du Congo')
                              DropdownButtonFormField<String>(
                                value: _selectedProvince,
                                decoration: const InputDecoration(
                                  labelText: 'Province *',
                                  prefixIcon: Icon(Icons.map),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(12)),
                                  ),
                                ),
                                items: _provincesRDC.map((province) {
                                  return DropdownMenuItem(value: province, child: Text(province));
                                }).toList(),
                                onChanged: (value) => setState(() => _selectedProvince = value),
                                validator: (v) => v == null ? 'Province requise' : null,
                              )
                            else
                              TextFormField(
                                controller: _provinceController,
                                decoration: const InputDecoration(
                                  labelText: 'État / Province / Région',
                                  prefixIcon: Icon(Icons.map),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(12)),
                                  ),
                                ),
                              ),
                              
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _villeController,
                              decoration: const InputDecoration(
                                labelText: 'Ville *',
                                prefixIcon: Icon(Icons.location_city),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(12)),
                                ),
                              ),
                              validator: (v) => v == null || v.isEmpty ? 'Ville requise' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _communeController,
                              decoration: const InputDecoration(
                                labelText: 'Commune / Arrondissement',
                                prefixIcon: Icon(Icons.grid_on),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _adresseController,
                              decoration: const InputDecoration(
                                labelText: 'Adresse complète',
                                prefixIcon: Icon(Icons.home),
                                hintText: 'Numéro, rue, quartier',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _codePostalController,
                              decoration: const InputDecoration(
                                labelText: 'Code postal',
                                prefixIcon: Icon(Icons.local_post_office),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(12)),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // SECTION 3: CONTACT
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.contact_phone, size: 20, color: Colors.orange),
                                const SizedBox(width: 8),
                                const Text(
                                  'Contact',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _telephoneController,
                              decoration: const InputDecoration(
                                labelText: 'Téléphone *',
                                prefixIcon: Icon(Icons.phone),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(12)),
                                ),
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (v) => v == null || v.isEmpty ? 'Téléphone requis' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email *',
                                prefixIcon: Icon(Icons.email),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(12)),
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => v == null || !v.contains('@') ? 'Email valide requis' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _siteWebController,
                              decoration: const InputDecoration(
                                labelText: 'Site web',
                                prefixIcon: Icon(Icons.language),
                                hintText: 'https://...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // SECTION 4: DIRECTION
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person, size: 20, color: Colors.purple),
                                const SizedBox(width: 8),
                                const Text(
                                  'Direction',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _directeurNomController,
                              decoration: const InputDecoration(
                                labelText: 'Nom du Directeur',
                                prefixIcon: Icon(Icons.person),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _directeurEmailController,
                              decoration: const InputDecoration(
                                labelText: 'Email du Directeur',
                                prefixIcon: Icon(Icons.email),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(12)),
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _directeurTelephoneController,
                              decoration: const InputDecoration(
                                labelText: 'Téléphone du Directeur',
                                prefixIcon: Icon(Icons.phone),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(12)),
                                ),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // SECTION 5: PÉDAGOGIE
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.school, size: 20, color: Colors.teal),
                                const SizedBox(width: 8),
                                const Text(
                                  'Pédagogie',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _selectedLangue,
                              decoration: const InputDecoration(
                                labelText: 'Langue d\'enseignement',
                                prefixIcon: Icon(Icons.language),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(12)),
                                ),
                              ),
                              items: _langueList.map((langue) {
                                return DropdownMenuItem(value: langue, child: Text(langue));
                              }).toList(),
                              onChanged: (value) => setState(() => _selectedLangue = value),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveSchool,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Ajouter l\'école'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}