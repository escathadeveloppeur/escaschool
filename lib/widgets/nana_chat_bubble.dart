// lib/widgets/nana_chat_bubble.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/nana_provider.dart';
import '../screens/nana/nana_chat_screen.dart';

class NanaChatBubble extends StatelessWidget {
  final String role;
  final String userId;
  final String userName;
  
  const NanaChatBubble({
    super.key,
    required this.role,
    required this.userId,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<NanaProvider>(
      builder: (context, nanaProvider, child) {
        // Si le chat est ouvert, afficher le chat
        if (nanaProvider.isChatOpen) {
          // ✅ Utiliser un Material avec un Overlay
          return Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () => nanaProvider.toggleChat(),
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: Center(
                  child: GestureDetector(
                    onTap: () {}, // Empêche la fermeture
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.92,
                      height: MediaQuery.of(context).size.height * 0.75,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.22),
                            blurRadius: 40,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: NanaChatScreen(
                        role: role,
                        userId: userId,
                        userName: userName,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        
        // Bulle flottante
        return GestureDetector(
          onTap: () => nanaProvider.toggleChat(),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1C2B45), Color(0xFF2C3D5F)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.chat_rounded,
                color: Color(0xFFE3AE3F),
                size: 28,
              ),
            ),
          ),
        );
      },
    );
  }
}