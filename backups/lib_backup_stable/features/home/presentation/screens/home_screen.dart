import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/plans/domain/models/plan_model.dart';
import 'package:intl/intl.dart';

import 'package:planmapp/core/services/plan_service.dart';
import 'package:planmapp/core/presentation/widgets/glass_container.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Plan>> _plansFuture;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  void _loadPlans() {
    _plansFuture = PlanService().getPlans();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Mis Planes (Live)", // Visual marker to confirm update
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
             onPressed: () {
               setState(() {
                 _loadPlans();
               });
             },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: InkWell(
              onTap: () => context.push('/profile'),
              borderRadius: BorderRadius.circular(20),
              child: const CircleAvatar(
                backgroundColor: AppTheme.secondaryBrand,
                child: Text("J", style: TextStyle(color: Colors.black)),
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Plan>>(
        future: _plansFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
             return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState(context);
          } else {
            return _buildPlanList(context, snapshot.data!);
          }
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Navigate to Create Plan Wizard and reload on return
          await context.push('/create-plan');
          setState(() {
            _loadPlans();
          });
        },
        backgroundColor: AppTheme.primaryBrand,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Nuevo Plan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
               padding: const EdgeInsets.all(24),
               decoration: BoxDecoration(
                  color: AppTheme.primaryBrand.withOpacity(0.1),
                  shape: BoxShape.circle,
               ),
               child: Icon(Icons.rocket_launch_rounded, size: 72, color: AppTheme.primaryBrand.withOpacity(0.8)),
            ),
            const SizedBox(height: 32),
            Text(
              "¡Tu agenda está libre!",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              "Crea un plan y empieza a organizar esa salida que tanto quieren.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => context.push('/create-plan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBrand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 4,
                shadowColor: AppTheme.primaryBrand.withOpacity(0.4),
              ),
              child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                       Text("Crear mi primer Plan ✨", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ]
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanList(BuildContext context, List<Plan> plans) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: plans.length,
      itemBuilder: (context, index) {
        final plan = plans[index];
        return _PlanCard(plan: plan);
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Plan plan;

  const _PlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () => context.push('/plan/${plan.id}'),
        child: GlassContainer(
          borderRadius: BorderRadius.circular(24),
          blur: 15,
          opacity: 0.6, // Semi-transparent white
          color: Colors.white,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                     decoration: BoxDecoration(
                        color: AppTheme.primaryBrand.withOpacity(0.1), // Subtle tint
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
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]
                      ),
                      child: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.black54)
                   )
                ],
              ),
              const SizedBox(height: 16),
              Text(
                plan.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: -0.5,
                  color: Colors.black87
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
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54),
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
                                style: const TextStyle(color: Colors.black54),
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
              "+${count - 3} más",
              style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
}
