import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'View_Hotels_Page.dart';
import 'package:hotel_booking_app/services/api_service.dart';

class AddPGSPage extends StatefulWidget {
  final String partnerId;
  final Map<String, dynamic>? pgData;

  const AddPGSPage({required this.partnerId, Key? key, this.pgData}) : super(key: key);

  @override
  State<AddPGSPage> createState() => _AddPGSPageState();
}

class GradientButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double? width;
  final double height;
  final EdgeInsets padding;
  final BorderRadius borderRadius;

  const GradientButton({
    required this.child,
    required this.onPressed,
    this.width,
    this.height = 48,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.6,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            // Use two valid green endpoints so gradient compiles cleanly.
            colors: [
              // Primary requested color (approx): Colors.greenAccent.shade700
              Color(0xFF64DD17),
              // Slightly deeper green for visual depth
              Color(0xFF2E7D32),
            ],
          ),
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: onPressed,
            child: Padding(
              padding: padding,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddPGSPageState extends State<AddPGSPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> controllers = {};
  bool isSaving = false;
  bool showSuccess = false;

  String? selectedPGType;
  final List<String> pgTypes = ['Gents', 'Ladies', 'Co-Live'];

  final List<String> fields = [
    "PG_Name",
    "Address",
    "City",
    "State",
    "Country",
    "Pincode",
    "Total_Single_Sharing_Rooms",
    "Total_Double_Sharing_Rooms",
    "Total_Three_Sharing_Rooms",
    "Total_Four_Sharing_Rooms",
    "Total_Five_Sharing_Rooms",
    "Description",
    "PG_Contact",
    "About_This_PG"
  ];

  final List<String> roomTypeOptions = ['Single Sharing', 'Double Sharing', 'Three Sharing', 'Four Sharing', 'Five Sharing'];
  final Map<String, bool> roomTypeSelected = {
    'Single Sharing': false,
    'Double Sharing': false,
    'Three Sharing': false,
    'Four Sharing': false,
    'Five Sharing': false,
  };
  final Map<String, TextEditingController> roomPriceControllers = {};
  final TextEditingController availableRoomsController = TextEditingController();

  final List<String> amenityOptions = [
    'AC',
    'TV',
    'Fridge',
    'Washing Machine',
    'Free WIFI',
    'Power Backup',
    'Attached Bathroom',
    'Elevator',
    ' Geyser',
    'Parking'
  ];

  final Map<String, bool> policies = {
    'Couple Friendly': false,
    'Alcohol Allowed': false,
    'Guest Should Display Govt ID\'s': false,
    'Non-Refundable': false,
    'Refundable': false
  };

  final TextEditingController aboutController = TextEditingController();
  final TextEditingController ratingController = TextEditingController(text: '0.0');

  final List<String> categories = [
    "Facade",
    "Lobby/Entrance",
    "Single Sharing",
    "Double Sharing",
    "Three Sharing",
    "Four Sharing",
    "Five Sharing"
  ];
  final Map<String, List<LocalPickedImage>> localImages = {};
  final Map<String, int> categoryLimits = {
    "Facade": 10,
    "Lobby/Entrance": 10,
    "Single Sharing": 10,
    "Double Sharing": 10,
    "Three Sharing": 10,
    "Four Sharing": 10,
    "Five Sharing": 10,
  };
  final int maxFileSizeBytes = 5 * 1024 * 1024;
  bool showImageSections = false;

  final TextEditingController locationController = TextEditingController();
  double? latitude;
  double? longitude;

  late AnimationController _expandCtrl;
  late Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();

    _expandCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _expandAnim = CurvedAnimation(parent: _expandCtrl, curve: Curves.easeInOut);

    for (var field in fields) {
      controllers[field] = TextEditingController();
    }
    controllers['Amenities'] = TextEditingController();

    for (var rt in roomTypeOptions) {
      roomPriceControllers[rt] = TextEditingController();
    }

    for (var c in categories) {
      localImages[c] = [];
    }

    if (widget.pgData != null) {
      final data = widget.pgData!;
      for (var f in fields) {
        controllers[f]?.text = data[f] ?? '';
      }
      selectedPGType = data['PG_Type'];

      final roomTypes = (data['Room_Type'] ?? '').split(',');
      final roomPrices = (data['Room_Price'] ?? '').split(',');

      for (int i = 0; i < roomTypes.length; i++) {
        final rt = roomTypes[i].trim();
        if (roomTypeOptions.contains(rt)) {
          roomTypeSelected[rt] = true;
          if (i < roomPrices.length) roomPriceControllers[rt]?.text = roomPrices[i].trim();
        }
      }

      controllers['Amenities']?.text = data['Amenities'] ?? '';

      for (var k in policies.keys) {
        policies[k] = (data['Policies'] ?? '').split(',').contains(k);
      }

      aboutController.text = data['About_This_Property'] ?? '';
      ratingController.text = (data['Rating'] ?? '0.0').toString();

      if ((data['PG_Location'] ?? '').contains(',')) {
        final parts = data['PG_Location']!.split(',');
        latitude = double.tryParse(parts[0]);
        longitude = double.tryParse(parts[1]);

        if (latitude != null && longitude != null) {
          locationController.text =
          "Lat: ${latitude!.toStringAsFixed(5)}, Lng: ${longitude!.toStringAsFixed(5)}";
        }
      }
    }
  }

  @override
  void dispose() {
    for (var c in controllers.values) c.dispose();
    for (var c in roomPriceControllers.values) c.dispose();
    availableRoomsController.dispose();
    aboutController.dispose();
    ratingController.dispose();
    locationController.dispose();
    _expandCtrl.dispose();
    super.dispose();
  }

  Widget buildTextField(String field) {
    bool isNumber = ["Total_Single_Sharing_Rooms", "Total_Double_Sharing_Rooms", "Total_Three_Sharing_Rooms",
      "Total_Four_Sharing_Rooms", "Total_Five_Sharing_Rooms", "Pincode"].contains(field);
    bool isPhone = field == "PG_Contact";

    return TextFormField(
      controller: controllers[field],
      keyboardType: isNumber || isPhone ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumber || isPhone ? [FilteringTextInputFormatter.digitsOnly] : [],
      decoration: InputDecoration(
        labelText: field.replaceAll("_", " "),
        filled: true,
        // remove glassy effect -> use solid white fill
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.green.shade900, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return "Required";
        if (isNumber && double.tryParse(v) == null) return "Invalid number";
        if (isPhone && v.length != 10) return "Must be 10 digits";
        return null;
      },
      onChanged: (_) => setState(() {}),
    );
  }

  Widget buildRoomTypeSection(double width) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Room Types", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: roomTypeOptions.map((rt) {
              return FilterChip(
                label: Text(rt),
                selected: roomTypeSelected[rt] == true,
                onSelected: (sel) {
                  setState(() {
                    roomTypeSelected[rt] = sel;
                    if (!sel) roomPriceControllers[rt]?.clear();
                  });
                },
                selectedColor: Colors.greenAccent.shade700,
                backgroundColor: Colors.grey.shade100,
                labelStyle: const TextStyle(color: Colors.black87),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Column(
            children: roomTypeOptions
                .where((rt) => roomTypeSelected[rt] == true)
                .map((rt) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: TextFormField(
                  controller: roomPriceControllers[rt],
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: "$rt Price (INR)",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.green.shade900, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) {
                    if (roomTypeSelected[rt] == true) {
                      if (v == null || v.isEmpty) return "Required";
                      if (double.tryParse(v) == null) return "Invalid number";
                    }
                    return null;
                  },
                ),
              );
            }).toList(),
          )
        ],
      ),
    );
  }

  Widget buildAmenitiesInput(double width) {
    final amenitiesText = controllers['Amenities']?.text ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Amenities", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: amenityOptions.map((a) {
            return ChoiceChip(
              label: Text(a),
              selected: amenitiesText.split(',').map((s) => s.trim()).contains(a),
              onSelected: (sel) {
                setState(() {
                  final current = amenitiesText
                      .split(',')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toList();

                  if (sel) {
                    if (!current.contains(a)) current.add(a);
                  } else {
                    current.removeWhere((c) => c == a);
                  }

                  controllers['Amenities']?.text = current.join(',');
                });
              },
              selectedColor: Colors.greenAccent.shade700,
              backgroundColor: Colors.grey.shade100,
              labelStyle: const TextStyle(color: Colors.black87),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controllers['Amenities'],
          decoration: InputDecoration(
            labelText: "Other Amenities (comma separated)",
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.green.shade900, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        )
      ],
    );
  }

  Widget buildPoliciesSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Policies", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          Column(
            children: policies.keys.map((k) {
              return CheckboxListTile(
                value: policies[k],
                onChanged: (v) => setState(() => policies[k] = v ?? false),
                title: Text(k, style: const TextStyle(color: Colors.black87)),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                activeColor: Colors.greenAccent.shade700,
                tileColor: Colors.transparent,
              );
            }).toList(),
          )
        ],
      ),
    );
  }

  Widget buildDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: selectedPGType,
          items: pgTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
          onChanged: (val) => setState(() => selectedPGType = val),
          decoration: InputDecoration(
            labelText: "PG Type",
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.green.shade900, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          validator: (v) => v == null || v.isEmpty ? "Required" : null,
        ),
      ],
    );
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> pickLocation() async {
    final result = await Navigator.push<Map<String, double>>(
      context,
      MaterialPageRoute(builder: (_) => MapPickerPage(initialLat: latitude, initialLng: longitude)),
    );

    if (result != null) {
      setState(() {
        latitude = result['lat'];
        longitude = result['lng'];
        locationController.text =
        "Lat: ${latitude!.toStringAsFixed(5)}, Lng: ${longitude!.toStringAsFixed(5)}";
      });
    }
  }

  Widget buildPreviewCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            controllers["PG_Name"]?.text.isEmpty ?? true ? "PG Name" : controllers["PG_Name"]!.text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            (controllers["City"]?.text.isEmpty ?? true) ? "City, State" : "${controllers["City"]?.text}, ${controllers["State"]?.text}",
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Text(selectedPGType == null ? "" : "Type: $selectedPGType", style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 8),
          Text(_displayPriceSummary(), style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 8),
          Text("Images: ${localImages.values.map((l) => l.length).fold<int>(0, (a, b) => a + b)}", style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  String _displayPriceSummary() {
    final selected = roomTypeOptions.where((rt) => roomTypeSelected[rt] == true).toList();
    if (selected.isEmpty) return "Price: -";

    final parts = selected.map((rt) {
      final p = roomPriceControllers[rt]?.text.trim() ?? "";
      if (p.isEmpty) return "$rt: -";
      return "$rt: ₹$p";
    }).toList();

    return parts.join(" | ");
  }

  Future<void> _pickImagesForCategory(String category) async {
    final already = localImages[category]!.length;
    final limit = categoryLimits[category] ?? 10;
    final remaining = limit - already;

    if (remaining <= 0) {
      _showSnack("Limit reached for $category");
      return;
    }

    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );

      if (res == null) return;

      final picked = res.files;
      int toTake = picked.length > remaining ? remaining : picked.length;

      int added = 0;

      for (int i = 0; i < toTake; i++) {
        final pf = picked[i];
        final Uint8List? bytes = pf.bytes;

        if (bytes == null) continue;
        if (bytes.length > maxFileSizeBytes) continue;

        localImages[category]!.add(
          LocalPickedImage(name: pf.name, bytes: bytes, path: null),
        );
        added++;
      }

      setState(() {});
      if (added > 0) _showSnack("Selected $added image(s) for $category");
    } catch (e) {
      _showSnack("Error selecting images: $e");
    }
  }

  Future<void> _removeImage(String category, int index) async {
    if (index < 0 || index >= localImages[category]!.length) return;
    setState(() {
      localImages[category]!.removeAt(index);
    });
  }

  Widget _buildCategoryCard(String category) {
    final list = localImages[category]!;
    final used = list.length;
    final limit = categoryLimits[category] ?? 10;

    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Expanded(child: Text(category, style: const TextStyle(color: Colors.black87, fontSize: 16))),
              Text("$used / $limit", style: const TextStyle(color: Colors.black54)),
              const SizedBox(width: 8),
              // Use GradientButton for the "Pick" action
              GradientButton(
                width: 120,
                height: 40,
                onPressed: (used >= limit) ? null : () => _pickImagesForCategory(category),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.add_a_photo, size: 18, color: Colors.white),
                    SizedBox(width: 6),
                    Text("Pick", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (list.isNotEmpty)
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final img = list[i];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: img.bytes != null
                              ? Image.memory(img.bytes!, width: 140, height: 90, fit: BoxFit.cover)
                              : Container(
                            width: 140,
                            height: 90,
                            color: Colors.grey.shade200,
                            child: Center(
                              child: Text(
                                img.name,
                                style: const TextStyle(color: Colors.black54, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: GestureDetector(
                            onTap: () => _removeImage(category, i),
                            child: Container(
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                              child: const Icon(Icons.close, size: 20, color: Colors.white),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 6,
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                            child: Text(
                              img.name.length > 14 ? img.name.substring(0, 12) + "..." : img.name,
                              style: const TextStyle(color: Colors.white70, fontSize: 10),
                            ),
                          ),
                        )
                      ],
                    ),
                  );
                },
              ),
            ),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text("No images selected yet for $category", style: const TextStyle(color: Colors.black54)),
            )
        ]),
      ),
    );
  }

  Widget buildImageSections() {
    return SizeTransition(
      sizeFactor: _expandAnim,
      axisAlignment: -1,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          children: [
            const Text("Upload images per category (Max 10 images per section, 5MB per image)", style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 10),
            ...categories.map((c) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _buildCategoryCard(c))).toList(),
            const SizedBox(height: 8),
            Row(
              children: [
                GradientButton(
                  onPressed: () {
                    setState(() {
                      showImageSections = false;
                      _expandCtrl.reverse();
                    });
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [Icon(Icons.check, color: Colors.white), SizedBox(width: 8), Text("Done", style: TextStyle(color: Colors.white))],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      for (var c in categories) localImages[c]!.clear();
                    });
                  },
                  icon: const Icon(Icons.delete_forever),
                  label: const Text("Clear All"),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.black26)),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget buildUploadImagesButton(double width) {
    return GradientButton(
      width: width,
      height: 50,
      onPressed: () {
        setState(() {
          showImageSections = true;
          _expandCtrl.forward();
        });
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.upload_file, color: Colors.white),
          SizedBox(width: 8),
          Text("Upload / Manage Images", style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Future<void> saveHotel() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate room prices when selected
    final selectedRoomTypes = roomTypeOptions.where((rt) => roomTypeSelected[rt] == true).toList();
    for (var rt in selectedRoomTypes) {
      final priceText = roomPriceControllers[rt]?.text.trim() ?? "";
      if (priceText.isEmpty) {
        _showSnack("Please enter price for $rt");
        return;
      }
      if (double.tryParse(priceText) == null) {
        _showSnack("Price for $rt must be numeric");
        return;
      }
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm"),
        content: const Text("Do you want to save this pg and upload selected images?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Confirm")),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      isSaving = true;
    });

    try {
      final Map<String, dynamic> body = {
        'pg_id': widget.pgData?['PG_ID'] ?? '',
        'partner_id': widget.partnerId,
        'pg_name': controllers["PG_Name"]?.text.trim() ?? '',
        'pg_type': selectedPGType ?? '',
        'room_type': selectedRoomTypes.join(','),
        'room_price': selectedRoomTypes.map((rt) => roomPriceControllers[rt]?.text.trim() ?? '').join(','),
        'address': controllers["Address"]?.text.trim() ?? '',
        'city': controllers["City"]?.text.trim() ?? '',
        'state': controllers["State"]?.text.trim() ?? '',
        'country': controllers["Country"]?.text.trim() ?? '',
        'pincode': controllers["Pincode"]?.text.trim() ?? '',
        'total_single_sharing_rooms': controllers["Total_Single_Sharing_Rooms"]?.text.trim() ?? '',
        'total_double_sharing_rooms': controllers["Total_Double_Sharing_Rooms"]?.text.trim() ?? '',
        'total_three_sharing_rooms': controllers["Total_Three_Sharing_Rooms"]?.text.trim() ?? '',
        'total_four_sharing_rooms': controllers["Total_Four_Sharing_Rooms"]?.text.trim() ?? '',
        'total_five_sharing_rooms': controllers["Total_Five_Sharing_Rooms"]?.text.trim() ?? '',
        'available_rooms': availableRoomsController.text.trim().isEmpty
            ? controllers["Total_Double_Sharing_Rooms"]?.text.trim() ?? ''
            : availableRoomsController.text.trim(),
        'amenities': controllers['Amenities']?.text.trim() ?? '',
        'description': controllers["Description"]?.text.trim() ?? '',
        'policies': policies.entries.where((e) => e.value).map((e) => e.key).join(','),
        'rating': ratingController.text.trim(),
        'pg_contact': controllers["PG_Contact"]?.text.trim() ?? '',
        'about_this_property': aboutController.text.trim(),
        'pg_location': "${latitude ?? ''},${longitude ?? ''}",
        'status': "Active",
      };

      // Attach images as base64
      Map<String, List<String>> base64Images = {};
      for (var category in categories) {
        final imgs = localImages[category]!;
        if (imgs.isNotEmpty) {
          base64Images[category] = imgs.map((img) => base64Encode(img.bytes!)).toList();
        }
      }

      if (base64Images.isNotEmpty) {
        body['images'] = jsonEncode(base64Images); // backend must parse this
      }

      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/webaddpgs'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body.map((k, v) => MapEntry(k, v.toString())),
      );

      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        if (decoded['status'] == 'success' || decoded['status'] == true) {
          _showSnack("PG saved successfully");
          setState(() => showSuccess = true);
          await Future.delayed(const Duration(milliseconds: 700));
          if (!mounted) return;
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ViewHotelsPage(partnerId: widget.partnerId)));
        } else {
          final msg = decoded['message'] ?? res.body;
          _showSnack("Save failed: $msg");
        }
      } else {
        _showSnack("Server error: ${res.statusCode}");
      }
    } catch (e) {
      _showSnack("Error saving PG: $e");
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Top nav bar with requested greenAccent shade
      appBar: AppBar(
        backgroundColor: Colors.greenAccent.shade700,
        title: const Text("Add Paying Guests"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          AnimatedScale(
            scale: showSuccess ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            child: const Padding(
              padding: EdgeInsets.only(right: 12.0),
              child: Icon(Icons.check_circle, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
      // Page background as requested
      backgroundColor: Colors.greenAccent.shade100,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Container(
                padding: const EdgeInsets.all(24),
                // remove glassy effect -> solid white card with subtle shadow
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 30, offset: Offset(0, 12))],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 4),
                    // Title row removed icon/back as we now have AppBar. Keep heading for larger UI.
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12.0),
                      child: Text("Add PGs",
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
                    ),
                    Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 700),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...fields.map((f) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: buildTextField(f),
                              )),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: TextFormField(
                                  controller: locationController,
                                  readOnly: true,
                                  onTap: pickLocation,
                                  decoration: InputDecoration(
                                    labelText: "PG Location (Click to select on map)",
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Colors.green.shade900, width: 2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    suffixIcon: const Icon(Icons.location_on, color: Colors.black54),
                                  ),
                                  validator: (v) => v == null || v.isEmpty ? "Required" : null,
                                ),
                              ),
                              const SizedBox(height: 12),
                              buildDropdown(),
                              const SizedBox(height: 12),
                              const SizedBox(height: 12),
                              buildRoomTypeSection(700),
                              const SizedBox(height: 12),
                              buildAmenitiesInput(700),
                              const SizedBox(height: 12),
                              buildPoliciesSection(),
                              const SizedBox(height: 12),
                              buildUploadImagesButton(700),
                              const SizedBox(height: 16),
                              if (showImageSections) buildImageSections(),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: aboutController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  labelText: "About This Property",
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.green.shade900, width: 2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: ratingController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        labelText: "Rating (0.0 - 5.0)",
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(color: Colors.green.shade900, width: 2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      validator: (v) {
                                        if (v == null || v.isEmpty) return "Required";
                                        final d = double.tryParse(v);
                                        if (d == null) return "Invalid";
                                        if (d < 0 || d > 5) return "Must be 0.0 - 5.0";
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Use GradientButton for "Add Hotel" with same callback
                                  SizedBox(
                                    height: 56,
                                    child: GradientButton(
                                      onPressed: isSaving ? null : saveHotel,
                                      padding: const EdgeInsets.symmetric(horizontal: 18),
                                      child: isSaving
                                          ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                          SizedBox(width: 8),
                                          Text("Saving...", style: TextStyle(color: Colors.white))
                                        ],
                                      )
                                          : const Text("Add PG", style: TextStyle(color: Colors.white)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            buildPreviewCard(),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              width: 300,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text("Tips", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                                  SizedBox(height: 8),
                                  Text(
                                      "- Use clear photos for Facade and Lobby.\n- Max 5MB per image.\n- Up to 10 images per category.\n- All images are uploaded together with the form.",
                                      style: TextStyle(color: Colors.black54)),
                                ],
                              ),
                            ),
                          ],
                        )
                      ],
                    )
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------- MODEL ---------------------
class LocalPickedImage {
  final String name;
  final Uint8List? bytes;
  final String? path;

  LocalPickedImage({required this.name, required this.bytes, required this.path});
}

// -------------------- MAP PICKER ---------------------
class MapPickerPage extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  const MapPickerPage({this.initialLat, this.initialLng, Key? key}) : super(key: key);

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  late CameraPosition _initialPosition;
  LatLng? pickedLocation;

  final TextEditingController latController = TextEditingController();
  final TextEditingController lngController = TextEditingController();

  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _determineInitialPosition();
  }

  Future<void> _determineInitialPosition() async {
    double lat, lng;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      lat = widget.initialLat ?? position.latitude;
      lng = widget.initialLng ?? position.longitude;
    } catch (e) {
      lat = widget.initialLat ?? 20.5937;
      lng = widget.initialLng ?? 78.9629;
    }

    setState(() {
      pickedLocation = LatLng(lat, lng);
      _initialPosition = CameraPosition(target: pickedLocation!, zoom: 15);

      latController.text = pickedLocation!.latitude.toStringAsFixed(6);
      lngController.text = pickedLocation!.longitude.toStringAsFixed(6);
    });
  }

  void _updateLocationFromFields() {
    final lat = double.tryParse(latController.text);
    final lng = double.tryParse(lngController.text);

    if (lat != null && lng != null) {
      setState(() {
        pickedLocation = LatLng(lat, lng);
        _mapController?.animateCamera(CameraUpdate.newLatLng(pickedLocation!));
      });
    }
  }

  @override
  void dispose() {
    latController.dispose();
    lngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pick PG Location"),
        backgroundColor: Colors.greenAccent.shade700,
        actions: [
          TextButton(
            onPressed: () {
              if (pickedLocation != null) {
                Navigator.pop(context, {
                  'lat': pickedLocation!.latitude,
                  'lng': pickedLocation!.longitude,
                });
              }
            },
            child: const Text("Done", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: pickedLocation == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: latController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: "Latitude", border: OutlineInputBorder()),
                    onChanged: (_) => _updateLocationFromFields(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: lngController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: "Longitude", border: OutlineInputBorder()),
                    onChanged: (_) => _updateLocationFromFields(),
                  ),
                )
              ],
            ),
          ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: _initialPosition,
              onMapCreated: (controller) => _mapController = controller,
              onTap: (pos) {
                setState(() {
                  pickedLocation = pos;
                  latController.text = pos.latitude.toStringAsFixed(6);
                  lngController.text = pos.longitude.toStringAsFixed(6);
                });
              },
              markers: pickedLocation != null ? {Marker(markerId: const MarkerId("picked"), position: pickedLocation!)} : {},
            ),
          ),
        ],
      ),
    );
  }
}
