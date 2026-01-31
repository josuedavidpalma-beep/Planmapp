import 'package:flutter/material.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/core/widgets/auth_guard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/core/services/chat_service.dart';
import 'package:planmapp/features/itinerary/presentation/widgets/simple_plan_header.dart';
import 'package:planmapp/features/plans/domain/models/plan_model.dart';
import 'package:planmapp/core/services/plan_service.dart';
import 'package:intl/intl.dart';

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
                if (_canEdit()) ...[
                    FloatingActionButton.extended(
                        heroTag: "finalizeBtn",
                        backgroundColor: AppTheme.secondaryBrand,
                        icon: const Icon(Icons.verified, color: Colors.black),
                        label: const Text("Finalizar Plan", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        onPressed: () => _finalizePlan(),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton(
                        heroTag: "addBtn",
                        backgroundColor: AppTheme.primaryBrand,
                        child: const Icon(Icons.note_add, color: Colors.white), 
                        onPressed: () async {
                            if (await AuthGuard.ensureAuthenticated(context)) {
                                _updatePlanDescription(context); 
                            }
                        },
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
                ],
            ),
        ),
    );
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
