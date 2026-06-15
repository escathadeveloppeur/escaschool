// lib/screens/admin/admin_menu.dart

import 'package:flutter/material.dart';
import 'admin_dashboard.dart';
import 'admin_users.dart';
import 'admin_classes.dart';
import 'admin_announcements.dart';
import 'admin_logs.dart';
import 'admin_professors.dart';
import 'admin_messages_screen.dart';
import 'school_settings_screen.dart';

class _AppColors {
  static const Color menuBackground = Color(0xFF0F172A);
  static const Color menuSelected = Color(0xFF3B5BDB);
  static const Color background = Color(0xFFF4F6FB);
}

class AdminMenu extends StatefulWidget {
  const AdminMenu({super.key});

  @override
  State<AdminMenu> createState() => _AdminMenuState();
}

class _AdminMenuState extends State<AdminMenu> {
  int _selectedIndex = 0;

  final List<Map<String, dynamic>> _menuItems = [
    {'icon': Icons.dashboard_rounded, 'title': 'Dashboard', 'index': 0},
    {'icon': Icons.people_rounded, 'title': 'Utilisateurs', 'index': 1},
    {'icon': Icons.school_rounded, 'title': 'Professeurs', 'index': 2},
    {'icon': Icons.class_rounded, 'title': 'Classes', 'index': 3},
    {'icon': Icons.campaign_rounded, 'title': 'Annonces', 'index': 4},
    {'icon': Icons.message_rounded, 'title': 'Messages', 'index': 5},
    {'icon': Icons.settings_rounded, 'title': 'Paramètres', 'index': 6},
    {'icon': Icons.history_rounded, 'title': 'Logs', 'index': 7},
  ];

  Widget _getScreen() {
    switch (_selectedIndex) {
      case 0:
        return const AdminDashboard();
      case 1:
        return AdminUsers(onChanged: () {});
      case 2:
        return AdminProfessors(onChanged: () {});
      case 3:
        return AdminClasses(onChanged: () {});
      case 4:
        return const AdminAnnouncements();
      case 5:
        return const AdminMessagesScreen();
      case 6:
        return const SchoolSettingsScreen();
      case 7:
        return const AdminLogs();
      default:
        return const AdminDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Menu latéral
          Container(
            width: 200,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_AppColors.menuBackground, Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomLeft,
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 30),
                _buildLogo(),
                const SizedBox(height: 20),
                ..._menuItems.map((item) => _buildMenuItem(item)),
                const Spacer(),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  height: 1,
                  color: Colors.white.withOpacity(0.1),
                ),
                const SizedBox(height: 10),
                _buildLogoutButton(),
                const SizedBox(height: 16),
              ],
            ),
          ),
          // Contenu
          Expanded(
            child: Container(
              color: _AppColors.background,
              child: _getScreen(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "ADMIN",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              Text(
                "Gestion",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(Map<String, dynamic> item) {
    final isSelected = _selectedIndex == item['index'];
    final iconColor = isSelected ? Colors.white : Colors.white60;
    final textColor = isSelected ? Colors.white : Colors.white60;
    final fontWeight = isSelected ? FontWeight.w600 : FontWeight.w400;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: isSelected
            ? LinearGradient(
                colors: [_AppColors.menuSelected, _AppColors.menuSelected.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() {
              _selectedIndex = item['index'];
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              children: [
                Icon(item['icon'], color: iconColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item['title'],
                    style: TextStyle(
                      color: textColor,
                      fontSize: 11,
                      fontWeight: fontWeight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFFEF4444).withOpacity(0.1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => Navigator.pushReplacementNamed(context, "/login"),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: const Row(
              children: [
                Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Déconnexion",
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}