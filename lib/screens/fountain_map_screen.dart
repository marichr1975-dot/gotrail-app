import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/nearby_poi_service.dart';

class FountainMapScreen extends StatefulWidget {
  final String? place;
  final LatLng center;
  final List<NearbyPoi> fountains;

  const FountainMapScreen({
    super.key,
    required this.place,
    required this.center,
    required this.fountains,
  });

  @override
  State<FountainMapScreen> createState() => _FountainMapScreenState();
}

class _FountainMapScreenState extends State<FountainMapScreen> {
  final MapController _controller = MapController();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.place == null || widget.place!.trim().isEmpty
        ? 'Fontane'
        : 'Fontane · ${widget.place}';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: widget.center,
              initialZoom: 15.4,
              minZoom: 6,
              maxZoom: 19,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.gotrai.app',
                maxZoom: 19,
                errorTileCallback: (_, __, ___) {},
              ),
              MarkerLayer(
                markers: [
                  ...widget.fountains.map(
                    (item) => Marker(
                      point: item.point,
                      width: 46,
                      height: 46,
                      child: Tooltip(
                        message:
                            '${item.name} · ${item.distanceKm.toStringAsFixed(1)} km',
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B5FD7),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(
                                blurRadius: 6,
                                color: Colors.black26,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.local_drink_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
