import 'package:flutter/material.dart';
import 'admin_dashboard.dart';
import 'admin_users.dart';
import 'admin_classes.dart';
import 'admin_announcements.dart';
import 'admin_logs.dart';

class AdminMenu extends StatefulWidget {
  const AdminMenu({super.key});

  @override
  _AdminMenuState createState() => _AdminMenuState();
}

class _AdminMenuState extends State<AdminMenu> {
  void _loadDashboardData() {
    setState(() {}); // rafraîchit l'état si besoin
  }

  int selectedIndex = 0;

  // ⚡ On initialise screens dans build()
  List<Widget> get screens => [
        AdminDashboard(),
        AdminUsers(),
         AdminClasses(onChanged: _loadDashboardData), 
        AdminAnnouncements(),
        AdminLogs(),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // 📌 Menu à gauche
          Container(
            width: 230,
            color: Colors.blueGrey[900],
            child: Column(
              children: [
                SizedBox(height: 40),
                Text("ADMIN PANEL",
                    style: TextStyle(color: Colors.white, fontSize: 20)),
                SizedBox(height: 30),
                menuItem(Icons.dashboard, "Dashboard", 0),
                menuItem(Icons.people, "Utilisateurs", 1),
                menuItem(Icons.class_, "Classes", 2),
                menuItem(Icons.campaign, "Annonces", 3),
                menuItem(Icons.history, "Logs", 4),
                Spacer(),
                Divider(color: Colors.white24),
                menuItem(Icons.logout, "Déconnexion", 100),
                SizedBox(height: 20),
              ],
            ),
          ),

          // 📌 Contenu à droite
          Expanded(child: screens[selectedIndex]),
        ],
      ),
    );
  }

  Widget menuItem(IconData icon, String title, int index) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: TextStyle(color: Colors.white)),
      selected: index == selectedIndex,
      onTap: () {
        if (index == 100) {
          Navigator.pushReplacementNamed(context, "/login");
          return;
        }
        setState(() => selectedIndex = index);
      },
    );
  }
}
