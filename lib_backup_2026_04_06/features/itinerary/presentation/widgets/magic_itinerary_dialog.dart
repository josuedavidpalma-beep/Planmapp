
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:planmapp/core/theme/app_theme.dart';

class MagicItineraryDialog extends StatefulWidget {
  const MagicItineraryDialog({super.key});

  @override
  State<MagicItineraryDialog> createState() => _MagicItineraryDialogState();
}

class _MagicItineraryDialogState extends State<MagicItineraryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _daysController = TextEditingController(text: "3");
  final _interestsController = TextEditingController();
  
  bool _isGenerating = false;

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, {
        'location': _locationController.text,
        'days': int.parse(_daysController.text),
        'interests': _interestsController.text,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.purple.withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(color: Colors.purple.withOpacity(0.2), blurRadius: 20, spreadRadius: 5),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 48)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 1.seconds),
              const SizedBox(height: 16),
              const Text(
                "Asistente Mágico",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                "Deja que la IA organice tu viaje ideal.",
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Location Input
              TextFormField(
                controller: _locationController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "¿A dónde vas?",
                  labelStyle: TextStyle(color: Colors.purple[200]),
                  prefixIcon: const Icon(Icons.location_on, color: Colors.purpleAccent),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[700]!)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.purpleAccent)),
                ),
                validator: (v) => v == null || v.isEmpty ? "Dinos el destino" : null,
              ),
              const SizedBox(height: 16),

              // Days Input
              TextFormField(
                controller: _daysController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "¿Cuántos días?",
                  labelStyle: TextStyle(color: Colors.purple[200]),
                  prefixIcon: const Icon(Icons.calendar_today, color: Colors.purpleAccent),
                   enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[700]!)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.purpleAccent)),
                ),
                validator: (v) => v == null || int.tryParse(v) == null ? "Ingresa un número" : null,
              ),
              const SizedBox(height: 16),

              // Interests Input
              TextFormField(
                controller: _interestsController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Intereses (Opcional)",
                  hintText: "Ej: Comida, Museos, Fiesta",
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  labelStyle: TextStyle(color: Colors.purple[200]),
                  prefixIcon: const Icon(Icons.favorite, color: Colors.purpleAccent),
                   enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[700]!)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.purpleAccent)),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 10,
                    shadowColor: Colors.purple.withOpacity(0.5),
                  ),
                  onPressed: _submit,
                  child: const Text("✨ Generar Itinerario", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
