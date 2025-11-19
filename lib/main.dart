import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'catatan_model.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const MapScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final List<CatatanModel> _savedNotes = [];
  final MapController _mapController = MapController();

  // Fungsi untuk mendapatkan lokasi saat ini
  Future<void> _findMyLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();

    _mapController.move(
      latlong.LatLng(position.latitude, position.longitude),
      15.0,
    );
  }

  // ini fungsi  buat menangani long press pada peta
  void _handleLongPress(TapPosition _, latlong.LatLng point) async {
    List<Placemark> placemarks =
        await placemarkFromCoordinates(point.latitude, point.longitude);

    String address = placemarks.first.street ?? "Alamat tidak dikenal";

    TextEditingController noteController = TextEditingController(); // dialog input catatan

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Tambah Catatan"),
          content: TextField(
            controller: noteController,
            decoration:
                const InputDecoration(hintText: "Masukkan catatan..."),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _savedNotes.add(
                    CatatanModel(
                      position: point,
                      note: noteController.text.isEmpty
                          ? "Catatan Baru"
                          : noteController.text,
                      address: address,
                    ),
                  );
                });
                Navigator.pop(context);
              },
              child: const Text("Simpan"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Geo-Catatan")),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: const latlong.LatLng(-6.2, 106.8),
          initialZoom: 13.0,
          onLongPress: _handleLongPress,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          ),
          MarkerLayer(
            markers: _savedNotes
                .map(
                  (n) => Marker(
                    point: n.position,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 32,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _findMyLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
