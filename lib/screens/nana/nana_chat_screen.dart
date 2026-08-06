// lib/screens/nana/nana_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/nana_provider.dart';

class NanaChatScreen extends StatefulWidget {
  final String role;
  final String userId;
  final String userName;
  
  const NanaChatScreen({
    super.key,
    required this.role,
    required this.userId,
    required this.userName,
  });

  @override
  State<NanaChatScreen> createState() => _NanaChatScreenState();
}

class _NanaChatScreenState extends State<NanaChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  // 🎨 Couleurs du thème "carnet d'écolier"
  static const Color _paperColor = Color(0xFFFAF7F0);
  static const Color _inkColor = Color(0xFF1C2B45);
  static const Color _inkSoftColor = Color(0xFF46536B);
  static const Color _marginRedColor = Color(0xFFC1392B);
  static const Color _gridBlueColor = Color(0xFFB7CBE8);
  static const Color _chalkColor = Color(0xFFE3AE3F);

  @override
  void initState() {
    super.initState();
    _initNana();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initNana() async {
    final nanaProvider = Provider.of<NanaProvider>(context, listen: false);
    if (nanaProvider.messages.isEmpty) {
      await nanaProvider.initialize(
        role: widget.role,
        userId: widget.userId,
        userName: widget.userName,
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NanaProvider>(
      builder: (context, nanaProvider, child) {
        final messages = nanaProvider.messages;
        final isLoading = nanaProvider.isLoading;
        final errorMessage = nanaProvider.errorMessage;
        
        _scrollToBottom();

        return Container(
          width: MediaQuery.of(context).size.width * 0.92,
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: _paperColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.22),
                blurRadius: 40,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              children: [
                // Header
                _buildHeader(nanaProvider),
                
                // Messages avec lignes de cahier
                Expanded(
                  child: Stack(
                    children: [
                      // Lignes de cahier
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _NotebookLinesPainter(
                            lineColor: _gridBlueColor.withOpacity(0.4),
                            lineHeight: 26,
                          ),
                        ),
                      ),
                      
                      // Messages
                      if (messages.isEmpty)
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.smart_toy,
                                size: 60,
                                color: _chalkColor.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Posez votre question',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: _inkSoftColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Nana est là pour vous aider',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _inkSoftColor.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final isUser = message['role'] == 'user';
                            final isSystem = message['role'] == 'system';
                            
                            if (isSystem) {
                              return _buildSystemMessage(message['content']!);
                            }
                            
                            return _buildMessage(
                              content: message['content']!,
                              isUser: isUser,
                            );
                          },
                        ),
                      
                      // Indicateur de chargement
                      if (isLoading)
                        Positioned(
                          bottom: 10,
                          left: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _marginRedColor.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _inkColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'écrit…',
                                  style: TextStyle(
                                    color: _inkSoftColor,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      // Message d'erreur
                      if (errorMessage != null)
                        Positioned(
                          top: 10,
                          left: 0,
                          right: 0,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    errorMessage,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Input
                _buildInput(nanaProvider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(NanaProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
      decoration: BoxDecoration(
        color: _inkColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Stack(
        children: [
          // Marge rouge
          Positioned(
            left: 10,
            top: 8,
            bottom: 8,
            child: Container(
              width: 2,
              color: _marginRedColor.withOpacity(0.65),
            ),
          ),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 14,
                          backgroundColor: Color(0xFFE3AE3F),
                          child: Icon(
                            Icons.smart_toy,
                            color: Color(0xFF1C2B45),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Assistant',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _chalkColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.only(left: 38),
                      child: Text(
                        'Toujours prêt à aider',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[400],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Bouton effacer historique
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.white70, size: 18),
                onPressed: () => _showClearHistoryDialog(provider),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Effacer l\'historique',
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => provider.toggleChat(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessage({required String content, required bool isUser}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            // Marge rouge pour l'assistant
            Container(
              width: 2,
              height: 30,
              color: _marginRedColor,
              margin: const EdgeInsets.only(right: 10, top: 2),
            ),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                child: SelectableText(
                  content,
                  style: TextStyle(
                    color: _inkColor,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ] else ...[
            // Message utilisateur
            Container(
              constraints: const BoxConstraints(maxWidth: 280),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFDF3D8),
                border: Border.all(color: _chalkColor),
                borderRadius: BorderRadius.circular(10).copyWith(
                  bottomRight: const Radius.circular(2),
                ),
              ),
              child: SelectableText(
                content,
                style: TextStyle(
                  color: _inkColor,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSystemMessage(String content) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _chalkColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _chalkColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: _chalkColor, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              content,
              style: TextStyle(
                color: _inkSoftColor,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(NanaProvider provider) {
    final suggestions = provider.getSuggestions(widget.role);
    
    return Container(
      decoration: BoxDecoration(
        color: _paperColor,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Suggestions
          if (provider.messages.length <= 3)
            SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                scrollDirection: Axis.horizontal,
                itemCount: suggestions.take(4).length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return ActionChip(
                    label: Text(
                      suggestions[index],
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: _chalkColor.withOpacity(0.15),
                    side: BorderSide(color: _chalkColor.withOpacity(0.3)),
                    onPressed: () => _sendMessage(provider, suggestions[index]),
                  );
                },
              ),
            ),
          
          // Barre de saisie
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onChanged: (value) => setState(() => _isTyping = value.isNotEmpty),
                    onSubmitted: (value) => _sendMessage(provider, value),
                    decoration: InputDecoration(
                      hintText: 'Pose ta question…',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _marginRedColor),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    maxLines: 3,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _inkColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(
                      provider.isLoading ? Icons.stop : Icons.send,
                      color: _chalkColor,
                      size: 16,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: provider.isLoading
                        ? null
                        : () => _sendMessage(provider, _controller.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage(NanaProvider provider, String message) {
    if (message.trim().isEmpty) return;
    _controller.clear();
    setState(() => _isTyping = false);
    
    // Fermer le clavier
    FocusScope.of(context).unfocus();
    
    provider.sendMessage(
      message: message,
      role: widget.role,
      userId: widget.userId,
      userName: widget.userName,
    );
  }

  void _showClearHistoryDialog(NanaProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Effacer l\'historique ?'),
        content: const Text(
          'Toutes les conversations seront supprimées. Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              provider.clearHistory(widget.userId);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
  }
}

// 🎨 PAINTER pour les lignes de cahier
class _NotebookLinesPainter extends CustomPainter {
  final Color lineColor;
  final double lineHeight;

  _NotebookLinesPainter({
    required this.lineColor,
    required this.lineHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;

    for (double y = lineHeight; y < size.height; y += lineHeight) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_NotebookLinesPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor || 
           oldDelegate.lineHeight != lineHeight;
  }
}