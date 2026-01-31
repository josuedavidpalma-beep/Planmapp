import 'dart:math';
import 'package:planmapp/features/itinerary/domain/models/geo_offer_model.dart';
import 'package:latlong2/latlong.dart';

class GeoOfferService {
  
  // Generate random offers around a center point
  Future<List<GeoOffer>> getOffers(LatLng center) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    final random = Random();
    final List<GeoOffer> offers = [];
    
    // Create 5 mock offers
    for (int i = 0; i < 5; i++) {
        // Random offset +- 0.005 degrees (approx 500m)
        final double latOffset = (random.nextDouble() - 0.5) * 0.01; 
        final double lngOffset = (random.nextDouble() - 0.5) * 0.01;
        
        String cat = ['food', 'drink', 'activity'][random.nextInt(3)];
        String title = "";
        String desc = "";
        
        switch(cat) {
            case 'food': 
                title = "2x1 Hamburguesas"; 
                desc = "Compra una y lleva otra gratis en BurgerKing";
                break;
            case 'drink':
                title = "Happy Hour 50% OFF";
                desc = "Cervezas nacionales a mitad de precio";
                break;
            case 'activity':
                title = "10% dto. Museo";
                desc = "Entrada con descuento grupo > 4";
                break;
        }

        offers.add(GeoOffer(
            id: "offer_$i",
            title: title,
            description: desc,
            code: "PLANMAPP${random.nextInt(100)}",
            discount: 0.1 + (random.nextDouble() * 0.4), // 10% - 50%
            lat: center.latitude + latOffset,
            lng: center.longitude + lngOffset,
            category: cat,
        ));
    }
    
    return offers;
  }
}
