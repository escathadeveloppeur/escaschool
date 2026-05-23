// lib/widgets/notification_badge.dart
import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationBadge extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const NotificationBadge({
    super.key,
    required this.icon,
    this.color = Colors.grey,
    this.onTap,
  });

  @override
  State<NotificationBadge> createState() => _NotificationBadgeState();
}

class _NotificationBadgeState extends State<NotificationBadge> {
  int _unreadCount = 0;
  late Stream<QuerySnapshot> _messagesStream;

  @override
  void initState() {
    super.initState();
    _setupMessagesListener();
  }

  void _setupMessagesListener() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    _messagesStream = FirebaseFirestore.instance
        .collection('messages')
        .where('recipientId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots();

    _messagesStream.listen((snapshot) {
      setState(() {
        _unreadCount = snapshot.docs.length;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: badges.Badge(
        showBadge: _unreadCount > 0,
        badgeContent: Text(
          '$_unreadCount',
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
        badgeStyle: const badges.BadgeStyle(
          badgeColor: Colors.red,
          padding: EdgeInsets.all(6),
        ),
        child: Icon(widget.icon, color: widget.color),
      ),
    );
  }
}