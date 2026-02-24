import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';

class SafeRouteNavigationScreen extends StatefulWidget {
  const SafeRouteNavigationScreen({super.key});

  @override
  State<SafeRouteNavigationScreen> createState() =>
      _SafeRouteNavigationScreenState();
}

class _SafeRouteNavigationScreenState extends State<SafeRouteNavigationScreen> {
  late GoogleMapController _mapController;

  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(37.7749, -122.4194),
    zoom: 14,
  );

  @override
  void dispose() {
    _sourceController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  // _______________ MY LOCATION FUNCTION __________
  Future<void> _goToMyLocation() async {
    try {
      _mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          const CameraPosition(
            target: LatLng(37.7749, -122.4194), // TEMP — replace with GPS later
            zoom: 16,
          ),
        ),
      );
    } catch (e) {
      print("Error moving to location: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Safe Route Navigation"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          //_______________ GOOGLE MAP ____________
          GoogleMap(
            initialCameraPosition: _initialPosition,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            myLocationEnabled: true,
            zoomControlsEnabled: false,
          ),

          //____________SEARCH PANEL_____________
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _sourceController,
                        decoration: const InputDecoration(
                          hintText: "Your Location",
                          prefixIcon:
                              Icon(Icons.circle, size: 12, color: Colors.green),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                      const Divider(
                          height: 1, thickness: 1, color: Colors.black12),
                      TextField(
                        controller: _destinationController,
                        decoration: const InputDecoration(
                          hintText: "Enter Destination",
                          prefixIcon:
                              Icon(Icons.location_on, color: Colors.red),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      elevation: 3,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      print("Find Route clicked");
                    },
                    child: const Text(
                      "Find Route",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // __________DRAGGABLE SLIDING PANEL____________ 
          DraggableScrollableSheet(
            initialChildSize: 0.12,
            minChildSize: 0.12,
            maxChildSize: 0.45,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(top: 10, bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const Text(
                      "Route Details",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Distance: 2.3 km",
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Estimated Time: 8 mins",
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Safety Score: High Safety Area",
                            style: TextStyle(
                                color: Colors.greenAccent, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2962FF),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Start Navigation",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // _____ MY LOCATION BUTTON ___
          Positioned(
            bottom: 120,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blueAccent,
              heroTag: "my_location_button",
              onPressed: _goToMyLocation,
              child: const Icon(Icons.my_location, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}
