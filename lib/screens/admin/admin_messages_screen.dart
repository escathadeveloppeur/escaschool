// lib/screens/admin/admin_messages_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';

// ===================== PALETTE / THEME HELPERS =====================
class _AppColors {
  static const Color primary = Color(0xFF1E3A8A);
  static const Color primaryLight = Color(0xFF3B5BDB);
  static const Color background = Color(0xFFF4F6FB);
  static const Color cardBorder = Color(0xFFE6E9F2);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF6B7280);
  
  // Couleurs pour les rôles
  static const Color teacherColor = Color(0xFF3B82F6);
  static const Color studentColor = Color(0xFF10B981);
  static const Color parentColor = Color(0xFFF59E0B);
  static const Color staffColor = Color(0xFF8B5CF6);
  static const Color adminColor = Color(0xFFEF4444);
}

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
      
      adminInfo = {
        'id': adminFirestoreId,
        'name': adminName,
        'role': 'admin',
      };
      
      await _loadTeachers(schoolId?.toString());
      await _loadStudents(schoolId?.toString());
      await _loadParents();
      await _loadStaffs();
      await _loadConversations(adminFirestoreId);
      
      _animationController.forward();
    } catch (e) {
      print('❌ Erreur: $e');
      _showSnackBar('Erreur de chargement', const Color(0xFFEF4444));
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _loadTeachers(String? schoolId) async {
    Query query = FirebaseFirestore.instance.collection('professors');
    if (schoolId != null) {
      query = query.where('schoolId', isEqualTo: int.tryParse(schoolId) ?? 0);
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
    }
  }
  
  Future<void> _loadStudents(String? schoolId) async {
    Query query = FirebaseFirestore.instance.collection('students');
    if (schoolId != null) {
      query = query.where('schoolId', isEqualTo: int.tryParse(schoolId) ?? 0);
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
    }
  }
  
  Future<void> _loadParents() async {
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
    }
  }
  
  Future<void> _loadStaffs() async {
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
    }
  }
  
  Future<void> _loadConversations(String? adminFirestoreId) async {
    if (adminFirestoreId == null) return;
    
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
    
    conversationMap = {};
    
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
      _showSnackBar('Veuillez écrire un message', const Color(0xFFF59E0B));
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
      
      _showSnackBar('Message envoyé', const Color(0xFF10B981));
    } catch (e) {
      _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
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
                  _buildDialogHeader('Nouveau message', Icons.edit_rounded),
                  const SizedBox(height: 16),
                  
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (teachers.isNotEmpty) ...[
                            _buildSectionHeader('PROFESSEURS', _AppColors.teacherColor),
                            const SizedBox(height: 8),
                            ...teachers.map((teacher) => _buildContactTile(
                              name: teacher['name'],
                              role: 'teacher',
                              subtitle: teacher['specialty'],
                              icon: Icons.school_rounded,
                              color: _AppColors.teacherColor,
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
                          
                          if (students.isNotEmpty) ...[
                            _buildSectionHeader('ÉLÈVES', _AppColors.studentColor),
                            const SizedBox(height: 8),
                            ...students.map((student) => _buildContactTile(
                              name: student['name'],
                              role: 'student',
                              subtitle: student['className'],
                              icon: Icons.child_care_rounded,
                              color: _AppColors.studentColor,
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
                          
                          if (parents.isNotEmpty) ...[
                            _buildSectionHeader('PARENTS', _AppColors.parentColor),
                            const SizedBox(height: 8),
                            ...parents.map((parent) => _buildContactTile(
                              name: parent['name'],
                              role: 'parent',
                              subtitle: '',
                              icon: Icons.family_restroom_rounded,
                              color: _AppColors.parentColor,
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
                          
                          if (staffs.isNotEmpty) ...[
                            _buildSectionHeader('PERSONNEL', _AppColors.staffColor),
                            const SizedBox(height: 8),
                            ...staffs.map((staff) => _buildContactTile(
                              name: staff['name'],
                              role: 'staff',
                              subtitle: staff['role'],
                              icon: Icons.person_rounded,
                              color: _AppColors.staffColor,
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
                            _buildEmptyContactsState(),
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
  
  Widget _buildSectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
  
  Widget _buildContactTile({
    required String name,
    required String role,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _AppColors.cardBorder),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(name, style: TextStyle(fontWeight: FontWeight.w600, color: _AppColors.textDark)),
        subtitle: subtitle.isNotEmpty 
            ? Text(subtitle, style: TextStyle(fontSize: 12, color: _AppColors.textMuted))
            : null,
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _AppColors.textMuted),
        onTap: onTap,
      ),
    );
  }
  
  Widget _buildEmptyContactsState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _AppColors.primary.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_off_rounded, size: 48, color: _AppColors.primary.withOpacity(0.4)),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun contact disponible',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _AppColors.textMuted),
          ),
        ],
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
                _buildConversationHeader(),
                const Divider(height: 1, color: _AppColors.cardBorder),
                
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    reverse: true,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[messages.length - 1 - index];
                      return _buildMessageBubble(msg);
                    },
                  ),
                ),
                
                _buildMessageInput(adminFirestoreId, adminName, setStateBottomSheet),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildConversationHeader() {
    final role = _selectedConversation!['role'];
    final color = _getRoleColor(role);
    final icon = _getRoleIcon(role);
    final label = _getRoleLabel(role);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(child: Icon(icon, color: Colors.white, size: 24)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedConversation!['name'],
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _AppColors.textDark),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: _AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMe = message['isMe'] as bool;
    final color = isMe ? const Color(0xFF10B981) : _AppColors.background;
    final textColor = isMe ? Colors.white : _AppColors.textDark;
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: isMe ? null : Border.all(color: _AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message['text'],
              style: TextStyle(color: textColor, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message['date']),
              style: TextStyle(
                fontSize: 10,
                color: isMe ? Colors.white70 : _AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMessageInput(String adminFirestoreId, String adminName, StateSetter setStateBottomSheet) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _AppColors.background,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: _AppColors.cardBorder),
              ),
              child: TextField(
                controller: _contentController,
                decoration: InputDecoration(
                  hintText: 'Écrire un message...',
                  hintStyle: TextStyle(color: _AppColors.textMuted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                maxLines: 3,
                minLines: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: _isSending ? null : () async {
                await _sendMessage(adminFirestoreId, adminName);
                setStateBottomSheet(() {});
                await _loadConversations(adminFirestoreId);
              },
            ),
          ),
        ],
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
          color: _AppColors.cardBorder,
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF10B981), size: 24),
          ),
          const SizedBox(width: 14),
          Text(
            title,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _AppColors.textDark),
          ),
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
      case 'teacher': return _AppColors.teacherColor;
      case 'student': return _AppColors.studentColor;
      case 'parent': return _AppColors.parentColor;
      case 'staff': return _AppColors.staffColor;
      case 'admin': return _AppColors.adminColor;
      default: return Colors.grey;
    }
  }
  
  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'teacher': return Icons.school_rounded;
      case 'student': return Icons.child_care_rounded;
      case 'parent': return Icons.family_restroom_rounded;
      case 'staff': return Icons.person_rounded;
      case 'admin': return Icons.admin_panel_settings_rounded;
      default: return Icons.person_rounded;
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
      backgroundColor: _AppColors.background,
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Messages',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19, letterSpacing: 0.2),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_AppColors.primary, _AppColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.message_rounded),
                onPressed: () {},
                tooltip: 'Messages',
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "Actualiser",
            onPressed: () => _loadData(),
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: Color(0xFF10B981)),
            tooltip: "Nouveau message",
            onPressed: () => _showNewConversationDialog(adminFirestoreId!, adminName),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_AppColors.primary),
              ),
            )
          : Column(
              children: [
                const SizedBox(height: 12),
                
                // Profil admin
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _AppColors.cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEF4444), Color(0xFFF97316)],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              adminName,
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _AppColors.textDark),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Administrateur',
                              style: TextStyle(fontSize: 12, color: _AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Compteur conversations
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.chat_bubble_outline_rounded, size: 18, color: _AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Conversations (${conversations.length})",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _AppColors.textDark),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Liste des conversations
                Expanded(
                  child: conversations.isEmpty
                      ? _buildEmptyConversationsState(adminFirestoreId, adminName)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: conversations.length,
                          itemBuilder: (context, index) {
                            final conv = conversations[index];
                            return _buildConversationCard(conv, adminFirestoreId!, adminName);
                          },
                        ),
                ),
              ],
            ),
    );
  }
  
  Widget _buildEmptyConversationsState(String? adminFirestoreId, String adminName) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _AppColors.primary.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chat_bubble_outline_rounded, size: 56, color: _AppColors.primary.withOpacity(0.4)),
          ),
          const SizedBox(height: 20),
          Text(
            'Aucune conversation',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _AppColors.textDark),
          ),
          const SizedBox(height: 8),
          Text(
            'Commencez un nouveau message',
            style: TextStyle(fontSize: 13, color: _AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _showNewConversationDialog(adminFirestoreId!, adminName),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Nouveau message'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildConversationCard(Map<String, dynamic> conversation, String adminFirestoreId, String adminName) {
    final unread = conversation['unreadCount'] as int;
    final role = conversation['role'];
    final color = _getRoleColor(role);
    final icon = _getRoleIcon(role);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedConversation = conversation;
        });
        _showConversationDetail(adminFirestoreId, adminName);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(child: Icon(icon, color: Colors.white, size: 24)),
          ),
          title: Text(
            conversation['name'],
            style: TextStyle(
              fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w600,
              fontSize: 15,
              color: _AppColors.textDark,
            ),
          ),
          subtitle: Text(
            conversation['lastMessage'],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: unread > 0 ? _AppColors.textDark : _AppColors.textMuted,
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _formatDate(conversation['lastDate']),
                style: TextStyle(fontSize: 10, color: _AppColors.textMuted),
              ),
              if (unread > 0)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}