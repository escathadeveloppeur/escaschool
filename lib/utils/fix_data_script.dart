import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:flutter/material.dart';

Future<void> fixExistingData(BuildContext context) async {
  final auth = Provider.of<AuthProvider>(context, listen: false);
  final currentSchoolId = auth.currentSchoolId;
  
  if (currentSchoolId == null) {
    print('⚠️ currentSchoolId est null, impossible de corriger');
    return;
  }
  
  print('🔧 Correction des données existantes avec schoolId: $currentSchoolId');
  
  // Mettre à jour les classes
  final classesSnapshot = await FirebaseFirestore.instance
      .collection('classes')
      .get();
  
  for (var doc in classesSnapshot.docs) {
    final data = doc.data();
    if (data['schoolId'] == null || data['schoolId'] == 0) {
      await doc.reference.update({'schoolId': currentSchoolId});
      print('✅ Classe mise à jour: ${data['className']}');
    }
  }
  
  // Mettre à jour les sections
  final sectionsSnapshot = await FirebaseFirestore.instance
      .collection('sections')
      .get();
  
  for (var doc in sectionsSnapshot.docs) {
    final data = doc.data();
    if (data['schoolId'] == null || data['schoolId'] == 0) {
      await doc.reference.update({'schoolId': currentSchoolId});
      print('✅ Section mise à jour: ${data['name']}');
    }
  }
  
  // Mettre à jour les étudiants
  final studentsSnapshot = await FirebaseFirestore.instance
      .collection('students')
      .get();
  
  for (var doc in studentsSnapshot.docs) {
    final data = doc.data();
    if (data['schoolId'] == null || data['schoolId'] == 0) {
      await doc.reference.update({'schoolId': currentSchoolId});
      print('✅ Étudiant mis à jour: ${data['fullName']}');
    }
  }
  
  print('✅ Correction terminée !');
}
