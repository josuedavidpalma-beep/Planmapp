import 'package:flutter/material.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/core/widgets/auth_guard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/core/services/chat_service.dart';
import 'package:planmapp/features/itinerary/presentation/widgets/simple_plan_header.dart';
import 'package:planmapp/features/plans/domain/models/plan_model.dart';
import 'package:planmapp/core/services/plan_service.dart';
import 'package:intl/intl.dart';
import 'package:planmapp/features/itinerary/domain/services/ai_itinerary_service.dart';

class ItineraryPlanTab extends StatefulWidget {
  final String planId;
  final String userRole; // 'admin', 'treasurer', 'member'
  final DateTime? planDate;

  const ItineraryPlanTab({super.key, required this.planId, required this.userRole, required this.planDate});

  @override
  State<ItineraryPlanTab> createState() => _ItineraryPlanTabState();
}

class _ItineraryPlanTabState extends State<ItineraryPlanTab> {
  Plan? _plan;
  bool _isLoading = true;
  bool _isGeneratingAI = false;
  RealtimeChannel? _planSubscription;

  @override
  void initState() {
    super.initState();
    _loadPlan();
    _subscribeToPlanChanges();
  }

  @override
  void dispose() {
      _planSubscription?.unsubscribe();
      super.dispose();
  }

  void _subscribeToPlanChanges() {
      _planSubscription = Supabase.instance.client
          .channel('public:plans:id=eq.${widget.planId}')
          .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'plans',
              filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: widget.planId),
              callback: (payload) {
                  _loadPlan();
              }
          )
          .subscribe();
  }

  Future<void> _loadPlan() async {
      try {
          final p = await PlanService().getPlanById(widget.planId);
          if (mounted && p != null) setState(() => _plan = p);
      } catch (_) {}
      if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _plan == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
                if (_canEdit() && _plan != null) ...[
                    if (_plan!.itinerarySteps.isEmpty && !_isGeneratingAI)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: FloatingActionButton.extended(
                                heroTag: "aiBtn",
                                backgroundColor: Colors.amber, // Magic Color
                                icon: const Icon(Icons.auto_awesome, color: Colors.black),
                                label: const Text("Auto-Armar", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                onPressed: () => _generateAIItinerary(),
                            ),
                        ),
                    FloatingActionButton.extended(
                        heroTag: "finalizeBtn",
                        backgroundColor: AppTheme.secondaryBrand,
                        icon: const Icon(Icons.verified, color: Colors.black),
                        label: const Text("Confirmar Plan", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        onPressed: () => _finalizePlan(),
                    ),
                ], 
            ], 
        ),
        body: SingleChildScrollView(
            child: Column(
                children: [
                    if (_plan != null)
                         SimplePlanHeader(
                             plan: _plan!,
                             canEdit: _canEdit(),
                             onEditDate: () => _updatePlanDate(context),
                             onEditTime: () => _updatePlanTime(context), // NEW
                             onEditLocation: () => _updatePlanLocation(context),
                             onPaymentModeChanged: _updatePaymentMode,
                             onEditDescription: () => _updatePlanDescription(context),
                         ),
                    if (_plan != null && _plan!.itinerarySteps.isNotEmpty)
                         Padding(
                             padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                             child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                     const Text("Crono-Itinerario", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                     const SizedBox(height: 16),
                                     ...List.generate(_plan!.itinerarySteps.length, (index) => _buildItineraryStepCard(_plan!.itinerarySteps[index], index)),
                                     if (_canEdit())
                                         Center(
                                             child: TextButton.icon(
                                                 icon: const Icon(Icons.add_circle_outline),
                                                 label: const Text("Añadir paso manualmente"),
                                                 onPressed: _addManualStep,
                                             )
                                         ),
                                     const SizedBox(height: 80), // Fab space
                                 ],
                             ),
                         )
                    else if (_isLoading || _isGeneratingAI)
                         const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
                    else if (_plan != null)
                         Padding(
                             padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                             child: Column(
                                 children: [
                                     const Icon(Icons.list_alt, size: 48, color: Colors.grey),
                                     const SizedBox(height: 16),
                                     const Text("Itinerario Vacío", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                     const SizedBox(height: 8),
                                     const Text("Aún no han organizado los pasos de este plan.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                                     if (_canEdit()) ...[
                                         const SizedBox(height: 24),
                                         const Text("👇 Toca 'Auto-Armar' para que la IA lo construya mágicamente.", textAlign: TextAlign.center, style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                                     ]
                                 ],
                             ),
                         )
                ],
            ),
        ),
    );
  }

  Widget _buildItineraryStepCard(Map<String, dynamic> step, int index) {
      return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              border: Border.all(color: AppTheme.primaryBrand.withOpacity(0.2))
          ),
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: AppTheme.primaryBrand.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                      child: Text(step['time'] ?? '--:--', style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primaryBrand)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              Text(step['title'] ?? 'Paso', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 6),
                              Text(step['description'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4)),
                          ],
                      )
                  ),
                  if (_canEdit())
                      IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
                          onPressed: () => _editItineraryStep(index, step),
                      )
              ],
          ),
      );
  }

  Future<void> _addManualStep() async {
      await _editItineraryStep(-1, {'time': '12:00 PM', 'title': '', 'description': ''});
  }

  Future<void> _editItineraryStep(int index, Map<String, dynamic> step) async {
      final timeCtrl = TextEditingController(text: step['time'] ?? '');
      final titleCtrl = TextEditingController(text: step['title'] ?? '');
      final descCtrl = TextEditingController(text: step['description'] ?? '');

      final result = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
              title: Text(index == -1 ? "Añadir Paso" : "Editar Paso"),
              content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      TextField(controller: timeCtrl, decoration: const InputDecoration(labelText: "Hora (ej. 10:00 AM)")),
                      TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Título")),
                      TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Descripción"), maxLines: 3),
                  ]
              ),
              actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
                  if (index != -1)
                      TextButton(
                          onPressed: () async {
                              final steps = List<Map<String, dynamic>>.from(_plan!.itinerarySteps);
                              steps.removeAt(index);
                              try {
                                  await Supabase.instance.client.from('plans').update({'itinerary_steps': steps}).eq('id', widget.planId);
                                  if (mounted) { Navigator.pop(c, false); _loadPlan(); }
                              } catch (_) {}
                          }, 
                          child: const Text("Eliminar", style: TextStyle(color: Colors.red))
                      ),
                  ElevatedButton(
                      onPressed: () {
                          Navigator.pop(c, true);
                      }, 
                      child: const Text("Guardar")
                  ),
              ]
          )
      );

      if (result == true) {
          final steps = List<Map<String, dynamic>>.from(_plan!.itinerarySteps);
          final newStep = {
              'time': timeCtrl.text,
              'title': titleCtrl.text,
              'description': descCtrl.text,
          };
          
          if (index == -1) {
              steps.add(newStep);
          } else {
              steps[index] = newStep;
          }
          
          try {
              await Supabase.instance.client.from('plans').update({'itinerary_steps': steps}).eq('id', widget.planId);
              _loadPlan();
          } catch (_) {}
      }
  }

  Future<void> _generateAIItinerary() async {
      if (_plan == null) return;
      setState(() => _isGeneratingAI = true);
      try {
          final ai = AiItineraryService();
          final genericSteps = await ai.generateItinerary(_plan!);
          
          if (genericSteps.isNotEmpty) {
              await Supabase.instance.client.from('plans').update({
                   'itinerary_steps': genericSteps
              }).eq('id', widget.planId);
              
              await _loadPlan();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✨ Itinerario generado con éxito!")));
          }
      } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error de IA: $e")));
      }
      if (mounted) setState(() => _isGeneratingAI = false);
  }

  bool _canEdit() {
      return widget.userRole == 'admin' || widget.userRole == 'treasurer';
  }

  Future<void> _finalizePlan() async {
      final date = widget.planDate != null ? DateFormat('EEE d MMM', 'es_CO').format(widget.planDate!) : "Fecha pendiente";
      String location = _plan?.locationName ?? "Por definir";

      final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
          title: const Text("¿Finalizar y Enviar?"),
          content: const Text("Se enviará una tarjeta de 'Confirmación Final' al chat para que todos confirmen su asistencia."),
          actions: [
              TextButton(onPressed: ()=>Navigator.pop(c, false), child: const Text("Cancelar")),
              ElevatedButton(onPressed: ()=>Navigator.pop(c, true), child: const Text("Enviar"))
          ],
      ));

      if (confirm == true) {
           try {
               final chat = ChatService();
               await chat.sendMessage(
                   widget.planId, 
                   "Plan Finalizado: $date en $location", 
                   type: 'final_confirmation',
                   metadata: {
                       'title': 'Plan Finalizado',
                       'date': widget.planDate?.toIso8601String(),
                       'location': location,
                       'notes': 'Por favor confirmen asistencia para organizar reservas.'
                   }
               );
               if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Plan enviado al chat ✅")));
           } catch (e) {
               if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
           }
      }
  }

  Future<void> _updatePlanDate(BuildContext context) async {
       final date = await showDatePicker(
            context: context, 
            initialDate: widget.planDate ?? DateTime.now(), 
            firstDate: DateTime.now(), 
            lastDate: DateTime.now().add(const Duration(days: 365))
       );
       if (date != null) {
           // Preserve time if exists
           final time = widget.planDate != null ? TimeOfDay.fromDateTime(widget.planDate!) : const TimeOfDay(hour: 0, minute: 0);
           final newDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);

           try {
               await Supabase.instance.client.from('plans').update({
                   'event_date': newDateTime.toIso8601String()
               }).eq('id', widget.planId);
               _loadPlan();
           } catch(e) {
               if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
           }
       }
  }

  Future<void> _updatePlanTime(BuildContext context) async {
       final time = await showTimePicker(
           context: context, 
           initialTime: widget.planDate != null ? TimeOfDay.fromDateTime(widget.planDate!) : TimeOfDay.now()
       );

       if (time != null) {
           final baseDate = widget.planDate ?? DateTime.now();
           final newDateTime = DateTime(baseDate.year, baseDate.month, baseDate.day, time.hour, time.minute);
           
           try {
               await Supabase.instance.client.from('plans').update({
                   'event_date': newDateTime.toIso8601String()
               }).eq('id', widget.planId);
               _loadPlan();
           } catch(e) {
               if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
           }
       }
  }

  Future<void> _updatePlanLocation(BuildContext context) async {
      final controller = TextEditingController(text: _plan?.locationName);
      final newLoc = await showDialog<String>(
          context: context,
          builder: (c) => AlertDialog(
              title: const Text("Editar Lugar Principal"),
              content: TextField(controller: controller, decoration: const InputDecoration(labelText: "Lugar")),
              actions: [
                  TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Cancelar")),
                  ElevatedButton(onPressed: ()=>Navigator.pop(c, controller.text), child: const Text("Guardar"))
              ],
          )
      );

      if (newLoc != null && newLoc.isNotEmpty) {
           try {
               await Supabase.instance.client.from('plans').update({
                   'location_name': newLoc
               }).eq('id', widget.planId);
               _loadPlan();
           } catch(e) {
               if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
           }
      }
  }

  Future<void> _updatePaymentMode(String mode) async {
       try {
           await Supabase.instance.client.from('plans').update({
               'payment_mode': mode
           }).eq('id', widget.planId);
           _loadPlan();
           if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Modo de pago actualizado")));
       } catch(e) {
           if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
       }
  }

  Future<void> _updatePlanDescription(BuildContext context) async {
      final controller = TextEditingController(text: _plan?.description);
      final newDesc = await showDialog<String>(
          context: context,
          builder: (c) => AlertDialog(
              title: const Text("Editar Observaciones"),
              content: TextField(
                  controller: controller, 
                  maxLines: 5,
                  decoration: const InputDecoration(
                      labelText: "Acuerdos y notas",
                      hintText: "Escribe aquí las decisiones del grupo...",
                      border: OutlineInputBorder()
                  )
              ),
              actions: [
                  TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Cancelar")),
                  ElevatedButton(onPressed: ()=>Navigator.pop(c, controller.text), child: const Text("Guardar"))
              ],
          )
      );

      if (newDesc != null) {
           try {
               await Supabase.instance.client.from('plans').update({
                   'description': newDesc
               }).eq('id', widget.planId);
               _loadPlan();
           } catch(e) {
               if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
           }
      }
  }
}
