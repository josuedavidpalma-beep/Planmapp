import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:planmapp/core/services/plan_service.dart';
import 'package:planmapp/features/plans/domain/models/plan_model.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// New Imports
import 'package:latlong2/latlong.dart';
import 'package:planmapp/features/itinerary/presentation/screens/location_picker_screen.dart';
import 'package:planmapp/core/services/poll_service.dart';
import 'package:planmapp/features/itinerary/services/itinerary_service.dart';
import 'package:planmapp/features/itinerary/domain/models/activity.dart';

import 'package:geocoding/geocoding.dart';

class CreatePlanScreen extends StatefulWidget {
  final String? initialTitle;

  const CreatePlanScreen({super.key, this.initialTitle});

  @override
  State<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends State<CreatePlanScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  
  // Form Controllers
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  
  // Date Step
  bool _isDateDefined = true;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // Location Step
  bool _isLocationDefined = true;
  LatLng? _pickedLocation; 

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _locationController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
       _pageController.nextPage(
        duration: const Duration(milliseconds: 300), 
        curve: Curves.easeInOut
      );
      setState(() => _currentStep++);
    } else {
      _createPlan();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300), 
        curve: Curves.easeInOut
      );
      setState(() => _currentStep--);
    } else {
      context.pop();
    }
  }

  Future<void> _createPlan() async {
    setState(() => _isLoading = true);

    try {
      final planId = const Uuid().v4();
      
      // 1. Determine Event Date
      final DateTime fullDate = (_isDateDefined && _selectedDate != null && _selectedTime != null)
          ? DateTime(
              _selectedDate!.year,
              _selectedDate!.month,
              _selectedDate!.day,
              _selectedTime!.hour,
              _selectedTime!.minute,
            )
          : DateTime.now().add(const Duration(days: 7)); // Placeholder

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
          throw Exception("Usuario no autenticado");
      }

      // 2. Create Plan Object
      final newPlan = Plan(
        id: planId,
        creatorId: userId, 
        title: _titleController.text, // Use Controller
        eventDate: fullDate, 
        locationName: _isLocationDefined ? _locationController.text : "Por definir", // Use Controller
        status: PlanStatus.active,
      );

      // SAVE PLAN 
      final planService = PlanService();
      await planService.createPlan(newPlan);

      // 3. AUTO LOGIC
      final itineraryService = ItineraryService();
      final pollService = PollService();

      // -- DATE LOGIC --
      if (!_isDateDefined) {
          // Create Draft Poll
          await pollService.createPoll(
              planId, 
              "¿Cuándo será el ${_titleController.text}?", 
              [], // Empty options for draft
              status: 'draft'
          );
      } 

      // -- LOCATION LOGIC --
      if (!_isLocationDefined) {
          // Create Draft Poll
          await pollService.createPoll(
              planId, 
              "¿Dónde será el ${_titleController.text}?", 
              [], 
              status: 'draft'
          );
      }

      // -- ACTIVITY LOGIC --
      // If Date IS defined, we create the start activity
      if (_isDateDefined) {
          await itineraryService.createActivity(Activity(
              id: '', // DB generates
              planId: planId,
              title: "Inicio: ${_titleController.text}",
              startTime: fullDate,
              category: ActivityCategory.activity,
              description: "Inicio del evento.",
              locationName: _isLocationDefined ? _locationController.text : null,
              location: _isLocationDefined ? _pickedLocation : null,
          ));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Plan creado con éxito! 🚀')),
        );
        context.go('/'); 
      }
    } catch (e) {
      if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: _prevStep,
        ),
        title: Text(
           "Paso ${_currentStep + 1} de 3", 
           style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
             colors: [AppTheme.primaryBrand, AppTheme.secondaryBrand],
             begin: Alignment.topCenter,
             end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
            children: [
               const SizedBox(height: 20),
               // Progress Header
               Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 40),
                 child: Row(
                    children: [
                        _buildProgressDot(0),
                        _buildProgressLine(0),
                        _buildProgressDot(1),
                        _buildProgressLine(1),
                        _buildProgressDot(2),
                    ],
                 ),
               ),
               const SizedBox(height: 40),

               // Content Card
               Expanded(
                 child: Container(
                   width: double.infinity,
                   margin: const EdgeInsets.symmetric(horizontal: 16),
                   decoration: BoxDecoration(
                     color: Colors.white,
                     borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                     boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))],
                   ),
                   child: Column(
                     children: [
                        Expanded(
                          child: PageView(
                            controller: _pageController,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _buildStep1Title(),
                              _buildStep2Date(),
                              _buildStep3Location(),
                            ],
                          ),
                        ),
                        // Bottom Bar inside the white card
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: _buildBottomBar(),
                        ),
                     ],
                   ),
                 ),
               ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressDot(int step) {
      bool isActive = _currentStep >= step;
      return Container(
          width: 12, height: 12,
          decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.white24,
              shape: BoxShape.circle,
          ),
      );
  }

  Widget _buildProgressLine(int step) {
       bool isActive = _currentStep > step;
       return Expanded(
           child: Container(
               height: 2,
               color: isActive ? Colors.white : Colors.white24,
           )
       );
  }

  Widget _buildStep1Title() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          const Icon(Icons.celebration_rounded, size: 60, color: AppTheme.primaryBrand),
          const SizedBox(height: 20),
          Text("¿Qué vamos a hacer?", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Dale un nombre épico a tu plan.", style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
          const SizedBox(height: 40),
          TextField(
            controller: _titleController,
            autofocus: true,
            style: const TextStyle(fontSize: 18),
            decoration: InputDecoration(
              labelText: "Nombre del Plan",
              floatingLabelBehavior: FloatingLabelBehavior.always,
              hintText: "Ej: Asado en mi casa",
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.edit_outlined, color: AppTheme.primaryBrand),
            ),
            onChanged: (value) => setState(() {}), 
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Date() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
           const SizedBox(height: 20),
           const Icon(Icons.calendar_month_rounded, size: 60, color: AppTheme.primaryBrand),
           const SizedBox(height: 20),
           Text("¿Cuándo es?", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
           const SizedBox(height: 8),
           const Text("Elige una fecha definitiva o dejalo a votación.", style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
           const SizedBox(height: 30),

           Container(
             decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
             ),
             child: CheckboxListTile(
               value: !_isDateDefined, 
               onChanged: (val) {
                   setState(() {
                       _isDateDefined = !val!;
                       if (!_isDateDefined) {
                           _selectedDate = null;
                           _selectedTime = null;
                       }
                   });
               },
               title: const Text("Lo decidiremos juntos (Votación)", style: TextStyle(fontWeight: FontWeight.w600)),
               subtitle: const Text("Crea una encuesta automática"),
               activeColor: AppTheme.primaryBrand,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
             ),
           ),

           const SizedBox(height: 20),
           
           AnimatedOpacity(
               duration: const Duration(milliseconds: 300),
               opacity: _isDateDefined ? 1.0 : 0.3,
               child: IgnorePointer(
                   ignoring: !_isDateDefined,
                   child: Column(
                       children: [
                           _buildPickerTile(
                               icon: Icons.today_rounded,
                               title: _selectedDate == null ? "Seleccionar Fecha" : DateFormat.yMMMMEEEEd('es_CO').format(_selectedDate!),
                               onTap: () async {
                                 final date = await showDatePicker(
                                   context: context, 
                                   initialDate: DateTime.now(), 
                                   firstDate: DateTime.now(), 
                                   lastDate: DateTime(2030)
                                 );
                                 if (date != null) setState(() => _selectedDate = date);
                               }
                           ),
                           const SizedBox(height: 12),
                           _buildPickerTile(
                               icon: Icons.access_time_rounded,
                               title: _selectedTime == null ? "Seleccionar Hora" : _selectedTime!.format(context),
                               onTap: () async {
                                 final time = await showTimePicker(
                                   context: context, 
                                   initialTime: TimeOfDay.now(),
                                   builder: (context, child) {
                                      return Localizations.override(
                                          context: context, 
                                          locale: const Locale('en', 'US'), 
                                          child: child
                                      );
                                   }
                                 );
                                 if (time != null) setState(() => _selectedTime = time);
                               }
                           ),
                       ],
                   ),
               ),
           )
        ],
      ),
    );
  }
  
  Widget _buildPickerTile({required IconData icon, required String title, required VoidCallback onTap}) {
       return InkWell(
           onTap: onTap,
           borderRadius: BorderRadius.circular(16),
           child: Container(
               padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
               decoration: BoxDecoration(
                   border: Border.all(color: Colors.grey.shade300),
                   borderRadius: BorderRadius.circular(16),
               ),
               child: Row(
                   children: [
                       Icon(icon, color: AppTheme.primaryBrand),
                       const SizedBox(width: 12),
                       Text(title, style: const TextStyle(fontSize: 16)),
                       const Spacer(),
                       const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                   ],
               ),
           ),
       );
  }

  Widget _buildStep3Location() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
               const SizedBox(height: 20),
               const Icon(Icons.place_rounded, size: 60, color: AppTheme.primaryBrand),
               const SizedBox(height: 20),
               Text("¿Dónde nos vemos?", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
               const SizedBox(height: 30),

               Container(
                 decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16)),
                 child: CheckboxListTile(
                     value: !_isLocationDefined, 
                     onChanged: (val) {
                         setState(() {
                             _isLocationDefined = !val!;
                             if (!_isLocationDefined) {
                                 _locationController.clear();
                                 _pickedLocation = null;
                             }
                         });
                     },
                     title: const Text("Lo decidiremos juntos (Votación)", style: TextStyle(fontWeight: FontWeight.w600)),
                     activeColor: AppTheme.primaryBrand,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                 ),
               ),
               const SizedBox(height: 24),
    
               AnimatedOpacity(
                   duration: const Duration(milliseconds: 300),
                   opacity: _isLocationDefined ? 1.0 : 0.3,
                   child: IgnorePointer(
                       ignoring: !_isLocationDefined,
                       child: Column(
                           children: [
                               // Styled Map Button
                               InkWell(
                                   onTap: () async {
                                        final result = await Navigator.push<LatLng>(
                                            context, MaterialPageRoute(builder: (_) => const LocationPickerScreen())
                                        );
                                        if (result != null) {
                                            setState(() {
                                                _pickedLocation = result;
                                                _locationController.text = "${result.latitude.toStringAsFixed(5)}, ${result.longitude.toStringAsFixed(5)}"; 
                                            });
                                            try {
                                                List<Placemark> placemarks = await placemarkFromCoordinates(result.latitude, result.longitude);
                                                if (placemarks.isNotEmpty) {
                                                    final place = placemarks.first;
                                                    final address = "${place.street ?? ''}, ${place.locality ?? ''}".trim(); 
                                                    setState(() => _locationController.text = address.isEmpty ? "Ubicación seleccionada" : address);
                                                }
                                            } catch (_) {}
                                        }
                                   },
                                   borderRadius: BorderRadius.circular(16),
                                   child: Container(
                                       height: 120,
                                       width: double.infinity,
                                       decoration: BoxDecoration(
                                           color: AppTheme.primaryBrand.withOpacity(0.05),
                                           borderRadius: BorderRadius.circular(16),
                                           border: Border.all(color: AppTheme.primaryBrand.withOpacity(0.2), width: 1),
                                           image: _pickedLocation != null ? null : const DecorationImage(image: AssetImage('assets/images/map_placeholder.png'), fit: BoxFit.cover, opacity: 0.1), // Placeholder if we had one
                                       ),
                                       child: Column(
                                           mainAxisAlignment: MainAxisAlignment.center,
                                           children: [
                                               Icon(_pickedLocation != null ? Icons.check_circle : Icons.map, size: 32, color: AppTheme.primaryBrand),
                                               const SizedBox(height: 8),
                                               Text(_pickedLocation != null ? "Ubicación Seleccionada" : "Abrir Mapa", style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBrand)),
                                           ],
                                       ),
                                   ),
                               ),
                               const SizedBox(height: 16),
                               TextField(
                                 controller: _locationController,
                                 decoration: InputDecoration(
                                   labelText: "Dirección o Lugar",
                                   hintText: "Ej: Parque Central",
                                   filled: true,
                                   fillColor: Colors.grey[50],
                                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                   prefixIcon: const Icon(Icons.location_on_outlined, color: Colors.grey),
                                 ),
                                 onChanged: (value) => setState(() {}),
                               ),
                           ],
                       ),
                   ),
               )
          ],
      ),
    );
  }

  Widget _buildBottomBar() {
    bool canProceed = false;
    switch (_currentStep) {
      case 0: canProceed = _titleController.text.trim().isNotEmpty; break;
      case 1: canProceed = !_isDateDefined || (_selectedDate != null && _selectedTime != null); break;
      case 2: canProceed = !_isLocationDefined || _locationController.text.trim().isNotEmpty; break;
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canProceed ? _nextStep : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBrand,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          _currentStep == 2 ? "¡Crear Plan!" : "Siguiente",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
