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
  const CreatePlanScreen({super.key});

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
    _titleController = TextEditingController();
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Plan creado con éxito! 🚀')),
        );
        context.go('/home'); 
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: _prevStep,
        ),
        title: Text("Paso ${_currentStep + 1} de 3"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / 3,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation(AppTheme.primaryBrand),
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
          padding: const EdgeInsets.all(24.0),
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
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1Title() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("¿Qué vamos a hacer?", style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text("Dale un nombre épico a tu plan.", style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 32),
        TextField(
          controller: _titleController, // Use Controller
          autofocus: true,
          decoration: const InputDecoration(
            labelText: "Nombre del Plan",
            hintText: "Ej: Asado en mi casa",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.celebration_rounded),
          ),
          onChanged: (value) => setState(() {}), // Trigger rebuild for button state
        ),
      ],
    );
  }

  Widget _buildStep2Date() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("¿Cuándo es?", style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        CheckboxListTile(
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
            title: const Text("Por definir (Crear votación)"),
            activeColor: AppTheme.primaryBrand,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 16),
        Opacity(
            opacity: _isDateDefined ? 1.0 : 0.5,
            child: IgnorePointer(
                ignoring: !_isDateDefined,
                child: Column(
                    children: [
                        ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.grey)),
                          leading: const Icon(Icons.calendar_today_rounded, color: AppTheme.primaryBrand),
                          title: Text(_selectedDate == null ? "Seleccionar Fecha" : DateFormat.yMMMMEEEEd('es_CO').format(_selectedDate!)),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context, 
                              initialDate: DateTime.now(), 
                              firstDate: DateTime.now(), 
                              lastDate: DateTime(2030)
                            );
                            if (date != null) setState(() => _selectedDate = date);
                          },
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.grey)),
                          leading: const Icon(Icons.access_time_rounded, color: AppTheme.primaryBrand),
                          title: Text(_selectedTime == null ? "Seleccionar Hora" : _selectedTime!.format(context)),
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context, 
                              initialTime: TimeOfDay.now(),
                              builder: (BuildContext context, Widget? child) {
                                return Localizations.override(
                                  context: context,
                                  locale: const Locale('en', 'US'), // Force US locale for 12h logic (AM/PM)
                                  child: child,
                                );
                              },
                            );
                            if (time != null) setState(() => _selectedTime = time);
                          },
                        ),
                    ],
                ),
            ),
        )
      ],
    );
  }

  Widget _buildStep3Location() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("¿Dónde nos vemos?", style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        CheckboxListTile(
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
            title: const Text("Por definir (Crear votación)"),
            activeColor: AppTheme.primaryBrand,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 16),

        Opacity(
            opacity: _isLocationDefined ? 1.0 : 0.5,
            child: IgnorePointer(
                ignoring: !_isLocationDefined,
                child: Column(
                    children: [
                        // Map Picker Button or Preview
                        if (_pickedLocation == null)
                            Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade300)
                                ),
                                child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () async {
                                        final result = await Navigator.push<LatLng>(
                                            context, 
                                            MaterialPageRoute(builder: (_) => const LocationPickerScreen())
                                        );
                                        if (result != null) {
                                            setState(() {
                                                _pickedLocation = result;
                                                _locationController.text = "📍 Buscando dirección..."; 
                                            });

                                            try {
                                                // Reverse Geocoding
                                                List<Placemark> placemarks = await placemarkFromCoordinates(result.latitude, result.longitude);
                                                if (placemarks.isNotEmpty) {
                                                    final place = placemarks.first;
                                                    // Construct address: Street, Number, Locality
                                                    final address = "${place.street ?? ''}, ${place.locality ?? ''}".trim(); 
                                                    setState(() => _locationController.text = address.isEmpty ? "Ubicación seleccionada" : address);
                                                } else {
                                                     setState(() => _locationController.text = "${result.latitude.toStringAsFixed(5)}, ${result.longitude.toStringAsFixed(5)}");
                                                }
                                            } catch (e) {
                                                // Fallback on error (e.g. Windows or No Internet)
                                                // Just show coords
                                                setState(() => _locationController.text = "${result.latitude.toStringAsFixed(5)}, ${result.longitude.toStringAsFixed(5)}");
                                            }
                                        }
                                    },
                                    child: const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 24.0),
                                        child: Column(
                                            children: [
                                                Icon(Icons.map_rounded, size: 40, color: AppTheme.primaryBrand),
                                                SizedBox(height: 8),
                                                Text("Toca para ubicar en mapa", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBrand)),
                                                Text("Seleccionar punto de encuentro", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                            ],
                                        ),
                                    ),
                                ),
                            )
                        else 
                            InkWell(
                                onTap: () async {
                                     final result = await Navigator.push<LatLng>(
                                            context, 
                                            MaterialPageRoute(builder: (_) => LocationPickerScreen(initialCenter: _pickedLocation!))
                                        );
                                        if (result != null) {
                                            setState(() => _pickedLocation = result);
                                        }
                                },
                                child: Container(
                                    height: 150,
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade300),
                                        color: Colors.grey[200],
                                    ),
                                    child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                                // Simple Static Map representation (FlutterMap needs controller, complex for static)
                                                // We will use a placeholder with coordinates
                                                Center(child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                        const Icon(Icons.location_on, color: Colors.red, size: 30),
                                                        Text("Ubicación seleccionada", style: const TextStyle(fontWeight: FontWeight.bold)),
                                                        Text("${_pickedLocation!.latitude.toStringAsFixed(4)}, ${_pickedLocation!.longitude.toStringAsFixed(4)}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                                    ],
                                                )),
                                                const Positioned(
                                                    top: 8, right: 8, 
                                                    child: CircleAvatar(backgroundColor: Colors.white, radius: 14, child: Icon(Icons.edit, size: 14, color: Colors.black))
                                                )
                                            ],
                                        ),
                                    ),
                                ),
                            ),

                        TextField(
                          controller: _locationController, // Persistent Controller
                          decoration: const InputDecoration(
                            labelText: "Dirección o Nombre",
                            hintText: "Ej: Restaurante Mexicano, Calle 123",
                            helperText: "Puedes escribir la dirección exacta si el mapa no la autocompleta.",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.location_on_rounded),
                          ),
                          // Update state on change to enable button
                          onChanged: (value) => setState(() {}),
                        ),
                    ],
                ),
            ),
        )
      ],
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
