import 'package:flutter/material.dart';
import '/models/user.dart';
import '../../services/db_helper.dart';


class AddUserScreen extends StatefulWidget {
  const AddUserScreen({super.key});

  @override
  _AddUserScreenState createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String role = 'student';

  final DBHelper db = DBHelper();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ajouter un utilisateur')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Nom'),
                validator: (value) => value!.isEmpty ? 'Obligatoire' : null,
              ),
              TextFormField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'Email'),
                validator: (value) => value!.isEmpty ? 'Obligatoire' : null,
              ),
              TextFormField(
                controller: passwordController,
                decoration: InputDecoration(labelText: 'Mot de passe'),
                validator: (value) => value!.isEmpty ? 'Obligatoire' : null,
              ),
              DropdownButtonFormField<String>(
                initialValue: role,
                items: [
                  DropdownMenuItem(value: 'student', child: Text('Étudiant')),
                  DropdownMenuItem(value: 'teacher', child: Text('Enseignant')),
                  DropdownMenuItem(value: 'parent', child: Text('Parent')),
                  DropdownMenuItem(value: 'staff', child: Text('Personnel')),
                  DropdownMenuItem(value: 'admin', child: Text('Administrateur')),
                  DropdownMenuItem(value: 'super_admin', child: Text('Super Admin')),
                ],
                onChanged: (value) {
                  setState(() {
                    role = value!;
                  });
                },
                decoration: InputDecoration(labelText: 'Rôle'),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    await db.insertUser({
                      'name': nameController.text,
                      'email': emailController.text,
                      'password': passwordController.text,
                      'role': role,
                    });
                    Navigator.pop(context);
                  }
                },
                child: Text('Ajouter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
