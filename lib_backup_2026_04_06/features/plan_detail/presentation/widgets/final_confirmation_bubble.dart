import 'package:flutter/material.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/plan_detail/domain/models/message_model.dart';
import 'package:planmapp/core/services/plan_service.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class FinalConfirmationBubble extends StatefulWidget {
  final Message message;
  final bool isMe;
  final VoidCallback? onViewItinerary;

  const FinalConfirmationBubble({
      super.key, 
      required this.message, 
      required this.isMe,
      this.onViewItinerary
  });

  @override
  State<FinalConfirmationBubble> createState() => _FinalConfirmationBubbleState();
}

class _FinalConfirmationBubbleState extends State<FinalConfirmationBubble> {
  bool _responded = false;
  bool _isAttending = false;

  Future<void> _handleDecline(BuildContext context) async {
      final shouldLeave = await showDialog<bool>(
          context: context, 
          builder: (c) => AlertDialog(
              title: const Text("😕 ¿No podrás asistir?"),
              content: const Text(
                  "Es una lástima que no puedas venir.\n\n"
                  "Para ayudar al grupo con la logística (reservas, cupos en autos, compras), "
                  "¿te gustaría salir del grupo del plan?\n\n"
                  "Esto evitará que te cuenten para gastos y espacios."
              ),
              actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text("Me quedo de espectador")
                  ),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text("Salir del Plan"),
                  )
              ],
          )
      );

      if (shouldLeave == true && mounted) {
           try {
               await PlanService().leavePlan(widget.message.planId);
               if (mounted) {
                   context.pop(); // Go back to Home
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Has salido del plan correctamente.")));
               }
           } catch (e) {
               if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
           }
      } else {
           // User declined but stays in group -> Set status to 'declined'
           try {
               await PlanService().updateMemberStatus(widget.message.planId, 'declined');
           } catch (_) {}
           
           setState(() {
              _responded = true;
              _isAttending = false;
          });
      }
  }

  Future<void> _handleConfirm() async {
      setState(() {
          _responded = true;
          _isAttending = true;
      });
      
      try {
          await PlanService().updateMemberStatus(widget.message.planId, 'accepted');
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Genial! Asistencia confirmada 🎉")));
          }
      } catch (e) {
          // Revert if failed (optimistic UI)
           setState(() {
              _responded = false;
              _isAttending = false;
          });
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al confirmar: $e")));
      }
  }

  @override
  Widget build(BuildContext context) {
    final metadata = widget.message.metadata ?? {};
    final title = metadata['title'] ?? 'Evento Final';
    final location = metadata['location'] ?? 'Ubicación por definir';
    final dateStr = metadata['date'];
    final notes = metadata['notes'];
    
    DateTime? eventDate;
    if (dateStr != null) eventDate = DateTime.tryParse(dateStr);

    return Align(
      alignment: Alignment.center, // Always center this crucial card
      child: Container(
        width: 300, // Wider
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primaryBrand, width: 2),
          boxShadow: [
             BoxShadow(color: AppTheme.primaryBrand.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))
          ]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
              // Header
              Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                      color: AppTheme.primaryBrand,
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18))
                  ),
                  child: Row(
                      children: [
                          const Icon(Icons.flight_takeoff, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2))),
                      ],
                  ),
              ),
              
              // Body
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          // Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                          // const SizedBox(height: 8),
                          Row(children: [
                              const Icon(Icons.calendar_today, size: 16, color: Colors.purple),
                              const SizedBox(width: 8),
                              Text(eventDate != null ? DateFormat('EEEE d MMM', 'es_CO').format(eventDate) : "Fecha por definir", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))
                          ]),
                          const SizedBox(height: 12),
                          Row(children: [
                              const Icon(Icons.place, size: 16, color: Colors.blue),
                              const SizedBox(width: 8),
                              Expanded(child: Text(location, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15)))
                          ]),
                          const SizedBox(height: 12),
                          // Payment Mode Display
                          if (metadata['payment_mode'] != null)
                             Container(
                                 padding: const EdgeInsets.all(8),
                                 decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                                 child: Row(
                                     children: [
                                         Icon(Icons.monetization_on, size: 16, color: Colors.green[700]),
                                         const SizedBox(width: 8),
                                         Text(_getPaymentLabel(metadata['payment_mode']), style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold, fontSize: 13))
                                     ],
                                 ),
                             ),
                          if (notes != null && notes.toString().isNotEmpty) ...[
                              const Divider(height: 24),
                              const Text("Observaciones:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              Text(notes, style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black54)),
                          ],

                          // VIEW ITINERARY BUTTON
                          if (widget.onViewItinerary != null) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                      onPressed: widget.onViewItinerary,
                                      icon: const Icon(Icons.receipt_long, size: 18),
                                      label: const Text("Ver Itinerario Completo"),
                                      style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.black87,
                                          side: BorderSide(color: Colors.grey.shade300)
                                      ),
                                  ),
                              )
                          ]
                      ],
                  ),
              ),

              // Actions
              if (!_responded)
                  Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                          children: [
                              Expanded(
                                  child: OutlinedButton(
                                      onPressed: () => _handleDecline(context),
                                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                      child: const Text("No puedo ir"),
                                  )
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: ElevatedButton(
                                      onPressed: _handleConfirm,
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                      child: const Text("¡Voy!"),
                                  )
                              ),
                          ],
                      ),
                  )
              else
                  Container(
                      padding: const EdgeInsets.all(12),
                      color: _isAttending ? Colors.green[50] : Colors.red[50],
                      alignment: Alignment.center,
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                              Icon(_isAttending ? Icons.check_circle : Icons.cancel, color: _isAttending ? Colors.green : Colors.red),
                              const SizedBox(width: 8),
                              Text(
                                  _isAttending ? "Asistencia Confirmada" : "No asistirás",
                                  style: TextStyle(fontWeight: FontWeight.bold, color: _isAttending ? Colors.green[800] : Colors.red[800])
                              )
                          ],
                      ),
                  )
          ],
        ),
      ),
    );
  }
  
  String _getPaymentLabel(String mode) {
      switch(mode) {
          case 'pool': return "Hacemos Vaca (Pool)";
          case 'guest': return "Invitado (Todo pago)";
          case 'split': return "Dividimos cuentas";
          case 'individual': default: return "Cada uno paga lo suyo";
      }
  }
}
