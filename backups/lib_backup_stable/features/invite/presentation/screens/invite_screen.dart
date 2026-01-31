import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/theme/app_theme.dart';

class InviteScreen extends StatelessWidget {
  final String planId;

  const InviteScreen({super.key, required this.planId});

  @override
  Widget build(BuildContext context) {
    // Mock contacts
    final contacts = [
      {"name": "Andrea Gomez", "phone": "300 123 4567"},
      {"name": "Camilo Torres", "phone": "310 987 6543"},
      {"name": "Daniela Perez", "phone": "315 456 7890"},
      {"name": "Fabian Ruiz", "phone": "301 234 5678"},
      {"name": "Gabriela Diaz", "phone": "320 876 5432"},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Invitar Amigos"),
        actions: [
          TextButton(
            onPressed: () {
               // Logic to send bulk invites
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text("Invitaciones enviadas")),
               );
               context.pop();
            },
            child: const Text("Listo", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: columConfig(contacts, context),
    );
  }

  Widget columConfig(List<Map<String, String>> contacts, BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: "Buscar en contactos...",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppTheme.lightBackground,
            ),
          ),
        ),
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
               color: AppTheme.secondaryBrand,
               shape: BoxShape.circle
            ),
            child: const Icon(Icons.link, color: Colors.white),
          ),
          title: const Text("Copiar enlace del plan"),
          subtitle: const Text("Cualquiera con el link puede unirse"),
          onTap: () {
             ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text("Enlace copiado al portapapeles")),
             );
          },
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey[200],
                  child: Text(contact["name"]![0]),
                ),
                title: Text(contact["name"]!),
                subtitle: Text(contact["phone"]!),
                trailing: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.lightBackground, // Unselected
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                  ),
                  child: const Text("Invitar"),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
