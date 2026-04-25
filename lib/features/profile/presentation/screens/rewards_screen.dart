import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({Key? key}) : super(key: key);

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _rewards = [];

  @override
  void initState() {
    super.initState();
    _fetchRewards();
  }

  Future<void> _fetchRewards() async {
      try {
          final sup = Supabase.instance.client;
          final uid = sup.auth.currentUser?.id;
          if (uid == null) return;
          
          final res = await sup.from('restaurant_rewards').select('*, restaurants(name)').eq('user_id', uid).order('created_at', ascending: false);
          
          if (mounted) {
              setState(() {
                  _rewards = List<Map<String, dynamic>>.from(res);
                  _isLoading = false;
              });
          }
      } catch(e) {
          if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error cargando cupones: $e")));
              setState(() => _isLoading = false);
          }
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppTheme.darkBackground,
        appBar: AppBar(
            backgroundColor: AppTheme.darkBackground,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text("Mis Recompensas", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: _isLoading 
            ? const Center(child: CircularProgressIndicator()) 
            : _rewards.isEmpty 
               ? const Center(child: Text("Aún no tienes recompensas. Asiste a planes y obtén cupones.", style: TextStyle(color: Colors.grey)))
               : ListView.builder(
                   padding: const EdgeInsets.all(16),
                   itemCount: _rewards.length,
                   itemBuilder: (c, i) {
                       final r = _rewards[i];
                       final isRedeemed = r['is_redeemed'] == true;
                       final isExpired = DateTime.parse(r['expires_at']).isBefore(DateTime.now());
                       final restName = r['restaurants']?['name'] ?? 'Restaurante';
                       
                       Color statusColor = Colors.green;
                       String statusText = "VÁLIDO";
                       
                       if (isRedeemed) {
                           statusColor = Colors.grey;
                           statusText = "USADO";
                       } else if (isExpired) {
                           statusColor = Colors.red;
                           statusText = "EXPIRADO";
                       }
                       
                       return Container(
                           margin: const EdgeInsets.only(bottom: 16),
                           padding: const EdgeInsets.all(16),
                           decoration: BoxDecoration(
                               gradient: LinearGradient(colors: isRedeemed || isExpired ? [Colors.grey.shade900, Colors.black87] : [Colors.indigo.shade900, Colors.purple.shade900]),
                               borderRadius: BorderRadius.circular(16),
                               border: Border.all(color: statusColor.withOpacity(0.5))
                           ),
                           child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                   Row(
                                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                       children: [
                                           Text(restName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                           Container(
                                               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                               decoration: BoxDecoration(color: statusColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                                               child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
                                           )
                                       ]
                                   ),
                                   const SizedBox(height: 12),
                                   Row(
                                       children: [
                                           Text("${r['discount_percentage']}%", style: const TextStyle(color: AppTheme.primaryBrand, fontSize: 32, fontWeight: FontWeight.bold)),
                                           const SizedBox(width: 12),
                                           Column(
                                               crossAxisAlignment: CrossAxisAlignment.start,
                                               children: [
                                                   const Text("Código Único:", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                                   SelectableText(r['promo_code'], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
                                               ]
                                           ),
                                           const Spacer(),
                                           if (!isRedeemed && !isExpired)
                                               IconButton(
                                                   icon: const Icon(Icons.copy, color: Colors.white),
                                                   onPressed: () {
                                                      Clipboard.setData(ClipboardData(text: r['promo_code']));
                                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Código copiado!")));
                                                   }
                                               )
                                       ]
                                   )
                               ]
                           )
                       );
                   }
               )
    );
  }
}
