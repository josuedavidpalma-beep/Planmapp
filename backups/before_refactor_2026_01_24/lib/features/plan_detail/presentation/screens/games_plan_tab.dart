import 'package:flutter/material.dart';
import 'package:planmapp/features/games/presentation/widgets/wheel_spin_dialog.dart';
import 'dart:math';

class GamesPlanTab extends StatelessWidget {
  final String planId;

  const GamesPlanTab({super.key, required this.planId});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildGameCard(
           context, 
           "Ruleta Rusa", 
           "Decide quién paga o quién toma.", 
           Icons.casino_outlined, 
           Colors.purple,
           () => _showRoulette(context),
        ),
        _buildGameCard(
           context, 
           "Verdad o Reto", 
           "Rompe el hielo con preguntas picantes.", 
           Icons.local_fire_department_outlined, 
           Colors.orange,
           () => _showTruthOrDare(context),
        ),
         _buildGameCard(
           context, 
           "Trivia", 
           "¿Quién sabe más del grupo?", 
           Icons.quiz_outlined, 
           Colors.blue,
           () => _showTrivia(context),
        ),
      ],
    );
  }

  void _showRoulette(BuildContext context) {
      showDialog(
          context: context, 
          builder: (context) => WheelSpinDialog(
              planId: planId,
              onSpinComplete: (result) {
                  // Maybe post to chat? For now just toast
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ganador: $result 🎲")));
              },
          )
      );
  }

  void _showTruthOrDare(BuildContext context) {
      // Simple MVP Dialog
      showDialog(context: context, builder: (context) => AlertDialog(
          title: const Text("🔥 Verdad o Reto"),
          content: const Text("Elige tu destino..."),
          actions: [
              TextButton(child: const Text("VERDAD", style: TextStyle(color: Colors.blue)), onPressed: () {
                  Navigator.pop(context);
                  _showRandomCard(context, "Verdad", [
                      "¿Cuál es tu peor cita?",
                      "¿Qué es lo más ilegal que has hecho?",
                      "¿Quién te cae mal de esta mesa?",
                      "¿Cuál es tu mayor miedo?",
                  ], Colors.blue);
              }),
              ElevatedButton(child: const Text("RETO", style: TextStyle(color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), onPressed: () {
                  Navigator.pop(context);
                  _showRandomCard(context, "Reto", [
                      "Baila la macarena sin música.",
                      "Deja que el grupo envíe un mensaje a quien quieran desde tu cel.",
                      "Tómate un shot sin manos.",
                      "Imita a alguien del grupo.",
                  ], Colors.orange);
              }),
          ],
      ));
  }

  void _showRandomCard(BuildContext context, String type, List<String> options, Color color) {
       final random = Random().nextInt(options.length);
       showDialog(context: context, builder: (context) => SimpleDialog(
           backgroundColor: color,
           title: Text(type, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
           children: [
               Padding(
                   padding: const EdgeInsets.all(24.0),
                   child: Text(options[random], style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
               ),
               Center(child: ElevatedButton(onPressed: ()=>Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: color), child: const Text("OK")))
           ],
       ));
  }

  void _showTrivia(BuildContext context) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🧠 Trivia: Próximamente...")));
  }

  Widget _buildGameCard(BuildContext context, String title, String desc, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shadowColor: color.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                 child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(desc, style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
