import 'package:flutter/material.dart';
import 'package:planmapp/core/theme/app_theme.dart';

class AvatarGalleryModal extends StatelessWidget {
  final Function(String) onAvatarSelected;

  const AvatarGalleryModal({super.key, required this.onAvatarSelected});

  @override
  Widget build(BuildContext context) {
    // Generate 40 unique avatar URLs using DiceBear
    // We'll use multiple styles for variety
    final avatarUrls = [
      ...List.generate(10, (i) => "https://api.dicebear.com/7.x/avataaars/svg?seed=p${i+1}"),
      ...List.generate(10, (i) => "https://api.dicebear.com/7.x/bottts/svg?seed=b${i+1}"),
      ...List.generate(10, (i) => "https://api.dicebear.com/7.x/adventurer/svg?seed=a${i+1}"),
      ...List.generate(10, (i) => "https://api.dicebear.com/7.x/personas/svg?seed=u${i+1}"),
    ];

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text("Elige tu Avatar 🎨", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          const Text("Selecciona el que mejor te represente", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: avatarUrls.length,
              itemBuilder: (context, index) {
                final url = avatarUrls[index];
                return InkWell(
                  onTap: () {
                    // Convert SVG URL to PNG if needed, but for now we'll assume the browser/app handles SVG 
                    // or we use a loader that supports it. DiceBear also supports .png
                    final pngUrl = url.replaceAll('/svg?', '/png?');
                    onAvatarSelected(pngUrl);
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white10),
                    ),
                    child: ClipOval(
                      child: Image.network(
                        url.replaceAll('/svg?', '/png?'), // DiceBear supports PNG for easier loading in Flutter
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: Colors.grey),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
