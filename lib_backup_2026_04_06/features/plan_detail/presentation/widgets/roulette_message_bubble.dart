import 'package:flutter/material.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/plan_detail/domain/models/message_model.dart';
import 'package:planmapp/features/games/presentation/widgets/wheel_spin_dialog.dart';

class RouletteMessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const RouletteMessageBubble({super.key, required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final metadata = message.metadata ?? {};
    final winner = metadata['winner'] ?? 'Desconocido';
    final options = List<String>.from(metadata['options'] ?? []);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 280,
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primaryBrand.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isMe ? const Radius.circular(0) : null,
            bottomLeft: !isMe ? const Radius.circular(0) : null,
          ),
          border: Border.all(color: AppTheme.primaryBrand.withOpacity(0.3)),
          boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
          ]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.casino_outlined, size: 20, color: AppTheme.secondaryBrand),
                const SizedBox(width: 8),
                Text(
                  "Ruleta Rusa",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryBrand,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            const Text("El destino decidió:", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.secondaryBrand.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                winner,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
            ),
            if (options.isNotEmpty && options.length <= 5) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: options.map((o) => Text(
                      o == winner ? "" : o, // Don't show winner in small list
                      style: const TextStyle(fontSize: 10, color: Colors.grey)
                  )).where((w) => (w.data as String).isNotEmpty).toList(),
                )
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton.icon(
                onPressed: () {
                    showDialog(
                        context: context, 
                        builder: (c) => WheelSpinDialog(
                            planId: message.planId, 
                            onSpinComplete: (_){},
                            initialOptions: options,
                            replayWinner: winner, // Replay Mode
                        )
                    );
                }, 
                icon: const Icon(Icons.replay, size: 16),
                label: const Text("Ver Repetición"),
                style: ElevatedButton.styleFrom(
                   backgroundColor: Colors.white,
                   foregroundColor: AppTheme.primaryBrand,
                   elevation: 0,
                   side: const BorderSide(color: AppTheme.primaryBrand)
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
