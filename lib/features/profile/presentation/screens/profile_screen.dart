import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:flutter/services.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = true;
  String? _avatarUrl;
  String? _email;
  DateTime? _birthday;
  String _selectedCountryCode = '+57';
  List<String> _selectedPreferences = [];

  final List<String> _countryCodes = ['+57', '+1', '+52', '+54', '+56', '+51', '+55', '+593', '+507', '+506'];
  final Map<String, IconData> _prefOptions = {
    'Playa': Icons.beach_access,
    'Piscina': Icons.pool,
    'Antro': Icons.music_note,
    'Casa': Icons.home,
    'Cocinar': Icons.kitchen,
    'Comer fuera': Icons.restaurant,
    'Italiana': Icons.local_pizza,
    'Francesa': Icons.wine_bar,
    'Chill': Icons.spa,
    'Party': Icons.celebration,
  };

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      if (mounted) {
        setState(() {
          _nameController.text = data['display_name'] ?? data['full_name'] ?? "";
          _phoneController.text = data['phone'] ?? "";
          _avatarUrl = data['avatar_url'];
          _email = Supabase.instance.client.auth.currentUser?.email;
          _selectedCountryCode = data['country_code'] ?? '+57';
          if (data['birthday'] != null) {
            _birthday = DateTime.tryParse(data['birthday']);
          }
          if (data['preferences'] != null) {
            _selectedPreferences = List<String>.from(data['preferences']);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando perfil: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('profiles').upsert({
        'id': userId,
        'full_name': _nameController.text.trim(),
        'display_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'country_code': _selectedCountryCode,
        'birthday': _birthday?.toIso8601String(),
        'preferences': _selectedPreferences,
        'updated_at': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error guardando: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mi Perfil", style: TextStyle(fontWeight: FontWeight.bold))),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // Avatar
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                      child: _avatarUrl == null 
                          ? const Icon(Icons.person, size: 50, color: Colors.grey)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 16),
                    InkWell(
                    onTap: () {
                       final uid = Supabase.instance.client.auth.currentUser?.id;
                       if (uid != null) {
                           Clipboard.setData(ClipboardData(text: uid));
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ID Copiado al portapapeles")));
                       }
                    },
                    child: Column(children: [
                        Text(_email ?? "", style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                            "ID: ${Supabase.instance.client.auth.currentUser?.id?.substring(0, 8)}... (Copiar)", 
                            style: const TextStyle(color: Colors.blueGrey, fontSize: 10)
                        ),
                    ]),
                  ),
                  const SizedBox(height: 32),

                  // Friends Section
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.people, color: Colors.purple),
                    ),
                    title: const Text("Mis Amigos", style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text("Gestionar amistades y solicitudes"),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => context.push('/friends'),
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  // Name
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: "Nombre",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Phone with Country Code
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCountryCode,
                            items: _countryCodes.map((code) => DropdownMenuItem(value: code, child: Text(code))).toList(),
                            onChanged: (val) => setState(() => _selectedCountryCode = val!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: "Teléfono (WhatsApp)",
                            hintText: "300...",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.phone_android),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text("Para enviarte recordatorios automáticamente", style: TextStyle(fontSize: 12, color: Colors.grey)),

                  const SizedBox(height: 24),
                  
                  // Birthday
                   InkWell(
                     onTap: () async {
                       final d = await showDatePicker(
                         context: context, 
                         initialDate: DateTime(2000), 
                         firstDate: DateTime(1950), 
                         lastDate: DateTime.now()
                       );
                       if (d != null) setState(() => _birthday = d);
                     },
                     child: InputDecorator(
                       decoration: InputDecoration(
                         labelText: "Cumpleaños", 
                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                         prefixIcon: const Icon(Icons.cake_outlined)
                       ),
                       child: Text(
                         _birthday != null ? "${_birthday!.day}/${_birthday!.month}/${_birthday!.year}" : "Seleccionar fecha",
                         style: TextStyle(color: _birthday != null ? Colors.black : Colors.grey[600]),
                       ),
                     ),
                   ),

                  const SizedBox(height: 32),
                  const Text("¿Qué te mueve? ✨", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _prefOptions.entries.map((entry) {
                      final isSelected = _selectedPreferences.contains(entry.key);
                      return FilterChip(
                        label: Text(entry.key),
                        avatar: Icon(entry.value, size: 16, color: isSelected ? Colors.white : Colors.black54),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryBrand,
                        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedPreferences.add(entry.key);
                            } else {
                              _selectedPreferences.remove(entry.key);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBrand,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Guardar Cambios", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton(
                      onPressed: () {
                         Supabase.instance.client.auth.signOut();
                         context.go('/onboarding');
                      },
                      child: const Text("Cerrar Sesión", style: TextStyle(color: Colors.red)),
                    ),
                  ),

                  const SizedBox(height: 24),
                  SwitchListTile(
                      title: const Text("Idioma / Language"),
                      subtitle: Text(_selectedCountryCode == '+1' ? "English" : "Español Latino (Default)"),
                      value: _selectedCountryCode == '+1', // Mock logic: If +1 (USA), assume English preference
                      activeColor: AppTheme.primaryBrand,
                      onChanged: (val) {
                          setState(() {
                              // Auto-switch country code as a "demo" of language switch
                              _selectedCountryCode = val ? '+1' : '+57';
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(val ? "Switched to English (Demo)" : "Cambiado a Español")));
                          });
                      },
                      secondary: const Icon(Icons.language),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
