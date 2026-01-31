import 'package:flutter/material.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/plans/domain/models/plan_model.dart';
import 'package:planmapp/features/social/services/social_feed_service.dart';
import 'package:planmapp/features/social/presentation/widgets/feed_plan_card.dart';
import 'package:go_router/go_router.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final _feedService = SocialFeedService();
  List<Plan> _feed = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    if(!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    
    try {
      final plans = await _feedService.getFriendsPlans();
      if(mounted) {
        setState(() {
          _feed = plans;
          _isLoading = false;
        });
      }
    } catch (e) {
      if(mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Error en el muro: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Comunidad", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {
             // Search Global?
          })
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
     if (_isLoading) return const Center(child: CircularProgressIndicator());
     
     if (_errorMessage != null) {
        return Center(
           child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                Text(_errorMessage!),
                TextButton(onPressed: _loadFeed, child: const Text("Reintentar"))
             ],
           )
        );
     }

     if (_feed.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.diversity_3_rounded, size: 80, color: Colors.indigo.shade100),
                const SizedBox(height: 16),
                const Text("Tu Muro está tranquilo", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text("Parece que tus amigos no han publicado planes públicos recientemente.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                ElevatedButton(
                    onPressed: () => context.push('/friends'), // Go to friends to add more
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBrand, foregroundColor: Colors.white),
                    child: const Text("Buscar nuevos amigos")
                )
              ],
            ),
          ),
        );
     }

     return RefreshIndicator(
       onRefresh: _loadFeed,
       child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _feed.length,
          separatorBuilder: (_,__) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
             final plan = _feed[index];
             return FeedPlanCard(
               plan: plan,
               onTap: () => context.push('/plan/${plan.id}'),
             );
          },
       ),
     );
  }
}
