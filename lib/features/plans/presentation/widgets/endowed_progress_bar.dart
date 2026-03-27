import 'package:flutter/material.dart';

/// Barra de Progreso Gamificada (Efecto de Progreso Dotado)
/// Según la economía conductual, la gente está más motivada a terminar 
/// una meta si sienten que ya empezaron. Por eso, "endowment" regala un % inicial visual.
class EndowedProgressBar extends StatelessWidget {
  final double currentAmount;
  final double targetAmount;
  
  /// El porcentaje visual regalado (ej. 0.10 para un 10% inicial "gratis")
  final double endowmentPercentage;

  const EndowedProgressBar({
    super.key,
    required this.currentAmount,
    required this.targetAmount,
    this.endowmentPercentage = 0.10, // 10% by default
  });

  @override
  Widget build(BuildContext context) {
    if (targetAmount <= 0) return const SizedBox.shrink();

    // Cálculo real
    double actualProgress = currentAmount / targetAmount;
    if (actualProgress > 1.0) actualProgress = 1.0;

    // Efecto visual: Si el progreso real es 0, mostramos el regalado.
    // A medida que avanza, el regalado se diluye o se mantiene sumado.
    // Para simplificar: Visual Progreso = Progreso Real + (Restante * Endowment)
    double visualProgress = actualProgress + ((1.0 - actualProgress) * endowmentPercentage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Recaudo de la Vaca",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              "\$${currentAmount.toStringAsFixed(0)} / \$${targetAmount.toStringAsFixed(0)}",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 12,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            children: [
              // Barra del Endowment (Regalo Visual)
              FractionallySizedBox(
                widthFactor: visualProgress,
                child: Container(
                  decoration: BoxDecoration(
                    // Color más tenue para indicar que es un impulso
                    color: Colors.green.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              // Barra del Progreso Real (Dinero Real)
              FractionallySizedBox(
                widthFactor: actualProgress,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          currentAmount == 0 
            ? "¡Ya te regalamos el primer empujón visual! Anímate a empezar." 
            : "¡Vas por buen camino! Sigue así.",
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontStyle: FontStyle.italic),
        )
      ],
    );
  }
}
