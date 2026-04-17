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
      ...List.generate(10, (i) => "https://api.dicebear.com/7.x/avataaars/png?seed=p${i+1}"),
      ...List.generate(10, (i) => "https://api.dicebear.com/7.x/bottts/png?seed=b${i+1}"),
      ...List.generate(10, (i) => "https://api.dicebear.com/7.x/pixel-art/png?seed=px${i+1}"),
      ...List.generate(10, (i) => "https://api.dicebear.com/7.x/noto-emoji/png?seed=e${i+1}"),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text("Elige tu Avatar 🎨", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 4),
          const Text("Selecciona el que mejor te represente", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: avatarUrls.length,
              itemBuilder: (context, index) {
                final url = avatarUrls[index];
                return InkWell(
                  onTap: () {
                    onAvatarSelected(url);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                      shape: BoxShape.circle,
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                    ),
                    child: ClipOval(
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
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
