import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class OnboardingSetupScreen extends StatefulWidget {
  const OnboardingSetupScreen({super.key});

  @override
  State<OnboardingSetupScreen> createState() => _OnboardingSetupScreenState();
}

class _OnboardingSetupScreenState extends State<OnboardingSetupScreen> {
  final _nicknameController = TextEditingController();
  DateTime _birthDate = DateTime(2000, 1, 1);
  String _budget = 'bacano'; // 'economico', 'bacano', 'play'
  final Set<String> _interests = {};
  bool _isLoading = false;
  int _currentPage = 0;
  final PageController _pageController = PageController();

  static const _budgetOptions = [
    {'key': 'economico', 'label': 'Económico', 'icon': '💰', 'desc': 'Planes sin gastar mucho'},
    {'key': 'bacano',    'label': 'Bacano',     'icon': '🎉', 'desc': 'Disfruto bien gastando lo justo'},
    {'key': 'play',      'label': 'Play',       'icon': '💎', 'desc': 'Sin límites, a disfrutar'},
  ];

  static const _interestOptions = [
    {'key': 'gastronomia',    'label': 'Gastronomía',    'emoji': '🍔'},
    {'key': 'vida_nocturna', 'label': 'Vida Nocturna', 'emoji': '🍹'},
    {'key': 'deporte',       'label': 'Deporte',        'emoji': '🏃‍♂️'},
    {'key': 'cultura',       'label': 'Cultura',        'emoji': '🎬'},
    {'key': 'aventura',      'label': 'Aventura',       'emoji': '🌴'},
    {'key': 'chill',         'label': 'Chill',          'emoji': '🏠'},
  ];

  Future<void> _saveProfile() async {
    if (_nicknameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ponle un apodo a tu perfil 😉')),
      );
      return;
    }
    if (_interests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elige al menos un interés')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'nickname': _nicknameController.text.trim(),
          'display_name': _nicknameController.text.trim(),
          'birth_date': _birthDate.toIso8601String().split('T')[0],
          'budget_level': _budget,
          'interests': _interests.toList(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        if (mounted) context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _saveProfile();
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Stack(
        children: [
          // Fondo decorativo
          Positioned(
            top: -80, right: -80,
            child: Container(
              width: 280, height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryBrand.withOpacity(0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -60, left: -60,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.secondaryBrand.withOpacity(0.08),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header con progress
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(3, (i) => Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 4,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: i <= _currentPage
                                  ? AppTheme.primaryBrand
                                  : Colors.white12,
                            ),
                          ),
                        )),
                      ),
                    ],
                  ),
                ),

                // Páginas
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (p) => setState(() => _currentPage = p),
                    children: [
                      _buildPage1Nickname(),
                      _buildPage2Budget(),
                      _buildPage3Interests(),
                    ],
                  ),
                ),

                // Botón siguiente
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBrand,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              _currentPage < 2 ? 'Continuar →' : '¡Listo, a planear! 🚀',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- PÁGINA 1: Nickname y fecha de nacimiento ---
  Widget _buildPage1Nickname() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('¿Cómo te llaman\ntus amigos?',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2),
          ).animate().fadeIn().slideX(begin: -0.2),
          const SizedBox(height: 8),
          const Text('Este será tu nombre en Planmapp',
            style: TextStyle(color: Colors.white54, fontSize: 15),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 32),

          // Campo Nickname
          TextField(
            controller: _nicknameController,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(
              hintText: 'Ej: El Checho, La Negra, Pepito...',
              hintStyle: const TextStyle(color: Colors.white30),
              prefixIcon: const Icon(Icons.person_outline, color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppTheme.primaryBrand, width: 2),
              ),
            ),
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 32),
          const Text('¿Cuándo naciste?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 4),
          const Text('Solo para darte planes acordes a tu edad',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _birthDate,
                firstDate: DateTime(1940),
                lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
                builder: (context, child) => Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: ColorScheme.dark(primary: AppTheme.primaryBrand),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _birthDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Icon(Icons.cake_outlined, color: AppTheme.primaryBrand.withOpacity(0.7)),
                  const SizedBox(width: 12),
                  Text(
                    '${_birthDate.day.toString().padLeft(2, '0')}/${_birthDate.month.toString().padLeft(2, '0')}/${_birthDate.year}',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const Spacer(),
                  const Icon(Icons.edit_outlined, color: Colors.white38, size: 18),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 300.ms),
        ],
      ),
    );
  }

  // --- PÁGINA 2: Presupuesto ---
  Widget _buildPage2Budget() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('¿Cuál es tu\nestilo de plan?',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2),
          ).animate().fadeIn().slideX(begin: -0.2),
          const SizedBox(height: 8),
          const Text('Así te sugerimos planes a tu medida',
            style: TextStyle(color: Colors.white54, fontSize: 15),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 32),

          ...List.generate(_budgetOptions.length, (i) {
            final opt = _budgetOptions[i];
            final isSelected = _budget == opt['key'];
            return GestureDetector(
              onTap: () => setState(() => _budget = opt['key']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isSelected ? AppTheme.primaryBrand.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryBrand : Colors.white12,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(opt['emoji'] ?? opt['icon']!, style: const TextStyle(fontSize: 32)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(opt['label']!,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 17, fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(opt['desc']!,
                            style: const TextStyle(color: Colors.white38, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: AppTheme.primaryBrand, size: 22),
                  ],
                ),
              ).animate(delay: (i * 80).ms).fadeIn().slideX(begin: 0.2),
            );
          }),
        ],
      ),
    );
  }

  // --- PÁGINA 3: Intereses ---
  Widget _buildPage3Interests() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('¿Qué te\ngusta hacer?',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2),
          ).animate().fadeIn().slideX(begin: -0.2),
          const SizedBox(height: 8),
          const Text('Elige todo lo que te late (mínimo 1)',
            style: TextStyle(color: Colors.white54, fontSize: 15),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 32),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: List.generate(_interestOptions.length, (i) {
              final opt = _interestOptions[i];
              final isSelected = _interests.contains(opt['key']);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _interests.remove(opt['key']);
                    } else {
                      _interests.add(opt['key']!);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: isSelected ? AppTheme.primaryBrand.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryBrand : Colors.white12,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(opt['emoji']!, style: const TextStyle(fontSize: 30)),
                      const SizedBox(height: 8),
                      Text(
                        opt['label']!,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white60,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ).animate(delay: (i * 60).ms).fadeIn().scale(begin: const Offset(0.9, 0.9)),
              );
            }),
          ),
        ],
      ),
    );
  }
}
