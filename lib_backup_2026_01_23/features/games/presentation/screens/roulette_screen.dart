import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:rxdart/rxdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RouletteScreen extends StatefulWidget {
  final String planId;
  const RouletteScreen({super.key, required this.planId});

  @override
  State<RouletteScreen> createState() => _RouletteScreenState();
}

class _RouletteScreenState extends State<RouletteScreen> {
  final StreamController<int> _selected = BehaviorSubject<int>();
  List<Map<String, dynamic>> _participants = [];
  bool _isLoading = true;
  bool _isSpinning = false;
  int _lastWinnerIndex = -1;

  @override
  void initState() {
    super.initState();
    _fetchParticipants();
  }

  @override
  void dispose() {
    _selected.close();
    super.dispose();
  }

  Future<void> _fetchParticipants() async {
    try {
      final response = await Supabase.instance.client
          .from('plan_members')
          .select('profiles(id, first_name, avatar_url)')
          .eq('plan_id', widget.planId);

      final List<Map<String, dynamic>> loaded = [];
      for (var row in response) {
        final profile = row['profiles'];
        if (profile != null) {
            // Ensure we have a name
            loaded.add({
                'name': profile['first_name'] ?? 'Usuario',
                'avatar': profile['avatar_url']
            });
        }
      }

      // If less than 2, add placeholders to make wheel work visually
      /* 
       * DISABLED AUTOMATIC PLACEHOLDERS to prioritize manual entry
      if (loaded.isEmpty) {
          loaded.add({'name': 'Yo', 'avatar': null});
          loaded.add({'name': 'Tú', 'avatar': null});
      }
      */

      if (mounted) {
        setState(() {
          _participants = loaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error cargando jugadores: $e")));
          setState(() => _isLoading = false);
      }
    }
  }

  void _spinWheel() {
    if (_isSpinning) return;
    setState(() => _isSpinning = true);
    
    final winnerIndex = Random().nextInt(_participants.length);
    _selected.add(winnerIndex);
    _lastWinnerIndex = winnerIndex;
  }

  void _onAnimationEnd() {
      setState(() => _isSpinning = false);
      _showWinnerDialog();
  }

  void _showWinnerDialog() {
      final winner = _participants[_lastWinnerIndex];
      showDialog(
          context: context, 
          builder: (c) => Dialog(
              backgroundColor: Colors.transparent,
              child: Stack(
                  alignment: Alignment.center,
                  children: [
                      Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                  BoxShadow(color: AppTheme.primaryBrand.withOpacity(0.5), blurRadius: 30, spreadRadius: 5)
                              ]
                          ),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                  const Text("🏆 ¡Tenemos un Pagador! 🏆", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                  const SizedBox(height: 20),
                                  CircleAvatar(
                                      radius: 40,
                                      backgroundColor: AppTheme.primaryBrand,
                                      child: Text(winner['name'][0], style: const TextStyle(fontSize: 30, color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                      winner['name'],
                                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.primaryBrand),
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton(
                                      onPressed: () => Navigator.pop(c), 
                                      child: const Text("Aceptar Destino")
                                  )
                              ],
                          ),
                      ),
                  ],
              ),
          )
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("La Ruleta")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
                const SizedBox(height: 20),
                const Text("Toca 'Girar' y descubre quién paga hoy 💸", style: TextStyle(fontSize: 16, color: Colors.grey)),
                Expanded(
                    child: _participants.length < 2 
                        ? Center(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    const Icon(Icons.group_add, size: 60, color: Colors.grey),
                                    const SizedBox(height: 16),
                                    // Change text based on count
                                    Text(
                                        _participants.isEmpty 
                                            ? "¡Agrega jugadores para empezar!" 
                                            : "¡Necesitas al menos 2 jugadores!",
                                        style: const TextStyle(fontSize: 18, color: Colors.grey)
                                    ),
                                    const SizedBox(height: 20),
                                    ElevatedButton.icon(
                                        onPressed: _showAddPlayerDialog,
                                        icon: const Icon(Icons.add),
                                        label: const Text("Agregar Jugador")
                                    ),
                                    // Show current list if we have 1 player
                                    if (_participants.isNotEmpty) ...[
                                        const SizedBox(height: 24),
                                        const Text("Jugadores actuales:", style: TextStyle(fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 8),
                                        Wrap(
                                            spacing: 8,
                                            children: _participants.map((p) => Chip(
                                                label: Text(p['name']),
                                                onDeleted: () {
                                                    setState(() {
                                                        _participants.remove(p);
                                                    });
                                                },
                                            )).toList(),
                                        )
                                    ]
                                ],
                            )
                        )
                        : Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: FortuneWheel(
                            selected: _selected.stream,
                            animateFirst: false,
                            onAnimationEnd: _onAnimationEnd,
                            items: [
                                for (var p in _participants)
                                    FortuneItem(
                                        child: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                                        style: FortuneItemStyle(
                                            color: AppTheme.primaryBrand.withOpacity(
                                                // Alternating colors
                                                _participants.indexOf(p) % 2 == 0 ? 0.3 : 0.1
                                            ),
                                            borderColor: AppTheme.primaryBrand,
                                            borderWidth: 2
                                        )
                                    )
                            ],
                        ),
                    )
                ),
                Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Row(
                        children: [
                            FloatingActionButton(
                                onPressed: _showAddPlayerDialog,
                                backgroundColor: Colors.white,
                                child: const Icon(Icons.add, color: AppTheme.primaryBrand),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                                child: SizedBox(
                                    height: 56,
                                    child: ElevatedButton(
                                        onPressed: (_isSpinning || _participants.length < 2) ? null : _spinWheel,
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.primaryBrand,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                                        ),
                                        child: _isSpinning 
                                            ? const CircularProgressIndicator(color: Colors.white) 
                                            : const Text("¡GIRAR!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))
                                    ),
                                ),
                            ),
                        ],
                    ),
                )
            ],
        ),
    );
  }

  void _showAddPlayerDialog() {
      final TextEditingController _nameCtrl = TextEditingController();
      showDialog(
          context: context,
          builder: (c) => AlertDialog(
              title: const Text("Agregar Jugador"),
              content: TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: "Nombre"),
                  textCapitalization: TextCapitalization.words,
                  autofocus: true,
              ),
              actions: [
                  TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancelar")),
                  ElevatedButton(
                      onPressed: () {
                          if (_nameCtrl.text.trim().isNotEmpty) {
                              setState(() {
                                  _participants.add({'name': _nameCtrl.text.trim(), 'avatar': null});
                              });
                          }
                          Navigator.pop(c);
                      },
                      child: const Text("Agregar")
                  )
              ],
          )
      );
  }
}
