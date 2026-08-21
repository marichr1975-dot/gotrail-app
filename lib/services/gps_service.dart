
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class GpsService {
  static Future<LatLng> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('GPS non attivo');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Permesso GPS non disponibile');
    }

    try {
      // V9: chiedi prima una posizione reale e aggiornata. In questo modo il
      // flusso INIZIA attiva davvero la localizzazione invece di usare subito
      // una coordinata vecchia rimasta in cache.
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return LatLng(p.latitude, p.longitude);
    } catch (_) {
      // Se in quel momento il fix non arriva (es. al chiuso), usa l'ultima
      // posizione nota solo come ripiego.
      final cached = await Geolocator.getLastKnownPosition();
      if (cached != null) {
        return LatLng(cached.latitude, cached.longitude);
      }
      throw Exception('Impossibile ottenere la posizione GPS');
    }
  }

  static Stream<Position> stream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    );
  }
}
