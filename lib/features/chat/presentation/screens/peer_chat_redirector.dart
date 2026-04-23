import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/core/services/plan_service.dart';

class PeerChatRedirector extends StatefulWidget {
  final String peerId;

  const PeerChatRedirector({Key? key, required this.peerId}) : super(key: key);

  @override
  State<PeerChatRedirector> createState() => _PeerChatRedirectorState();
}

class _PeerChatRedirectorState extends State<PeerChatRedirector> {
  @override
  void initState() {
    super.initState();
    _redirectToChat();
  }

  Future<void> _redirectToChat() async {
    try {
      final chatId = await PlanService().getOrCreateDirectChat(widget.peerId);
      if (mounted) {
        context.go('/plan_detail/$chatId');
      }
    } catch (e) {
      if (mounted) {
        // Fallback or error state
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error abriendo chat: $e")));
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryBrand),
            SizedBox(height: 16),
            Text("Conectando chat seguro...", style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
