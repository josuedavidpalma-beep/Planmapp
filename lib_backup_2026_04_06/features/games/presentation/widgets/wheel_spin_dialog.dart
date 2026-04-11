
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rxdart/rxdart.dart';
import 'package:planmapp/core/services/chat_service.dart';

class WheelSpinDialog extends StatefulWidget {
  final String planId;
  final Function(String result) onSpinComplete;
  final List<String>? initialOptions;
  final String? replayWinner;

  const WheelSpinDialog({
      super.key, 
      required this.planId, 
      required this.onSpinComplete,
      this.initialOptions,
      this.replayWinner
  });

  @override
  State<WheelSpinDialog> createState() => _WheelSpinDialogState();
}

class _WheelSpinDialogState extends State<WheelSpinDialog> {
  final _optionsController = TextEditingController();
  final StreamController<int> _selectedController = BehaviorSubject<int>();
  
  List<String> _options = [];
  bool _isSpinning = false;
  bool _isThinking = false; 
  String? _finalResult;

  bool get _isReplay => widget.replayWinner != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialOptions != null) {
        _options.addAll(widget.initialOptions!);
    }
    
    // REPLAY MODE: Auto-spin to winner
    if (_isReplay && widget.replayWinner != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
             _spinToWinner(widget.replayWinner!);
        });
    }
  }

  @override
  void dispose() {
    _optionsController.dispose();
    _selectedController.close();
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

  void _spinToWinner(String winner) {
      if (_isSpinning) return;
      final index = _options.indexOf(winner);
      if (index == -1) return; // Should not happen in replay unless data corrupted

      setState(() {
          _isSpinning = true;
          _finalResult = null;
      });
      _selectedController.add(index);
  }

  void _spin() {
      if (_options.isEmpty || _isSpinning) return;
      
      final index = Fortune.randomInt(0, _options.length);
      setState(() {
          _isSpinning = true;
          _finalResult = null;
      });
      _selectedController.add(index);
  }

  void _onAnimationEnd() {
      // Find who was selected (the stream value handles the visual stop, but we need to know the index)
      // Actually FortuneWheel doesn't return the index in onAnimationEnd easily without tracking state.
      // But we SET the index, so we know it if we tracked it? 
      // FortuneWheel widget takes a stream. We pushed an int.
      // We can't easily retrieve the last value from StreamController generic.
      // Wait! We can just track specific target index in _spin();
      // Refactoring _spin slightly.
  }

  Future<void> _askAGenie() async {
      setState(() => _isThinking = true);
      try {
           final supabase = Supabase.instance.client;
           final response = await supabase.functions.invoke('ai-assistant', body: {
               'action': 'suggest_poll_options',
               'payload': { 'question': 'Opciones divertidas para tomar una decisión en grupo', 'location': 'general' }
           });
           
           final List<dynamic> suggestions = response.data;
           if (mounted) {
               setState(() {
                   for (var s in suggestions) _options.add(s.toString());
               });
           }
      } catch (e) {
           if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("El genio está ocupado.")));
      } finally {
           if(mounted) setState(() => _isThinking = false);
      }
  }

  Future<void> _postToChat(String winner) async {
       try {
           final chatService = ChatService();
           await chatService.sendMessage(
               widget.planId, 
               "🎲 La ruleta ha hablado: $winner",
               type: 'roulette', 
               metadata: {
                   'winner': winner,
                   'options': _options
               }
           );
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Publicado en el chat")));
       } catch (e) {
           // Error handling
       }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        scrollable: true,
        title: Row(children: [
            Text(_isReplay ? "🔄 Repetición" : "🎡 Ruleta de la Suerte"), 
            const Spacer(), 
            const CloseButton()
        ]),
        content: SizedBox(
            width: 300,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                    SizedBox(
                        height: 300,
                        child: _options.length < 2 
                        ? Center(child: Text(_isReplay ? "Datos insuficientes" : "Agrega al menos 2 opciones", style: const TextStyle(color: Colors.grey)))
                        : FortuneWheel(
                            selected: _selectedController.stream,
                            animateFirst: false,
                            onAnimationEnd: () {
                                setState(() => _isSpinning = false);
                                // We need the index. Let's assume we store it or find it.
                                // Actually, getting the current value from a Stream is tricky without caching.
                                // Improvement: Keep track of targetIndex in state.
                            },
                            items: [
                                for (var option in _options)
                                    FortuneItem(
                                        child: Text(option, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        style: FortuneItemStyle(
                                            color: _options.indexOf(option) % 2 == 0 ? AppTheme.primaryBrand : AppTheme.secondaryBrand,
                                            borderColor: Colors.white,
                                            borderWidth: 2
                                        )
                                    ),
                            ],
                        ),
                    ),
                    const SizedBox(height: 16),
                    
                    if (!_isReplay) ...[
                        if (_options.isEmpty)
                             ElevatedButton.icon(
                                 onPressed: _isThinking ? null : _askAGenie, 
                                 icon: _isThinking ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
                                 label: const Text("Sugerencias IA")
                             ),
                        
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
                    ] else ...[
                        Text("Ganador: ${widget.replayWinner ?? ''}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.secondaryBrand))
                    ]
                ],
            ),
        ),
        actions: [
            if (!_isReplay)
                ElevatedButton(
                    onPressed: _options.length < 2 || _isSpinning ? null : () {
                        final index = Fortune.randomInt(0, _options.length);
                        _selectedController.add(index);
                        setState(() {
                            _isSpinning = true;
                            _finalResult = _options[index]; // Lock in result
                        });
                        
                        // Delay execution of "Post" prompt until animation ends
                        Future.delayed(const Duration(seconds: 5), () async {
                             setState(() => _isSpinning = false);
                             widget.onSpinComplete(_finalResult!);
                             
                             // Ask to share
                             if (mounted) {
                                 final share = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
                                     title: Text("¡Ganador: $_finalResult!"),
                                     content: const Text("¿Publicar resultado en el chat?"),
                                     actions: [
                                         TextButton(onPressed: ()=>Navigator.pop(c, false), child: const Text("Solo cerrar")),
                                         ElevatedButton(onPressed: ()=>Navigator.pop(c, true), child: const Text("Publicar"))
                                     ],
                                 ));
                                 
                                 if (share == true) {
                                     _postToChat(_finalResult!);
                                     if(mounted) Navigator.pop(context);
                                 }
                             }
                        });
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBrand, foregroundColor: Colors.white),
                    child: Text(_isSpinning ? "Girando..." : "¡GIRAR!"),
                )
        ],
    );
  }
}
