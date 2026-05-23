// lib/screens/admin/admin_messages_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';

class AdminMessagesScreen extends StatefulWidget {
  const AdminMessagesScreen({super.key});

  @override
  _AdminMessagesScreenState createState() => _AdminMessagesScreenState();
}

class _AdminMessagesScreenState extends State<AdminMessagesScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? adminInfo;
  List<Map<String, dynamic>> conversations = [];
  Map<String, Map<String, dynamic>> conversationMap = {};
  
  List<Map<String, dynamic>> teachers = [];
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> parents = [];
  List<Map<String, dynamic>> staffs = [];
  
  bool _isLoading = true;
  bool _isSending = false;
  Map<String, dynamic>? _selectedConversation;
  
  final TextEditingController _contentController = TextEditingController();
  
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
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final adminFirestoreId = auth.user?.firestoreId;
      final adminName = auth.user?.name ?? auth.user?.email ?? 'Administrateur';
      final schoolId = auth.currentSchoolId;
      
      print('\n╔════════════════════════════════════════════════════════════╗');
      print('║     CHARGEMENT ADMIN MESSAGES                              ║');
      print('╚════════════════════════════════════════════════════════════╝\n');
      print('📌 ADMIN FIRESTORE ID: $adminFirestoreId');
      print('📌 ADMIN NAME: $adminName');
      print('📌 SCHOOL ID: $schoolId');
      
      adminInfo = {
        'id': adminFirestoreId,
        'name': adminName,
        'role': 'admin',
      };
      
      await _loadTeachers(schoolId.toString());
      await _loadStudents(schoolId.toString());
      await _loadParents(schoolId.toString());
      await _loadStaffs(schoolId.toString());
      await _loadConversations(adminFirestoreId);
      
      _animationController.forward();
    } catch (e) {
      print('❌ Erreur: $e');
      _showSnackBar('Erreur de chargement', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _loadTeachers(String? schoolId) async {
    print('\n🔍 CHARGEMENT DES PROFESSEURS');
    Query query = FirebaseFirestore.instance.collection('professors');
    if (schoolId != null) {
      query = query.where('schoolId', isEqualTo: int.tryParse(schoolId) ?? 0);
      print('   Filtre schoolId = $schoolId');
    }
    final snapshot = await query.get();
    
    teachers = [];
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      teachers.add({
        'id': doc.id,
        'name': data['fullName'] ?? 'Professeur',
        'specialty': data['specialty'] ?? '',
      });
      print('   - ${data['fullName']} (ID: ${doc.id})');
    }
    print('   ✅ ${teachers.length} professeur(s)');
  }
  
  Future<void> _loadStudents(String? schoolId) async {
    print('\n🔍 CHARGEMENT DES ÉLÈVES');
    Query query = FirebaseFirestore.instance.collection('students');
    if (schoolId != null) {
      query = query.where('schoolId', isEqualTo: int.tryParse(schoolId) ?? 0);
      print('   Filtre schoolId = $schoolId');
    }
    final snapshot = await query.get();
    
    students = [];
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      students.add({
        'id': doc.id,
        'name': data['fullName'] ?? 'Élève',
        'className': data['className'] ?? '',
      });
      print('   - ${data['fullName']} (ID: ${doc.id})');
    }
    print('   ✅ ${students.length} élève(s)');
  }
  
  Future<void> _loadParents(String? schoolId) async {
    print('\n🔍 CHARGEMENT DES PARENTS');
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'parent')
        .get();
    
    parents = [];
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      parents.add({
        'id': doc.id,
        'name': data['name'] ?? data['email'] ?? 'Parent',
      });
      print('   - ${data['name'] ?? data['email']} (ID: ${doc.id})');
    }
    print('   ✅ ${parents.length} parent(s)');
  }
  
  Future<void> _loadStaffs(String? schoolId) async {
    print('\n🔍 CHARGEMENT DU STAFF');
    final snapshot = await FirebaseFirestore.instance
        .collection('staff')
        .get();
    
    staffs = [];
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      staffs.add({
        'id': doc.id,
        'name': data['fullName'] ?? data['name'] ?? 'Personnel',
        'role': data['role'] ?? '',
      });
      print('   - ${data['fullName'] ?? data['name']} (ID: ${doc.id})');
    }
    print('   ✅ ${staffs.length} personnel(s)');
  }
  
  Future<void> _loadConversations(String? adminFirestoreId) async {
    if (adminFirestoreId == null) return;
    
    print('\n🔍 CHARGEMENT DES CONVERSATIONS');
    print('   🔑 Utilisation de adminFirestoreId: $adminFirestoreId');
    
    final receivedSnapshot = await FirebaseFirestore.instance
        .collection('messages')
        .where('recipientRole', isEqualTo: 'admin')
        .where('recipientId', isEqualTo: adminFirestoreId)
        .get();
    
    final sentSnapshot = await FirebaseFirestore.instance
        .collection('messages')
        .where('senderRole', isEqualTo: 'admin')
        .where('senderId', isEqualTo: adminFirestoreId)
        .get();
    
    print('   📥 Messages reçus: ${receivedSnapshot.docs.length}');
    print('   📤 Messages envoyés: ${sentSnapshot.docs.length}');
    
    conversationMap = {};
    
    // Traiter les messages reçus
    for (var doc in receivedSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final senderId = data['senderId'] ?? '';
      final senderName = data['senderName'] ?? 'Inconnu';
      final senderRole = data['senderRole'] ?? 'unknown';
      final conversationId = '${senderRole}_$senderId';
      
      if (!conversationMap.containsKey(conversationId)) {
        conversationMap[conversationId] = {
          'id': conversationId,
          'name': senderName,
          'role': senderRole,
          'contactId': senderId,
          'lastMessage': data['content'] ?? '',
          'lastDate': data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
          'unreadCount': data['read'] == false ? 1 : 0,
        };
        print('   📁 Nouvelle conversation: $senderName ($senderRole)');
      } else {
        final existing = conversationMap[conversationId]!;
        final msgDate = data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now();
        if (msgDate.isAfter(existing['lastDate'])) {
          existing['lastMessage'] = data['content'] ?? '';
          existing['lastDate'] = msgDate;
        }
        if (data['read'] == false) {
          existing['unreadCount'] = (existing['unreadCount'] as int) + 1;
        }
      }
    }
    
    // Traiter les messages envoyés
    for (var doc in sentSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final recipientId = data['recipientId'] ?? '';
      final recipientName = data['recipientName'] ?? 'Destinataire';
      final recipientRole = data['recipientRole'] ?? 'unknown';
      final conversationId = '${recipientRole}_$recipientId';
      
      if (!conversationMap.containsKey(conversationId)) {
        conversationMap[conversationId] = {
          'id': conversationId,
          'name': recipientName,
          'role': recipientRole,
          'contactId': recipientId,
          'lastMessage': data['content'] ?? '',
          'lastDate': data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
          'unreadCount': 0,
        };
        print('   📁 Nouvelle conversation (envoi): $recipientName ($recipientRole)');
      } else {
        final existing = conversationMap[conversationId]!;
        final msgDate = data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now();
        if (msgDate.isAfter(existing['lastDate'])) {
          existing['lastMessage'] = data['content'] ?? '';
          existing['lastDate'] = msgDate;
        }
      }
    }
    
    conversations = conversationMap.values.toList();
    conversations.sort((a, b) => b['lastDate'].compareTo(a['lastDate']));
    
    print('   ✅ ${conversations.length} conversation(s) chargée(s)\n');
  }
  
  Future<void> _markMessagesAsRead(String contactId, String adminFirestoreId) async {
    final unreadMessages = await FirebaseFirestore.instance
        .collection('messages')
        .where('recipientId', isEqualTo: adminFirestoreId)
        .where('senderId', isEqualTo: contactId)
        .where('read', isEqualTo: false)
        .get();
    
    for (var doc in unreadMessages.docs) {
      await doc.reference.update({'read': true, 'readAt': FieldValue.serverTimestamp()});
    }
    
    await _loadConversations(adminFirestoreId);
  }
  
  Future<void> _sendMessage(String? adminFirestoreId, String adminName) async {
    final content = _contentController.text.trim();
    
    if (content.isEmpty || _selectedConversation == null || adminFirestoreId == null) {
      _showSnackBar('Veuillez écrire un message', Colors.orange);
      return;
    }
    
    setState(() => _isSending = true);
    
    try {
      final messageData = {
        'senderId': adminFirestoreId,
        'senderName': adminName,
        'senderRole': 'admin',
        'recipientId': _selectedConversation!['contactId'],
        'recipientName': _selectedConversation!['name'],
        'recipientRole': _selectedConversation!['role'],
        'subject': 'Message',
        'content': content,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      await FirebaseFirestore.instance.collection('messages').add(messageData);
      
      _contentController.clear();
      await _loadConversations(adminFirestoreId);
      
      _showSnackBar('Message envoyé', Colors.green);
      
    } catch (e) {
      _showSnackBar('Erreur: $e', Colors.red);
    } finally {
      setState(() => _isSending = false);
    }
  }
  
  void _showNewConversationDialog(String adminFirestoreId, String adminName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateBottomSheet) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  _buildDragHandle(),
                  const SizedBox(height: 16),
                  _buildDialogHeader('Nouveau message', Icons.edit),
                  const SizedBox(height: 16),
                  
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section Professeurs
                          if (teachers.isNotEmpty) ...[
                            const Text(
                              'PROFESSEURS',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blue),
                            ),
                            const SizedBox(height: 8),
                            ...teachers.map((teacher) => _buildContactTile(
                              name: teacher['name'],
                              role: 'teacher',
                              subtitle: teacher['specialty'],
                              icon: Icons.school,
                              color: Colors.blue,
                              onTap: () {
                                setState(() {
                                  _selectedConversation = {
                                    'name': teacher['name'],
                                    'role': 'teacher',
                                    'contactId': teacher['id'],
                                  };
                                });
                                Navigator.pop(context);
                                _showConversationDetail(adminFirestoreId, adminName);
                              },
                            )).toList(),
                            const SizedBox(height: 16),
                          ],
                          
                          // Section Élèves
                          if (students.isNotEmpty) ...[
                            const Text(
                              'ÉLÈVES',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.green),
                            ),
                            const SizedBox(height: 8),
                            ...students.map((student) => _buildContactTile(
                              name: student['name'],
                              role: 'student',
                              subtitle: student['className'],
                              icon: Icons.child_care,
                              color: Colors.green,
                              onTap: () {
                                setState(() {
                                  _selectedConversation = {
                                    'name': student['name'],
                                    'role': 'student',
                                    'contactId': student['id'],
                                  };
                                });
                                Navigator.pop(context);
                                _showConversationDetail(adminFirestoreId, adminName);
                              },
                            )).toList(),
                            const SizedBox(height: 16),
                          ],
                          
                          // Section Parents
                          if (parents.isNotEmpty) ...[
                            const Text(
                              'PARENTS',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.orange),
                            ),
                            const SizedBox(height: 8),
                            ...parents.map((parent) => _buildContactTile(
                              name: parent['name'],
                              role: 'parent',
                              subtitle: '',
                              icon: Icons.family_restroom,
                              color: Colors.orange,
                              onTap: () {
                                setState(() {
                                  _selectedConversation = {
                                    'name': parent['name'],
                                    'role': 'parent',
                                    'contactId': parent['id'],
                                  };
                                });
                                Navigator.pop(context);
                                _showConversationDetail(adminFirestoreId, adminName);
                              },
                            )).toList(),
                            const SizedBox(height: 16),
                          ],
                          
                          // Section Personnel
                          if (staffs.isNotEmpty) ...[
                            const Text(
                              'PERSONNEL',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.purple),
                            ),
                            const SizedBox(height: 8),
                            ...staffs.map((staff) => _buildContactTile(
                              name: staff['name'],
                              role: 'staff',
                              subtitle: staff['role'],
                              icon: Icons.person,
                              color: Colors.purple,
                              onTap: () {
                                setState(() {
                                  _selectedConversation = {
                                    'name': staff['name'],
                                    'role': 'staff',
                                    'contactId': staff['id'],
                                  };
                                });
                                Navigator.pop(context);
                                _showConversationDetail(adminFirestoreId, adminName);
                              },
                            )).toList(),
                          ],
                          
                          if (teachers.isEmpty && students.isEmpty && parents.isEmpty && staffs.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(Icons.person_off, size: 48, color: Colors.grey[400]),
                                  const SizedBox(height: 8),
                                  Text('Aucun contact disponible', style: TextStyle(color: Colors.grey[500])),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildContactTile({
    required String name,
    required String role,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isSelected ? Border.all(color: color, width: 1) : null,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: subtitle.isNotEmpty 
            ? Text(subtitle, style: const TextStyle(fontSize: 12))
            : null,
        trailing: isSelected 
            ? Icon(Icons.check_circle, color: color, size: 18)
            : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
  
  void _showConversationDetail(String adminFirestoreId, String adminName) async {
    if (_selectedConversation == null) return;
    
    await _markMessagesAsRead(_selectedConversation!['contactId'], adminFirestoreId);
    
    List<Map<String, dynamic>> messages = [];
    
    final receivedSnapshot = await FirebaseFirestore.instance
        .collection('messages')
        .where('recipientId', isEqualTo: adminFirestoreId)
        .where('senderId', isEqualTo: _selectedConversation!['contactId'])
        .get();
    
    final sentSnapshot = await FirebaseFirestore.instance
        .collection('messages')
        .where('senderId', isEqualTo: adminFirestoreId)
        .where('recipientId', isEqualTo: _selectedConversation!['contactId'])
        .get();
    
    for (var doc in receivedSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      messages.add({
        'id': doc.id,
        'text': data['content'] ?? '',
        'isMe': false,
        'date': data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
      });
    }
    
    for (var doc in sentSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      messages.add({
        'id': doc.id,
        'text': data['content'] ?? '',
        'isMe': true,
        'date': data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
      });
    }
    
    messages.sort((a, b) => a['date'].compareTo(b['date']));
    
    _contentController.clear();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateBottomSheet) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                _buildDragHandle(),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _getRoleColor(_selectedConversation!['role']),
                        child: Icon(_getRoleIcon(_selectedConversation!['role']), color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedConversation!['name'],
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _getRoleLabel(_selectedConversation!['role']),
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    reverse: true,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[messages.length - 1 - index];
                      return Align(
                        alignment: msg['isMe'] ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: msg['isMe'] ? const Color(0xFF10B981) : Colors.grey[200],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                msg['text'],
                                style: TextStyle(
                                  color: msg['isMe'] ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTime(msg['date']),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: msg['isMe'] ? Colors.white70 : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _contentController,
                          decoration: InputDecoration(
                            hintText: 'Écrire un message...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          maxLines: 3,
                          minLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: const Color(0xFF10B981),
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white, size: 20),
                          onPressed: _isSending ? null : () async {
                            await _sendMessage(adminFirestoreId, adminName);
                            setStateBottomSheet(() {});
                            await _loadConversations(adminFirestoreId);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildDragHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
  
  Widget _buildDialogHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF10B981), size: 22),
          ),
          const SizedBox(width: 14),
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
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
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 7) return '${date.day}/${date.month}/${date.year}';
    if (diff.inDays > 0) return 'il y a ${diff.inDays} j';
    if (diff.inHours > 0) return 'il y a ${diff.inHours} h';
    if (diff.inMinutes > 0) return 'il y a ${diff.inMinutes} min';
    return 'maintenant';
  }
  
  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
  
  Color _getRoleColor(String role) {
    switch (role) {
      case 'teacher': return Colors.blue;
      case 'student': return Colors.green;
      case 'parent': return Colors.orange;
      case 'staff': return Colors.purple;
      case 'admin': return Colors.red;
      default: return Colors.grey;
    }
  }
  
  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'teacher': return Icons.school;
      case 'student': return Icons.child_care;
      case 'parent': return Icons.family_restroom;
      case 'staff': return Icons.person;
      case 'admin': return Icons.admin_panel_settings;
      default: return Icons.person;
    }
  }
  
  String _getRoleLabel(String role) {
    switch (role) {
      case 'teacher': return 'Professeur';
      case 'student': return 'Élève';
      case 'parent': return 'Parent';
      case 'staff': return 'Personnel';
      case 'admin': return 'Administrateur';
      default: return 'Inconnu';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final adminFirestoreId = auth.user?.firestoreId;
    final adminName = auth.user?.name ?? auth.user?.email ?? 'Administrateur';
    final unreadCount = conversations.fold<int>(0, (sum, c) => sum + (c['unreadCount'] as int));
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Messages', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.message_outlined),
                onPressed: () {},
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadData(),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFF10B981)),
            onPressed: () => _showNewConversationDialog(adminFirestoreId!, adminName),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.red[100],
                        child: const Icon(Icons.admin_panel_settings, size: 20, color: Colors.red),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(adminName, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('Administrateur', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: conversations.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text('Aucune conversation', style: TextStyle(color: Colors.grey[500])),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () => _showNewConversationDialog(adminFirestoreId!, adminName),
                                icon: const Icon(Icons.edit),
                                label: const Text('Nouveau message'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: conversations.length,
                          itemBuilder: (context, index) {
                            final conv = conversations[index];
                            final unread = conv['unreadCount'] as int;
                            
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedConversation = conv;
                                });
                                _showConversationDetail(adminFirestoreId!, adminName);
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getRoleColor(conv['role']),
                                    child: Icon(_getRoleIcon(conv['role']), color: Colors.white, size: 20),
                                  ),
                                  title: Text(
                                    conv['name'],
                                    style: TextStyle(
                                      fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: Text(
                                    conv['lastMessage'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: unread > 0 ? Colors.black87 : Colors.grey[600],
                                    ),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _formatDate(conv['lastDate']),
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                      if (unread > 0)
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF10B981),
                                            shape: BoxShape.circle,
                                          ),
                                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                          child: Text(
                                            '$unread',
                                            style: const TextStyle(color: Colors.white, fontSize: 10),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                    ],
                                  ),
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