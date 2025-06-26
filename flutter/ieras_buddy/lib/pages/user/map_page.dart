import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class MapPickerPage extends StatefulWidget {
  const MapPickerPage({super.key});

  @override
  _MapPickerPageState createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  LatLng? selectedLocation;
  GoogleMapController? mapController;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  LatLng? currentLocation;

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location services are disabled.');
      return;
    }
    Position pos = await Geolocator.getCurrentPosition();
    setState(() {
      currentLocation = LatLng(pos.latitude, pos.longitude);
      selectedLocation = currentLocation;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Select Location")),
      body: currentLocation == null
          ? Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: currentLocation!,
                    zoom: 14,
                  ),
                  onMapCreated: (controller) => mapController = controller,
                  onTap: (LatLng location) {
                    setState(() => selectedLocation = location);
                  },
                  markers: selectedLocation != null
                      ? {
                          Marker(
                            markerId: MarkerId("selected"),
                            position: selectedLocation!,
                          ),
                        }
                      : {},
                  zoomControlsEnabled: false,
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            selectedLocation = currentLocation;
                            if (mapController != null &&
                                currentLocation != null) {
                              mapController!.animateCamera(
                                CameraUpdate.newCameraPosition(
                                  CameraPosition(
                                      target: currentLocation!, zoom: 16),
                                ),
                              );
                            }
                          });
                        },
                        child: Text("Reset"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (selectedLocation != null) {
                            Navigator.pop(context, selectedLocation);
                          }
                        },
                        child: Text("Confirm Location"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
