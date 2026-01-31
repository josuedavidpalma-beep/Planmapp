import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:rxdart/rxdart.dart';
import 'package:planmapp/features/plans/services/plan_members_service.dart';

class RouletteScreen extends StatefulWidget {
  final String planId;
  const RouletteScreen({super.key, required this.planId});

  @override
  State<RouletteScreen> createState() => _RouletteScreenState();
}

class _RouletteScreenState extends State<RouletteScreen> {
  final StreamController<int> _selected = BehaviorSubject<int>();
  List<PlanMember> _participants = [];
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
      final members = await PlanMembersService().getMembers(widget.planId);
      
      // Auto-add "Yo" if list is empty (rare)
      if (members.isEmpty) {
          // Should not happen if user is viewing this inside a plan
      }

      if (mounted) {
        setState(() {
          _participants = members;
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
    
    // Logic: Pick random
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
          barrierDismissible: false,
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
                                  const Text("🏆 ¡Tenemos un Elegido! 🏆", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                  const SizedBox(height: 20),
                                  CircleAvatar(
                                      radius: 50,
                                      backgroundImage: winner.avatarUrl != null ? NetworkImage(winner.avatarUrl!) : null,
                                      backgroundColor: AppTheme.primaryBrand,
                                      child: winner.avatarUrl == null 
                                          ? Text(winner.name[0].toUpperCase(), style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold))
                                          : null,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                      winner.name,
                                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.primaryBrand),
                                      textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primaryBrand,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                                      ),
                                      onPressed: () => Navigator.pop(c), 
                                      child: const Text("Aceptar Destino", style: TextStyle(fontWeight: FontWeight.bold))
                                  )
                              ],
                          ),
                      ),
                      // Confetti or visual flair could go here
                  ],
              ),
          )
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("La Ruleta", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.primaryBrand,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
           gradient: LinearGradient(
               colors: [AppTheme.primaryBrand.withOpacity(0.05), Colors.white],
               begin: Alignment.topCenter,
               end: Alignment.bottomCenter
           )
        ),
        child: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text("Toca 'Girar' y deja que el destino decida 🎲", 
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)
                  ),
                ),
                Expanded(
                    child: _participants.length < 2 
                        ? Center(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    const Icon(Icons.group_add_rounded, size: 80, color: Colors.grey),
                                    const SizedBox(height: 16),
                                    Text(
                                        _participants.isEmpty 
                                            ? "¡Agrega jugadores para empezar!" 
                                            : "¡Necesitas al menos 2 jugadores!",
                                        style: const TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold)
                                    ),
                                    const SizedBox(height: 20),
                                    ElevatedButton.icon(
                                        onPressed: _showAddPlayerDialog,
                                        icon: const Icon(Icons.add),
                                        label: const Text("Agregar Jugador Temporales"),
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.secondaryBrand,
                                            foregroundColor: Colors.white
                                        ),
                                    ),
                                    if (_participants.isNotEmpty) ...[
                                        const SizedBox(height: 24),
                                        const Text("Jugadores actuales:", style: TextStyle(fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 12),
                                        Wrap(
                                            spacing: 8,
                                            children: _participants.map((p) => Chip(
                                                avatar: CircleAvatar(
                                                    backgroundImage: p.avatarUrl != null ? NetworkImage(p.avatarUrl!) : null,
                                                    child: p.avatarUrl == null ? Text(p.name[0]) : null,
                                                ),
                                                label: Text(p.name),
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
                        padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            FortuneWheel(
                                selected: _selected.stream,
                                animateFirst: false,
                                onAnimationEnd: _onAnimationEnd,
                                indicators: const <FortuneIndicator>[
                                    FortuneIndicator(
                                        alignment: Alignment.topCenter,
                                        child: TriangleIndicator(
                                            color: AppTheme.secondaryBrand,
                                        ),
                                    ),
                                ],
                                items: [
                                    for (var p in _participants)
                                        FortuneItem(
                                            child: Text(
                                                p.name, 
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 16)
                                            ),
                                            style: FortuneItemStyle(
                                                color: _participants.indexOf(p) % 2 == 0 
                                                    ? const Color(0xFFE1F5FE) // Light Blue 
                                                    : const Color(0xFFFFF3E0), // Light Orange
                                                borderColor: AppTheme.primaryBrand.withOpacity(0.5),
                                                borderWidth: 1
                                            )
                                        )
                                ],
                            ),
                            // Center Circle for better look
                            Container(
                                width: 50, height: 50,
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)]
                                ),
                                child: const Center(child: Icon(Icons.star, color: AppTheme.secondaryBrand)),
                            )
                          ],
                        ),
                    )
                ),
                Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
                    ),
                    child: Column(
                      children: [
                        Row(
                            children: [
                                FloatingActionButton(
                                    mini: true,
                                    onPressed: _showAddPlayerDialog,
                                    backgroundColor: Colors.grey[100],
                                    elevation: 0,
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
                                                disabledBackgroundColor: Colors.grey[300],
                                                foregroundColor: Colors.white,
                                                elevation: 4,
                                                shadowColor: AppTheme.primaryBrand.withOpacity(0.4),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                                            ),
                                            child: _isSpinning 
                                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                                                : const Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                        Icon(Icons.casino_outlined, size: 28),
                                                        SizedBox(width: 12),
                                                        Text("¡GIRAR!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                                    ],
                                                )
                                        ),
                                    ),
                                ),
                            ],
                        ),
                        const SizedBox(height: 20), // Bottom safe area spacer
                      ],
                    ),
                )
            ],
        ),
      ),
    );
  }

  void _showAddPlayerDialog() {
      final TextEditingController nameCtrl = TextEditingController();
      showDialog(
          context: context,
          builder: (c) => AlertDialog(
              title: const Text("Agregar Jugador"),
              content: TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: "Nombre",
                      hintText: "Ej. Juan, María...",
                      border: OutlineInputBorder()
                  ),
                  textCapitalization: TextCapitalization.words,
                  autofocus: true,
              ),
              actions: [
                  TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancelar")),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBrand, foregroundColor: Colors.white),
                      onPressed: () {
                          if (nameCtrl.text.trim().isNotEmpty) {
                              setState(() {
                                  _participants.add(PlanMember(
                                      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                                      name: nameCtrl.text.trim(),
                                      isGuest: true
                                  ));
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
