// lib/screens/admin/generate_qr_codes.dart

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/db_helper.dart';
import '../../services/qr_service.dart';
import '../../models/student_model.dart';

class GenerateQRCodesScreen extends StatefulWidget {
  const GenerateQRCodesScreen({super.key});

  @override
  _GenerateQRCodesScreenState createState() => _GenerateQRCodesScreenState();
}

class _GenerateQRCodesScreenState extends State<GenerateQRCodesScreen> {
  final DBHelper db = DBHelper();
  List<StudentModel> students = [];
  List<StudentModel> filteredStudents = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedClass = 'Toutes';

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    students = await db.getAllStudents();
    _filterStudents();
    setState(() => _isLoading = false);
  }

  void _filterStudents() {
    setState(() {
      filteredStudents = students.where((s) {
        final matchesSearch = _searchQuery.isEmpty ||
            s.fullName.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesClass = _selectedClass == 'Toutes' ||
            s.className == _selectedClass;
        return matchesSearch && matchesClass;
      }).toList();
    });
  }

  List<String> get _uniqueClasses {
    final classes = students.map((s) => s.className).toSet().toList();
    classes.sort();
    classes.insert(0, 'Toutes');
    return classes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Générer QR Codes'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadStudents,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filtres
                Container(
                  padding: EdgeInsets.all(16),
                  color: Colors.blue[50],
                  child: Column(
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Rechercher un élève...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (value) {
                          _searchQuery = value;
                          _filterStudents();
                        },
                      ),
                      SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedClass,
                        items: _uniqueClasses.map((classe) {
                          return DropdownMenuItem(
                            value: classe,
                            child: Text(classe),
                          );
                        }).toList(),
                        onChanged: (value) {
                          _selectedClass = value!;
                          _filterStudents();
                        },
                        decoration: InputDecoration(
                          labelText: 'Classe',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Statistiques
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.info, size: 16, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        '${filteredStudents.length} élève(s)',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                
                // Liste des QR codes
                Expanded(
                  child: filteredStudents.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'Aucun élève trouvé',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.all(8),
                          itemCount: filteredStudents.length,
                          itemBuilder: (context, index) {
                            final student = filteredStudents[index];
                            final qrData = QRService.generateStudentQR(student);
                            
                            return Card(
                              margin: EdgeInsets.only(bottom: 8),
                              child: ExpansionTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue,
                                  child: Text(
                                    student.fullName[0].toUpperCase(),
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(
                                  student.fullName,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text('Classe: ${student.className}'),
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        QrImageView(
                                          data: qrData,
                                          version: QrVersions.auto,
                                          size: 200.0,
                                          gapless: false,
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'QR Code - ${student.fullName}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            ElevatedButton.icon(
                                              onPressed: () {
                                                _showFullScreenQR(context, qrData, student.fullName);
                                              },
                                              icon: Icon(Icons.fullscreen),
                                              label: Text('Agrandir'),
                                            ),
                                            SizedBox(width: 8),
                                            OutlinedButton.icon(
                                              onPressed: () {
                                                _shareQRCode(qrData, student.fullName);
                                              },
                                              icon: Icon(Icons.share),
                                              label: Text('Partager'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
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
  }

  void _showFullScreenQR(BuildContext context, String qrData, String studentName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        child: Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                studentName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 250.0,
                gapless: false,
              ),
              SizedBox(height: 16),
              Text(
                'Scannez ce QR code pour valider la présence',
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Fermer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _shareQRCode(String qrData, String studentName) {
    // Implémenter le partage
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('QR code prêt à être partagé'),
        backgroundColor: Colors.green,
      ),
    );
  }
}