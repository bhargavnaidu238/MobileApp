import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

// Project specific imports
import 'package:hotel_booking_app/services/api_service.dart';
import 'View_Hotels_Page.dart';

class AddHotelsPage extends StatefulWidget {
  final String partnerId;
  final Map<String, dynamic>? hotelData; // Data passed from View Hotels Page for Editing

  const AddHotelsPage({required this.partnerId, Key? key, this.hotelData}) : super(key: key);

  @override
  State<AddHotelsPage> createState() => _AddHotelsPageState();
}

class _AddHotelsPageState extends State<AddHotelsPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> controllers = {};

  bool showAddRoomField = false;
  bool showAddAmenityField = false;
  bool showAddPolicyField = false;
  bool showImageSections = false;
  bool isSaving = false;

  final TextEditingController newRoomTypeCtrl = TextEditingController();
  final TextEditingController newAmenityCtrl = TextEditingController();
  final TextEditingController newPolicyCtrl = TextEditingController();
  final TextEditingController aboutController = TextEditingController();
  final TextEditingController ratingController = TextEditingController(text: '0.0');
  final TextEditingController locationController = TextEditingController();

  String? selectedHotelType;
  String? selectedCustomization;
  double? latitude, longitude;

  List<String> roomTypes = ['Standard Room', 'Executive Room', 'Suite Room'];
  Map<String, bool> roomSelected = {};
  Map<String, TextEditingController> roomPrices = {};

  List<String> amenities = ['AC', 'TV', 'Free WIFI', 'Power Backup', 'Attached Bathroom', 'Elevator Geyser', 'Parking'];
  Map<String, bool> amenitySelected = {};

  List<String> policies = ['Couple Friendly', 'Alcohol Allowed', 'Guest Should Display Govt ID\'s', 'Non-Refundable', 'Refundable'];
  Map<String, bool> policySelected = {};

  final Map<String, List<Uint8List>> localImages = {};

  late AnimationController _expandCtrl;
  late Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _expandCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _expandAnim = CurvedAnimation(parent: _expandCtrl, curve: Curves.easeInOut);
    _initData();
  }

  void _initData() {
    List<String> fields = ["Hotel_Name", "Address", "City", "State", "Country", "Pincode", "Total_Rooms", "Description", "Hotel_Contact"];
    for (var f in fields) {
      controllers[f] = TextEditingController();
      controllers[f]!.addListener(() => setState(() {}));
    }
    for (var r in roomTypes) { roomSelected[r] = false; roomPrices[r] = TextEditingController(text: "0"); }
    for (var a in amenities) amenitySelected[a] = false;
    for (var p in policies) policySelected[p] = false;

    localImages["Facade"] = [];
    localImages["Lobby/Entrance"] = [];

    // Check if we are in EDIT mode
    if (widget.hotelData != null) {
      _populateExistingData();
    }
  }

  // --- ISSUE 2 FIXED: AUTO POPULATION ---
  void _populateExistingData() {
    final data = widget.hotelData!;

    controllers["Hotel_Name"]!.text = data['Hotel_Name']?.toString() ?? "";
    controllers["Address"]!.text = data['Address']?.toString() ?? "";
    controllers["City"]!.text = data['City']?.toString() ?? "";
    controllers["State"]!.text = data['State']?.toString() ?? "";
    controllers["Country"]!.text = data['Country']?.toString() ?? "";
    controllers["Pincode"]!.text = data['Pincode']?.toString() ?? "";
    controllers["Total_Rooms"]!.text = data['Total_Rooms']?.toString() ?? "0";
    controllers["Description"]!.text = data['Description']?.toString() ?? "";
    controllers["Hotel_Contact"]!.text = data['Hotel_Contact']?.toString() ?? "";

    aboutController.text = data['About_This_Property']?.toString() ?? "";
    ratingController.text = data['Rating']?.toString() ?? "0.0";
    selectedHotelType = data['Hotel_Type'];
    selectedCustomization = data['Customization'];

    // Parse Location
    String? loc = data['Hotel_Location'];
    if (loc != null && loc.contains(',')) {
      List<String> parts = loc.split(',');
      latitude = double.tryParse(parts[0]);
      longitude = double.tryParse(parts[1]);
      locationController.text = "Lat: $latitude, Lng: $longitude";
    }

    // Parse Amenities
    List<String> savedAmenities = data['Amenities']?.toString().split(',') ?? [];
    for (var a in savedAmenities) {
      String trimmed = a.trim();
      if (trimmed.isNotEmpty) {
        if (!amenities.contains(trimmed)) amenities.add(trimmed);
        amenitySelected[trimmed] = true;
      }
    }

    // Parse Policies
    List<String> savedPolicies = data['Policies']?.toString().split(',') ?? [];
    for (var p in savedPolicies) {
      String trimmed = p.trim();
      if (trimmed.isNotEmpty) {
        if (!policies.contains(trimmed)) policies.add(trimmed);
        policySelected[trimmed] = true;
      }
    }

    // Parse Rooms and Prices
    List<String> savedRooms = data['Room_Type']?.toString().split(',') ?? [];
    List<String> savedPrices = data['Room_Price']?.toString().split(',') ?? [];
    for (int i = 0; i < savedRooms.length; i++) {
      String rName = savedRooms[i].trim();
      if (rName.isNotEmpty) {
        if (!roomTypes.contains(rName)) roomTypes.add(rName);
        roomSelected[rName] = true;
        roomPrices[rName] = TextEditingController(text: i < savedPrices.length ? savedPrices[i] : "0");
      }
    }
    setState(() {});
  }

  // --- ISSUE 1 FIXED: UPDATING MAPS ON ADDING NEW ---
  void _addNewAmenity() {
    String val = newAmenityCtrl.text.trim();
    if (val.isNotEmpty) {
      setState(() {
        if (!amenities.contains(val)) amenities.add(val);
        amenitySelected[val] = true; // Mark as selected immediately
        newAmenityCtrl.clear();
        showAddAmenityField = false;
      });
    }
  }

  void _addNewPolicy() {
    String val = newPolicyCtrl.text.trim();
    if (val.isNotEmpty) {
      setState(() {
        if (!policies.contains(val)) policies.add(val);
        policySelected[val] = true; // Mark as selected immediately
        newPolicyCtrl.clear();
        showAddPolicyField = false;
      });
    }
  }

  void _addNewRoom() {
    String val = newRoomTypeCtrl.text.trim();
    if (val.isNotEmpty) {
      setState(() {
        if (!roomTypes.contains(val)) roomTypes.add(val);
        roomSelected[val] = true;
        roomPrices[val] = TextEditingController(text: "0");
        newRoomTypeCtrl.clear();
        showAddRoomField = false;
      });
    }
  }

  // --- IMAGE & CATEGORY LOGIC ---
  List<String> get dynamicCategories {
    List<String> cats = ["Facade", "Lobby/Entrance"];
    roomSelected.forEach((key, selected) { if (selected) cats.add(key); });
    return cats;
  }

  Future<void> _pickImages(String category) async {
    if ((localImages[category]?.length ?? 0) >= 10) {
      _showSnack("Maximum 10 images allowed for $category");
      return;
    }
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true, withData: true);
    if (result != null) {
      setState(() {
        localImages.putIfAbsent(category, () => []);
        for (var file in result.files) {
          if (localImages[category]!.length < 10 && file.bytes != null) {
            localImages[category]!.add(file.bytes!);
          }
        }
      });
    }
  }

  // --- SAVE HOTEL ---
  Future<void> saveHotel() async {
    if (!_formKey.currentState!.validate()) {
      _showSnack("All fields are mandatory except Rating");
      return;
    }
    if (latitude == null) {
      _showSnack("Please select location on map");
      return;
    }

    setState(() => isSaving = true);

    try {
      final selRooms = roomSelected.entries.where((e) => e.value).map((e) => e.key).toList();
      final selPrices = selRooms.map((r) => roomPrices[r]?.text.isEmpty ?? true ? "0" : roomPrices[r]!.text).toList();

      final Map<String, String> body = {
        'hotel_id': widget.hotelData?['Hotel_ID']?.toString() ?? '',
        'partner_id': widget.partnerId,
        'hotel_name': controllers["Hotel_Name"]!.text,
        'hotel_type': selectedHotelType ?? 'Hotel',
        'customization': selectedCustomization ?? 'No',
        'room_type': selRooms.isEmpty ? 'Standard' : selRooms.join(','),
        'room_price': selPrices.isEmpty ? '0' : selPrices.join(','),
        'address': controllers["Address"]!.text,
        'city': controllers["City"]!.text,
        'state': controllers["State"]!.text,
        'country': controllers["Country"]!.text,
        'pincode': controllers["Pincode"]!.text,
        'total_rooms': controllers["Total_Rooms"]!.text,
        'available_rooms': controllers["Total_Rooms"]!.text,
        'amenities': amenitySelected.entries.where((e) => e.value).map((e) => e.key).join(','),
        'description': controllers["Description"]!.text,
        'policies': policySelected.entries.where((e) => e.value).map((e) => e.key).join(','),
        'rating': ratingController.text,
        'hotel_contact': controllers["Hotel_Contact"]!.text,
        'about_this_property': aboutController.text,
        'hotel_location': "$latitude,$longitude",
        'status': "Active",
      };

      Map<String, List<String>> imageMap = {};
      localImages.forEach((cat, bytesList) {
        if (bytesList.isNotEmpty) {
          imageMap[cat] = bytesList.map((b) => base64Encode(b)).toList();
        }
      });
      if (imageMap.isNotEmpty) body['images'] = jsonEncode(imageMap);

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/webaddhotels'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );

      final result = jsonDecode(response.body);
      if (response.statusCode == 200 && result['status'] == 'success') {
        _showSnack(result['message']);
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ViewHotelsPage(partnerId: widget.partnerId)));
      } else {
        _showSnack("Error: ${result['message']}");
      }
    } catch (e) {
      _showSnack("Connection Error: $e");
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB9F6CA),
      appBar: AppBar(backgroundColor: const Color(0xFF00C853), title: Text(widget.hotelData == null ? "Add Hotels" : "Edit Hotel"), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // LEFT SIDE: FORM
              Container(
                width: 750, padding: const EdgeInsets.all(35),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Add Hotels", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 25),
                      DropdownButtonFormField<String>(value: selectedHotelType, decoration: _inputStyle("Hotel Type"), items: ['Hotel', 'Home Stays', 'Dormitory', 'Farm House','Lodge', 'Party Rooms', 'Resort', 'Villa'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() => selectedHotelType = v), validator: (v) => v == null ? "Required" : null),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(value: selectedCustomization, decoration: _inputStyle("Customization"), items: ['Yes', 'No'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() => selectedCustomization = v), validator: (v) => v == null ? "Required" : null),
                      const SizedBox(height: 15),
                      ...controllers.keys.map((k) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(controller: controllers[k], decoration: _inputStyle(k.replaceAll("_", " ")), validator: (v) => (v == null || v.isEmpty) ? "Required" : null))),

                      TextFormField(controller: locationController, readOnly: true, decoration: _inputStyle("Location").copyWith(suffixIcon: const Icon(Icons.map)), onTap: () async {
                        final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => MapPickerPage(initialLat: latitude, initialLng: longitude)));
                        if (res != null) setState(() { latitude = res['lat']; longitude = res['lng']; locationController.text = "Lat: ${latitude!.toStringAsFixed(3)}, Lng: ${longitude!.toStringAsFixed(3)}"; });
                      }),

                      const SizedBox(height: 25),
                      _sectionHeader("Room Types", () => setState(() => showAddRoomField = !showAddRoomField)),
                      if (showAddRoomField) _addInputRow(newRoomTypeCtrl, "Room Type Name", _addNewRoom),
                      Wrap(spacing: 8, children: roomTypes.map((r) => FilterChip(label: Text(r), selected: roomSelected[r] ?? false, onSelected: (v) => setState(() => roomSelected[r] = v))).toList()),
                      ...roomTypes.where((r) => roomSelected[r] == true).map((r) => Padding(padding: const EdgeInsets.only(top: 10), child: TextFormField(controller: roomPrices[r], decoration: _inputStyle("$r Price"), keyboardType: TextInputType.number, validator: (v) => (v == null || v.isEmpty) ? "Required" : null))),

                      const SizedBox(height: 25),
                      _sectionHeader("Amenities", () => setState(() => showAddAmenityField = !showAddAmenityField)),
                      if (showAddAmenityField) _addInputRow(newAmenityCtrl, "Amenity", _addNewAmenity),
                      Wrap(spacing: 8, children: amenities.map((a) => FilterChip(label: Text(a), selected: amenitySelected[a] ?? false, onSelected: (v) => setState(() => amenitySelected[a] = v))).toList()),

                      const SizedBox(height: 25),
                      _sectionHeader("Policies", () => setState(() => showAddPolicyField = !showAddPolicyField)),
                      if (showAddPolicyField) _addInputRow(newPolicyCtrl, "Policy", _addNewPolicy),
                      ...policies.map((p) => CheckboxListTile(title: Text(p, style: const TextStyle(fontSize: 13)), value: policySelected[p] ?? false, onChanged: (v) => setState(() => policySelected[p] = v!), dense: true, activeColor: Colors.green, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading)),

                      const SizedBox(height: 25),
                      SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => setState(() { showImageSections = !showImageSections; showImageSections ? _expandCtrl.forward() : _expandCtrl.reverse(); }), icon: const Icon(Icons.upload), label: const Text("Upload / Manage Images"), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C853), foregroundColor: Colors.white, padding: const EdgeInsets.all(15)))),

                      SizeTransition(sizeFactor: _expandAnim, child: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Column(children: [
                        ...dynamicCategories.map((c) => Column(children: [
                          ListTile(title: Text(c, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: const Text("Limit: 10 images"), trailing: Text("${localImages[c]?.length ?? 0} / 10"), onTap: () => _pickImages(c)),
                          if (localImages[c]?.isNotEmpty ?? false) SizedBox(height: 70, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: localImages[c]!.length, itemBuilder: (ctx, i) => _imageThumbnail(c, i))),
                          const Divider(),
                        ])),
                      ]))),

                      const SizedBox(height: 25),
                      TextFormField(controller: aboutController, maxLines: 3, decoration: _inputStyle("About Property"), validator: (v) => (v == null || v.isEmpty) ? "Required" : null),
                      const SizedBox(height: 20),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 30),
              _buildPreviewSidebar(),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI FRAGMENTS ---
  Widget _buildFooter() {
    return Row(children: [
      Expanded(child: TextFormField(controller: ratingController, decoration: _inputStyle("Rating (0.0-5.0)"), keyboardType: TextInputType.number)),
      const SizedBox(width: 15),
      SizedBox(height: 50, width: 150, child: ElevatedButton(onPressed: isSaving ? null : saveHotel, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C853), foregroundColor: Colors.white), child: isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("Save Hotel"))),
    ]);
  }

  Widget _buildPreviewSidebar() {
    return Column(children: [
      Container(width: 300, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(controllers["Hotel_Name"]!.text.isEmpty ? "Hotel Name" : controllers["Hotel_Name"]!.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 5),
        Text("${controllers["Address"]!.text} ${controllers["City"]!.text} ${controllers["State"]!.text}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const Divider(),
        Text("Rating: ${ratingController.text}", style: const TextStyle(fontSize: 12)),
        Text("Type: ${selectedHotelType ?? '-'}", style: const TextStyle(fontSize: 12)),
      ])),
    ]);
  }

  Widget _imageThumbnail(String c, int i) => Stack(children: [Container(margin: const EdgeInsets.only(right: 5), width: 60, height: 60, decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)), child: Image.memory(localImages[c]![i], fit: BoxFit.cover)), Positioned(right: 0, child: GestureDetector(onTap: () => setState(() => localImages[c]!.removeAt(i)), child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white))))]);
  Widget _sectionHeader(String title, VoidCallback onAdd) => Row(children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.add_circle_outline, size: 20), onPressed: onAdd)]);
  Widget _addInputRow(TextEditingController ctrl, String hint, VoidCallback onCheck) => Row(children: [Expanded(child: TextField(controller: ctrl, decoration: InputDecoration(hintText: hint))), IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: onCheck)]);
  InputDecoration _inputStyle(String label) => InputDecoration(labelText: label, labelStyle: const TextStyle(fontSize: 13, color: Colors.black54), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Colors.black26)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF00C853), width: 1.5)));
  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

// --- MAP PICKER ---
class MapPickerPage extends StatefulWidget {
  final double? initialLat, initialLng;
  const MapPickerPage({this.initialLat, this.initialLng, Key? key}) : super(key: key);
  @override State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  LatLng? _loc;
  final TextEditingController latC = TextEditingController(), lngC = TextEditingController();
  GoogleMapController? _mc;

  @override void initState() { super.initState(); _initLoc(); }

  Future<void> _initLoc() async {
    LatLng base = const LatLng(12.9716, 77.5946);
    try {
      Position p = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      base = LatLng(p.latitude, p.longitude);
    } catch (_) {}
    setState(() { _loc = LatLng(widget.initialLat ?? base.latitude, widget.initialLng ?? base.longitude); latC.text = _loc!.latitude.toString(); lngC.text = _loc!.longitude.toString(); });
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pick Location"), backgroundColor: Colors.green),
      body: _loc == null ? const Center(child: CircularProgressIndicator()) : Column(children: [
        Padding(padding: const EdgeInsets.all(10), child: Row(children: [
          Expanded(child: TextField(controller: latC, decoration: const InputDecoration(labelText: "Lat"))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: lngC, decoration: const InputDecoration(labelText: "Lng"))),
          ElevatedButton(onPressed: () => Navigator.pop(context, {'lat': _loc!.latitude, 'lng': _loc!.longitude}), child: const Text("Done"))
        ])),
        Expanded(child: GoogleMap(initialCameraPosition: CameraPosition(target: _loc!, zoom: 14), onMapCreated: (c) => _mc = c, onTap: (l) => setState(() { _loc = l; latC.text = l.latitude.toString(); lngC.text = l.longitude.toString(); }), markers: {Marker(markerId: const MarkerId("m"), position: _loc!)}))
      ]),
    );
  }
}