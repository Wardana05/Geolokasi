import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class CatatanModel {
  final LatLng position;
  final String note;
  final String address;
  final String category; // rumah/toko/kantor

  CatatanModel({
    required this.position,
    required this.note,
    required this.address,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
        "lat": position.latitude,
        "lng": position.longitude,
        "note": note,
        "address": address,
        "category": category,
      };

  factory CatatanModel.fromJson(Map<String, dynamic> json) {
    return CatatanModel(
      position: LatLng(json["lat"], json["lng"]),
      note: json["note"],
      address: json["address"],
      category: json["category"],
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

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  // ========================== LOAD & SAVE DATA =============================
  Future<void> _loadSavedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? raw = prefs.getString("notes");

    if (raw != null) {
      List decoded = jsonDecode(raw);
      setState(() {
        _savedNotes.clear();
        _savedNotes.addAll(decoded.map((e) => CatatanModel.fromJson(e)));
      });
    }
  }

  Future<void> _saveData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List jsonList = _savedNotes.map((e) => e.toJson()).toList();
    prefs.setString("notes", jsonEncode(jsonList));
  }

  // ========================== GET CURRENT LOCATION ==========================
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
      LatLng(position.latitude, position.longitude),
      16.0,
    );
  }

  // =========================== HANDLE LONG PRESS ===========================
  void _handleLongPress(TapPosition tapPos, LatLng point) async {
    List<Placemark> placemarks =
        await placemarkFromCoordinates(point.latitude, point.longitude);

    String address = placemarks.isNotEmpty
        ? (placemarks.first.street ?? "Alamat tidak dikenal")
        : "Alamat tidak ditemukan";

    _showAddNoteDialog(point, address);
  }

  // ========================= ADD NOTE DIALOG ================================
  void _showAddNoteDialog(LatLng point, String address) {
    TextEditingController noteC = TextEditingController();

    String selectedCategory = "rumah";

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Tambah Catatan"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Alamat:\n$address"),
              const SizedBox(height: 10),
              TextField(
                controller: noteC,
                decoration: const InputDecoration(
                  labelText: "Catatan",
                ),
              ),
              const SizedBox(height: 10),
              DropdownButton<String>(
                value: selectedCategory,
                items: const [
                  DropdownMenuItem(value: "rumah", child: Text("Rumah")),
                  DropdownMenuItem(value: "toko", child: Text("Toko")),
                  DropdownMenuItem(value: "kantor", child: Text("Kantor")),
                ],
                onChanged: (v) {
                  selectedCategory = v!;
                  setState(() {});
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("Batal"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text("Simpan"),
              onPressed: () {
                setState(() {
                  _savedNotes.add(
                    CatatanModel(
                      position: point,
                      note: noteC.text,
                      address: address,
                      category: selectedCategory,
                    ),
                  );
                  _saveData();
                });
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  // ============================== DELETE NOTE ===============================
  void _deleteNoteDialog(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Hapus Marker?"),
        content: Text("Yakin ingin menghapus catatan '${_savedNotes[index].note}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _savedNotes.removeAt(index);
                _saveData();
              });
              Navigator.pop(context);
            },
            child: const Text("Hapus"),
          )
        ],
      ),
    );
  }

  // ========================== GET ICON BASED ON CATEGORY ====================
  Widget _buildMarkerIcon(String category) {
    switch (category) {
      case "rumah":
        return Image.asset("assets/icons/rumah.png", width: 40);
      case "toko":
        return Image.asset("assets/icons/toko.png", width: 40);
      case "kantor":
        return Image.asset("assets/icons/kantor.png", width: 40);
      default:
        return const Icon(Icons.location_on, color: Colors.red, size: 40);
    }
  }

  // =============================== UI MAP ==================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Geo-Catatan")),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: const LatLng(-6.2, 106.8),
          initialZoom: 13.0,
          onLongPress: _handleLongPress,
        ),
        children: [
          TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
          ),

          // MARKERS
          MarkerLayer(
            markers: [
              for (int i = 0; i < _savedNotes.length; i++)
                Marker(
                  point: _savedNotes[i].position,
                  width: 60,
                  height: 60,
                  child: GestureDetector(
                    onTap: () => _deleteNoteDialog(i),
                    child: _buildMarkerIcon(_savedNotes[i].category),
                  ),
                ),
            ],
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
