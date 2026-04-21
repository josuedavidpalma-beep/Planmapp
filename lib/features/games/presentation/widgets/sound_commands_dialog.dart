import 'dart:math';
import 'package:flutter/material.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/games/data/sound_commands_data.dart';

class SoundCommandsDialog extends StatefulWidget {
  final List<String> participants;
  final Function(String resultMessage) onResult;

  const SoundCommandsDialog({
    super.key,
    required this.participants,
    required this.onResult,
  });

  @override
  State<SoundCommandsDialog> createState() => _SoundCommandsDialogState();
}

class _SoundCommandsDialogState extends State<SoundCommandsDialog> {
  int _step = 0; // 0 = Seleccionar Modo, 1 = Jugando (Reto)
  String _selectedMode = 'chill'; // 'chill' or 'party'
  
  String _victim = '';
  String _challenge = '';
  final Random _random = Random();

  void _startGame(String mode) {
      if (widget.participants.isEmpty) return;
      
      setState(() {
          _selectedMode = mode;
          _victim = widget.participants[_random.nextInt(widget.participants.length)];
          
          final list = mode == 'party' ? SoundCommandsData.partyChallenges : SoundCommandsData.chillChallenges;
          _challenge = list[_random.nextInt(list.length)];
          
          _step = 1;
      });
  }

  void _endGame(bool success) {
      String msg;
      if (success) {
          msg = "🔊 ¡El grupo guió a $_victim exitosamente!\nLogró: $_challenge";
      } else {
          msg = "🔊 El grupo intentó guiar a $_victim, pero fracasaron o se rindió. 💀\nMisión era: $_challenge";
      }
      widget.onResult(msg);
      Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
       backgroundColor: AppTheme.darkSurface,
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
       child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _step == 0 ? _buildModeSelection() : _buildGameScreen(),
       )
    );
  }

  Widget _buildModeSelection() {
     return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             const Icon(Icons.volume_up_rounded, size: 48, color: Colors.blueAccent),
             const SizedBox(height: 16),
             const Text("Comandos Sonoros", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
             const SizedBox(height: 8),
             const Text(
               "Selecciona el tono de los retos. Escogeremos una víctima al azar.",
               textAlign: TextAlign.center,
               style: TextStyle(color: Colors.grey, fontSize: 14)
             ),
             const SizedBox(height: 32),
             
             // Modo Chill
             InkWell(
                 onTap: () => _startGame('chill'),
                 borderRadius: BorderRadius.circular(16),
                 child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blueAccent.withOpacity(0.5))
                    ),
                    child: const Row(
                        children: [
                            Text("☕", style: TextStyle(fontSize: 28)),
                            SizedBox(width: 16),
                            Expanded(child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                   Text("Modo Chill", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                   Text("Retos tontos y amigables. Ideal para pasar el rato.", style: TextStyle(color: Colors.white70, fontSize: 13))
                               ],
                            ))
                        ],
                    )
                 )
             ),
             
             const SizedBox(height: 16),
             
             // Modo Party
             InkWell(
                 onTap: () => _startGame('party'),
                 borderRadius: BorderRadius.circular(16),
                 child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.5))
                    ),
                    child: const Row(
                        children: [
                            Text("🔥", style: TextStyle(fontSize: 28)),
                            SizedBox(width: 16),
                            Expanded(child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                   Text("Modo Fiesta", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                   Text("Retos atrevidos, físicos o con tragos.", style: TextStyle(color: Colors.white70, fontSize: 13))
                               ],
                            ))
                        ],
                    )
                 )
             ),
             
             const SizedBox(height: 24),
             TextButton(
               onPressed: () => Navigator.of(context).pop(), 
               child: const Text("Cancelar", style: TextStyle(color: Colors.grey))
             )
           ],
        )
     );
  }

  Widget _buildGameScreen() {
      return Padding(
         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
         child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                Container(
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                   decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                   ),
                   child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                          Icon(Icons.visibility_off, color: Colors.redAccent, size: 16),
                          SizedBox(width: 8),
                          Text("¡Oculta tu pantalla de la víctima!", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13))
                      ],
                   )
                ),
                
                const SizedBox(height: 24),
                
                RichText(
                   textAlign: TextAlign.center,
                   text: TextSpan(
                       style: const TextStyle(color: Colors.white, fontSize: 18),
                       children: [
                           const TextSpan(text: "La víctima es: "),
                           TextSpan(text: _victim, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 22)),
                       ]
                   )
                ),
                
                const SizedBox(height: 24),
                
                const Text("Deberán guiarlo con sonidos para que:", style: TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                   '"$_challenge"',
                   textAlign: TextAlign.center,
                   style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)
                ),
                
                const SizedBox(height: 32),
                
                Container(
                   padding: const EdgeInsets.all(12),
                   decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                   child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                          Text("🥶 Ouu (Frío)", style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold)),
                          SizedBox(width: 16),
                          Text("🔥 Aaaa (Caliente)", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                      ]
                   )
                ),
                
                const SizedBox(height: 32),
                
                Row(
                   children: [
                       Expanded(
                           child: OutlinedButton(
                               style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.redAccent),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                               ),
                               onPressed: () => _endGame(false),
                               child: const Text("Se Rindió", style: TextStyle(color: Colors.redAccent))
                           )
                       ),
                       const SizedBox(width: 16),
                       Expanded(
                           child: ElevatedButton(
                               style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryBrand,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                               ),
                               onPressed: () => _endGame(true),
                               child: const Text("¡Logrado!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                           )
                       )
                   ],
                )
            ],
         )
      );
  }
}
