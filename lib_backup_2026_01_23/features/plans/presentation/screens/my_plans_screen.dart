import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planmapp/core/theme/theme_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/plans/domain/models/plan_model.dart';
import 'package:intl/intl.dart';

import 'package:planmapp/core/services/plan_service.dart';
import 'package:planmapp/core/presentation/widgets/glass_container.dart';
import 'package:planmapp/core/presentation/widgets/bouncy_button.dart';
import 'package:planmapp/core/presentation/widgets/skeleton_helper.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/features/plans/services/plan_members_service.dart';

class MyPlansScreen extends ConsumerStatefulWidget {
  const MyPlansScreen({super.key});

  @override
  ConsumerState<MyPlansScreen> createState() => _MyPlansScreenState();
}

class _MyPlansScreenState extends ConsumerState<MyPlansScreen> {
  List<Plan> _plans = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    if (!mounted) return;
    setState(() {
       _isLoading = true;
       _errorMessage = null; 
    });
    
    try {
      // Add artificial delay ensuring spinner shows at least briefly for UX (optional but nice)
      // await Future.delayed(const Duration(milliseconds: 300)); 
      
      final plans = await PlanService().getPlans();
      if (mounted) {
        setState(() {
          _plans = plans;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
           _isLoading = false;
           // Friendly error message
           _errorMessage = "Problema al cargar: ${e.toString()}";
           debugPrint("Error loading plans: $e");
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Mis Planes", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
           if (_errorMessage != null)
             IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPlans)
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
             begin: Alignment.topCenter, end: Alignment.bottomCenter,
             colors: [Theme.of(context).scaffoldBackgroundColor, Theme.of(context).cardColor.withOpacity(0.5)]
          )
        ),
        child: _isLoading 
            ? _buildLoadingState() 
            : _errorMessage != null 
                ? _buildErrorState()
                : _plans.isEmpty ? _buildEmptyState() : _buildPlanList(context, _plans),
      ),
    );
  }

  Widget _buildErrorState() {
      return Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                  Icon(Icons.cloud_off, size: 64, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(_errorMessage ?? "Error desconocido", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[800], fontSize: 16)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                      onPressed: _loadPlans,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Intentar de nuevo"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBrand,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                      ),
                  )
               ],
            ),
          )
      );
  }

  Widget _buildLoadingState() {
     return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        separatorBuilder: (_,__) => const SizedBox(height: 16),
        itemBuilder: (_,__) => SkeletonHelper.planCardSkeleton(),
     );
  }

  Widget _buildEmptyState() {
     return Center(
        child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
              Icon(Icons.map_outlined, size: 80, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text("No tienes planes activos", style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("¡Usa el botón central para empezar!", style: TextStyle(color: Colors.grey)),
           ],
        )
     );
  }
  Widget _buildPlanList(BuildContext context, List<Plan> plans) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: plans.length,
      itemBuilder: (context, index) {
        final plan = plans[index];
        return _PlanCard(
            plan: plan, 
            onRefresh: _loadPlans
        )
            .animate(delay: (100 * index).ms) 
            .slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOutQuad)
            .fade(duration: 400.ms);
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Plan plan;
  final VoidCallback onRefresh;

  const _PlanCard({required this.plan, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () => context.push('/plan/${plan.id}'),
        onLongPress: () => _showOptions(context),
        child: GlassContainer(
          borderRadius: BorderRadius.circular(24),
          blur: 15,
          opacity: 0.6, 
          color: Theme.of(context).cardColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20), // Reduced horizontal slightly
          child: LayoutBuilder(
            builder: (context, constraints) {
               // Prevent negative constraints if width is extremely small
               if (constraints.maxWidth < 0) return const SizedBox(); 
               
               return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                children: [
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                     decoration: BoxDecoration(
                        color: AppTheme.primaryBrand.withOpacity(0.1), 
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryBrand.withOpacity(0.2)),
                     ),
                     child: Text(
                       plan.status.name.toUpperCase(),
                       style: const TextStyle(
                         color: AppTheme.primaryBrand,
                         fontWeight: FontWeight.w800,
                         fontSize: 10,
                         letterSpacing: 0.5
                       ),
                     ),
                   ),
                   const Spacer(),
                   Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Theme.of(context).cardColor, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]
                      ),
                      child: Icon(Icons.more_vert, size: 12, color: Theme.of(context).iconTheme.color)
                   )
                ],
              ),
              const SizedBox(height: 16),
              Text(
                plan.title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: -0.5,
                  color: Theme.of(context).textTheme.bodyLarge?.color
                ),
              ),
              const SizedBox(height: 8),
               // Date & Location Row
               Row(
                 children: [
                    const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d').format(plan.eventDate),
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                         children: [
                            const Icon(Icons.location_on_rounded, size: 14, color: AppTheme.secondaryBrand),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                plan.locationName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                         ],
                      ),
                    )
                 ],
               ),
              const SizedBox(height: 20),
              
              // Bottom Action Area
              Row(
                children: [
                  _buildAvatarStack(plan.participantCount),
                  const Spacer(),
                  Text(
                    DateFormat('h:mm a').format(plan.eventDate).toLowerCase(),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
                  ),
                ],
              ),
                ],
              );
            }
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      final isCreator = uid == plan.creatorId;

      showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 24),
                      Text(plan.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      
                      ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          tileColor: Colors.red.withOpacity(0.1),
                          leading: Icon(isCreator ? Icons.delete_outline : Icons.exit_to_app, color: Colors.red),
                          title: Text(isCreator ? "Eliminar Plan" : "Salir del Plan", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          onTap: () async {
                              final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
                                  title: Text(isCreator ? "¿Eliminar este plan?" : "¿Salir del plan?"),
                                  content: Text(isCreator 
                                    ? "Esta acción no se puede deshacer. Se borrarán todos los datos, chats y gastos." 
                                    : "Ya no tendrás acceso al chat ni a los gastos compartido."),
                                  actions: [
                                      TextButton(onPressed: ()=>Navigator.pop(c, false), child: const Text("Cancelar")),
                                      TextButton(onPressed: ()=>Navigator.pop(c, true), child: const Text("Confirmar", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                                  ],
                              ));

                              if (confirm == true) {
                                  if (context.mounted) Navigator.pop(context); // Close sheet
                                  try {
                                      if (isCreator) {
                                          await PlanService().deletePlan(plan.id);
                                          if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Plan eliminado")));
                                      } else {
                                          await PlanMembersService().leavePlan(plan.id);
                                          if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saliste del plan")));
                                      }
                                      onRefresh(); // Refresh list
                                  } catch (e) {
                                      if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                                  }
                              }
                          },
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          leading: const Icon(Icons.close),
                          title: const Text("Cancelar"),
                          onTap: () => Navigator.pop(context),
                      ),
                  ],
              ),
          )
      );
  }

  Widget _buildAvatarStack(int count) {
    return Row(
      children: [
        for (int i = 0; i < 3; i++)
          Align(
            widthFactor: 0.7,
            child: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Colors.grey[300],
                child: const Icon(Icons.person, size: 16, color: Colors.white),
              ),
            ),
          ),
        if (count > 3)
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(
              "+${count - 3}",
              style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
} // End of file
