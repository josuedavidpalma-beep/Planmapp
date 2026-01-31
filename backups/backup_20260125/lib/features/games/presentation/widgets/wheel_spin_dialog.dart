
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WheelSpinDialog extends StatefulWidget {
  final String planId;
  final Function(String result) onSpinComplete;

  const WheelSpinDialog({super.key, required this.planId, required this.onSpinComplete});

  @override
  State<WheelSpinDialog> createState() => _WheelSpinDialogState();
}

class _WheelSpinDialogState extends State<WheelSpinDialog> with SingleTickerProviderStateMixin {
  final _optionsController = TextEditingController();
  List<String> _options = [];
  bool _isSpinning = false;
  double _currentRotation = 0;
  String? _finalResult;
  bool _isThinking = false; // For AI

  @override
  void dispose() {
    _optionsController.dispose();
    super.dispose();
  }

  void _addOption() {
      if (_optionsController.text.isNotEmpty) {
          setState(() {
              _options.add(_optionsController.text);
              _optionsController.clear();
          });
      }
  }

  void _spin() {
      if (_options.isEmpty || _isSpinning) return;
      
      setState(() {
          _isSpinning = true;
          _finalResult = null;
      });

      // Simple physics simulation for spin
      // We will rotate roughly 5-10 times full circle plus a random offset
      final random = Random();
      final fullRotations = 5 + random.nextInt(5);
      final randomAngle = random.nextDouble() * 2 * pi;
      final targetRotation = _currentRotation + (fullRotations * 2 * pi) + randomAngle;
      
      // Calculate winner roughly based on angle (simplified)
      // The segment count is _options.length. 
      // This is purely visual in this MVP, we pick random index first then rotate to it.
      final winnerIndex = random.nextInt(_options.length);
      final winner = _options[winnerIndex];

      // Logic: If 0 is at top, and we have N segments. 
      // Segment angle = 2pi / N.
      // We want to land on index i. 
      // Target angle should align index i to top pointer.
      // let's simplify: just spin wild and pick random result to display.
      
      Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
              setState(() {
                  _isSpinning = false;
                  _finalResult = winner;
              });
              // Fire confetti or something?
              widget.onSpinComplete(winner);
          }
      });
  }
  
  Future<void> _askAGenie() async {
      setState(() => _isThinking = true);
      try {
           final supabase = Supabase.instance.client;
           final response = await supabase.functions.invoke('ai-assistant', body: {
               'action': 'suggest_poll_options', // Reusing this logic as it returns a list of strings
               'payload': { 'question': 'Opciones divertidas para tomar una decisión en grupo', 'location': 'general' }
           });
           
           // if (response.error != null) throw Exception(response.error!.message);
           
           final List<dynamic> suggestions = response.data;
           if (mounted) {
               setState(() {
                   for (var s in suggestions) _options.add(s.toString());
               });
           }
      } catch (e) {
           if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("El genio está dormido.")));
      } finally {
           if(mounted) setState(() => _isThinking = false);
      }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        scrollable: true,
        title: const Row(children: [Text("🎡 Ruleta de la Suerte"), Spacer(), CloseButton()]),
        content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        // THE WHEEL (Visual Mockup for MVP using Container rotation)
                         SizedBox(
                             height: 250,
                             width: 250,
                             child: Stack(
                                 alignment: Alignment.center,
                                 children: [
                                     // The Wheel
                                     AnimatedRotation(
                                         turns: _isSpinning ? 10 : 0, // Simplified: needs specialized controller for realistic physics
                                         duration: const Duration(seconds: 4),
                                         curve: Curves.easeOutCirc,
                                         child: Container(
                                             decoration: const BoxDecoration(
                                                 shape: BoxShape.circle,
                                                 gradient: SweepGradient(colors: [Colors.red, Colors.blue, Colors.green, Colors.yellow, Colors.purple, Colors.orange, Colors.red])
                                             ),
                                             child: Center(
                                                 child: Container(
                                                     width: 200, height: 200, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                                     child: Center(
                                                         child: _options.isEmpty 
                                                            ? const Text("Añade opciones", style: TextStyle(color: Colors.grey))
                                                            : Text(_options.join("\n"), textAlign: TextAlign.center, maxLines: 4, overflow: TextOverflow.ellipsis)
                                                     ),
                                                 )
                                             ),
                                         ),
                                     ),
                                     // The Pointer
                                     const Positioned(top: 0, child: Icon(Icons.arrow_drop_down, size: 40, color: Colors.black)),
                                     
                                     if (_finalResult != null)
                                         Container(
                                             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                             decoration: BoxDecoration(color: AppTheme.accentColor, borderRadius: BorderRadius.circular(16)),
                                             child: Text(_finalResult!, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18))
                                         ).animate().scale(curve: Curves.elasticOut),
                                 ],
                             ),
                         ),
                         
                         const SizedBox(height: 16),
                         if (_options.isEmpty) ...[
                             ElevatedButton.icon(
                                 onPressed: _isThinking ? null : _askAGenie, 
                                 icon: _isThinking ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
                                 label: const Text("Que la IA decida las opciones")
                             ),
                             const SizedBox(height: 8),
                         ],
                         
                         // Input
                         Row(
                             children: [
                                 Expanded(child: TextField(controller: _optionsController, decoration: const InputDecoration(hintText: "Opción (ej. Pizza)"))),
                                 IconButton(icon: const Icon(Icons.add_circle, color: AppTheme.primaryBrand), onPressed: _addOption)
                             ],
                         ),
                         
                         Wrap(
                             spacing: 8,
                             children: _options.map((e) => Chip(
                                 label: Text(e), 
                                 onDeleted: _isSpinning ? null : () => setState(() => _options.remove(e))
                             )).toList(),
                         )
                    ],
                ),
            ),
        ),
        actions: [
            ElevatedButton(
                onPressed: _options.length < 2 || _isSpinning ? null : _spin,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBrand, foregroundColor: Colors.white),
                child: Text(_isSpinning ? "Girando..." : "¡GIRAR!"),
            )
        ],
    );
  }
}
