import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'hotel_payment.dart';
import 'package:http/http.dart' as http;
import 'package:hotel_booking_app/services/api_service.dart';
// import 'customization_page.dart'; // assuming this exists in your project

class BookingPage extends StatefulWidget {
  final Map hotel;
  final Map user;
  final String userId;

  const BookingPage({
    Key? key,
    required this.hotel,
    required this.user,
    this.userId = "",
  }) : super(key: key);

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final _formKey = GlobalKey<FormState>();

  late Map hotel;
  late Map user;

  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;

  // Hotel mode counters
  int adults = 1;
  int children = 0;
  int rooms = 1;

  // PG mode counters
  int persons = 1;
  int months = 1; // Months for PG booking (1..12)

  // keep selectedRoomType state for PG selection UI
  String selectedRoomType = '';

  bool isFetchingPhone = false;
  bool _disposed = false;

  DateTime? checkInDate;
  DateTime? checkOutDate;

  bool wantsCustomization = false;
  Map<String, dynamic> customizationSelection = {};
  double customizationPrice = 0.0;

  bool showSummary = false;

  // Mode detection
  bool get isPgMode {
    // Detect PG booking: presence of PG_ID or Selected_Room_Type or PG_Name
    if (hotel.containsKey('PG_ID') ||
        hotel.containsKey('Selected_Room_Type') ||
        hotel.containsKey('PG_Name')) return true;
    // Also if Hotel_Name absent but PG_Name present
    if ((hotel['Hotel_Name'] ?? '').toString().trim().isEmpty &&
        (hotel['PG_Name'] ?? '').toString().trim().isNotEmpty) {
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();

    hotel = Map<String, dynamic>.from(widget.hotel);
    user = Map<String, dynamic>.from(widget.user);

    final initName = (user['name'] ??
        "${(user['firstName'] ?? '')} ${(user['lastName'] ?? '')}".trim() ??
        user['username'] ??
        user['user_name'] ??
        user['Guest_Name'] ??
        user['Name'] ??
        "")
        .toString();
    final initEmail = (user['email'] ??
        user['mail'] ??
        user['username'] ??
        user['Email'] ??
        user['EmailAddress'] ??
        "")
        .toString();
    final initPhone = (user['mobile'] ??
        user['phone'] ??
        user['mobile_no'] ??
        user['Mobile'] ??
        user['mobileNumber'] ??
        user['MobileNumber'] ??
        "")
        .toString();

    nameController = TextEditingController(text: initName);
    emailController = TextEditingController(text: initEmail);
    phoneController = TextEditingController(text: initPhone);

    // ---- DATE INITIALIZATION (HOTEL vs PG) ----
    if (isPgMode) {
      // ✅ For PG: keep both dates empty by default (optional)
      checkInDate = DateTime.now();
      checkOutDate = null;
    } else {
      // ✅ For hotels: keep existing behaviour
      checkInDate = DateTime.now();
      checkOutDate = DateTime.now().add(const Duration(days: 1));
    }

    // If phone not present but email present, try to fetch
    if (phoneController.text.trim().isEmpty &&
        emailController.text.trim().isNotEmpty) {
      _fetchPhoneFromProfile(emailController.text.trim());
    }

    wantsCustomization = false;

    // If PG mode and hotel contains persons/months or selected values, init from those
    if (isPgMode) {
      persons =
      (hotel['Persons'] ?? hotel['persons'] ?? hotel['Guest_Count'] ?? 1)
      is int
          ? (hotel['Persons'] ??
          hotel['persons'] ??
          hotel['Guest_Count'] ??
          1)
          : int.tryParse((hotel['Persons'] ??
          hotel['persons'] ??
          hotel['Guest_Count'] ??
          '1')
          .toString()) ??
          1;

      months = (hotel['Months'] ?? hotel['months'] ?? 1) is int
          ? (hotel['Months'] ?? hotel['months'] ?? 1)
          : int.tryParse(
          (hotel['Months'] ?? hotel['months'] ?? '1').toString()) ??
          1;

      // Ensure months bounds 1..12
      if (months < 1) months = 1;
      if (months > 12) months = 12;

      // Initialize selectedRoomType from incoming hotel data if present
      final incomingRoomType =
      (hotel['Selected_Room_Type'] ?? hotel['SelectedRoomType'] ??
          hotel['Room_Type'] ??
          hotel['room_type'] ??
          '')
          .toString();
      if (incomingRoomType.isNotEmpty) {
        selectedRoomType = incomingRoomType;
      } else {
        // fallback: if Room_Price is a map with keys, pick first key as default
        final rp =
            hotel['Room_Price'] ?? hotel['Room_Prices'] ?? hotel['room_price'];
        if (rp is Map && rp.isNotEmpty) {
          selectedRoomType = rp.keys.first.toString();
        }
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  String get hotelName =>
      (hotel['Hotel_Name'] ??
          hotel['HotelName'] ??
          hotel['Name'] ??
          hotel['PG_Name'] ??
          '')
          .toString();

  String get hotelAddress {
    final address = hotel['Address'] ??
        hotel['Hotel_Address'] ??
        hotel['Hotel_Location'] ??
        hotel['PG_Location'] ??
        '';
    final city = hotel['City'] ?? '';
    final state = hotel['State'] ?? '';
    final country = hotel['Country'] ?? '';
    final pincode = hotel['Pincode'] ?? '';

    final parts = [address, city, state, country, pincode]
        .where((e) => e != null && e.toString().trim().isNotEmpty)
        .map((e) => e.toString().trim())
        .toList();

    return parts.isEmpty ? '' : parts.join(', ');
  }

  String get hotelContact =>
      (hotel['Hotel_Contact'] ??
          hotel['Contact'] ??
          hotel['Phone'] ??
          hotel['PG_Contact'] ??
          '')
          .toString();

  String get hotelAmenities =>
      (hotel['Amenities'] ?? hotel['Hotel_Amenities'] ?? '').toString();

  String get hotelRating => (hotel['Rating'] ?? '').toString();

  bool get customizationAllowed {
    final v = hotel['Customization'] ??
        hotel['Customization_Allowed'] ??
        hotel['customization'] ??
        hotel['customization_allowed'];
    if (v == null) return false;
    if (v is bool) return v;
    final s = v.toString().toLowerCase().trim();
    return s == 'yes' || s == 'true' || s == '1' || s == 'y';
  }

  int get daysOfStay {
    if (checkInDate == null || checkOutDate == null) return 0;
    final diff = checkOutDate!.difference(checkInDate!).inDays;
    return diff > 0 ? diff : 0;
  }

  // --- HOTEL mode: room price per day (existing)
  double get roomPricePerDay {
    final rp = hotel['Room_Price'] ??
        hotel['room_price'] ??
        hotel['RoomPrice'] ??
        hotel['Price'] ??
        '';
    final s = rp?.toString() ?? '';
    if (s.isEmpty) return 0.0;
    final first = s.split(',').first.trim();
    final cleaned = first.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  double get allDayPrice => roomPricePerDay * daysOfStay * rooms;

  // --- PG mode: monthly price
  double get pgMonthlyPrice {
    // Priority: Selected_Room_Price (string), Room_Price mapping, Room_Prices map
    final selPrice = hotel['Selected_Room_Price'] ?? hotel['selected_room_price'];
    if (selPrice != null) {
      final s = selPrice.toString();
      final cleaned = s.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }

    final rp = hotel['Room_Price'] ?? hotel['Room_Prices'] ?? hotel['room_price'];
    if (rp == null) return 0.0;

    try {
      // If Map with keys
      if (rp is Map) {
        // Try to get price for Selected_Room_Type (prefers local selectedRoomType then hotel value)
        final key = (hotel['Selected_Room_Type'] ??
            hotel['room_type'] ??
            hotel['Room_Type'] ??
            selectedRoomType ??
            '')
            .toString();
        if (key.isNotEmpty && rp.containsKey(key)) {
          final s = rp[key].toString();
          final cleaned = s.replaceAll(RegExp(r'[^0-9.]'), '');
          return double.tryParse(cleaned) ?? 0.0;
        }
        // otherwise, take first numeric
        final firstVal = rp.values.first.toString();
        final cleaned = firstVal.replaceAll(RegExp(r'[^0-9.]'), '');
        return double.tryParse(cleaned) ?? 0.0;
      }

      final s = rp.toString();
      // If comma-separated list, try to pick index based on Selected_Room_Type mapping fallback
      final parts = s
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll('"', '')
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (parts.isEmpty) return 0.0;

      // If Selected_Room_Type present, try mapping by order (Single, Double, Three, Four, Five)
      final selType =
      (hotel['Selected_Room_Type'] ?? selectedRoomType ?? '').toString().toLowerCase();
      if (selType.isNotEmpty) {
        if (selType.contains('single') && parts.length >= 1) {
          return double.tryParse(parts[0].replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
        } else if ((selType.contains('double') || selType.contains('two')) &&
            parts.length >= 2) {
          return double.tryParse(parts[1].replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
        } else if ((selType.contains('three') || selType.contains('3')) &&
            parts.length >= 3) {
          return double.tryParse(parts[2].replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
        } else if ((selType.contains('four') || selType.contains('4')) &&
            parts.length >= 4) {
          return double.tryParse(parts[3].replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
        } else if ((selType.contains('five') || selType.contains('5')) &&
            parts.length >= 5) {
          return double.tryParse(parts[4].replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
        }
      }
      // fallback to first
      return double.tryParse(parts[0].replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  // ✅ PG total should be: Price * Persons * Months
  double get pgTotalForMonths {
    final price = pgMonthlyPrice;
    return price * persons * months;
  }

  double get gst {
    // Keep GST 5% same for both modes
    final base = isPgMode ? pgTotalForMonths : allDayPrice;
    return 0.05 * (base + customizationPrice);
  }

  double get totalAmount {
    final base = isPgMode ? pgTotalForMonths : allDayPrice;
    return base + customizationPrice + gst;
  }

  void _updateRooms() {
    final totalGuests = adults + children;
    rooms = max((totalGuests / 4).ceil(), 1);
    if (!_disposed) setState(() {});
  }

  Future<void> _fetchPhoneFromProfile(String email) async {
    setState(() => isFetchingPhone = true);
    try {
      final uri = Uri.parse(
          '${ApiConfig.baseUrl}/updateProfile?email=${Uri.encodeComponent(email)}&userId=${Uri.encodeComponent(widget.userId)}');
      final response =
      await http.get(uri).timeout(const Duration(seconds: 8));
      if (!_disposed &&
          response.statusCode == 200 &&
          response.body.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final fetchedPhone =
        (data['mobile'] ?? data['phone'] ?? "").toString();
        if (fetchedPhone.trim().isNotEmpty) {
          phoneController.text = fetchedPhone.trim();
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch phone: $e');
    } finally {
      if (!_disposed) setState(() => isFetchingPhone = false);
    }
  }

  Widget _buildDateSelector(String label, DateTime? date, VoidCallback onTap) {
    final display =
    date == null ? "Optional" : "${date.day}-${date.month}-${date.year}";
    return GestureDetector(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(display, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildCounter(String label, int value, Function(int) onChanged,
      {bool allowZero = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        Row(children: [
          IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.red),
              onPressed: (value > (allowZero ? 0 : 1))
                  ? () => onChanged(value - 1)
                  : null),
          Text("$value",
              style:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.green),
              onPressed: () => onChanged(value + 1)),
        ])
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayRoomType = (hotel['Room_Type'] ??
        hotel['room_type'] ??
        hotel['Selected_Room_Type'] ??
        '')
        .toString();
    final displayHotelName =
    hotelName.isNotEmpty ? hotelName : (isPgMode ? 'Paying Guest' : 'Hotel');
    return Scaffold(
      appBar: AppBar(
          title: Text("Booking - $displayHotelName"),
          backgroundColor: Colors.green),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [
                Colors.lime.withOpacity(0.6),
                Colors.green.withOpacity(0.4)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
        ),
        child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            child: showSummary ? _buildSummary() : _buildForm()),
      ),
    );
  }

  Widget _buildForm() {
    // PG-specific extracted values
    final pgSelectedRoomType = (hotel['Selected_Room_Type'] ??
        hotel['SelectedRoomType'] ??
        hotel['Room_Type'] ??
        '')
        .toString();
    final pgSelectedRoomPrice =
    (hotel['Selected_Room_Price'] ?? hotel['SelectedRoomPrice'] ?? '')
        .toString();
    final pgPolicies =
    (hotel['Policies'] ?? hotel['PG_Policies'] ?? hotel['Rules'] ?? '')
        .toString();

    return Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Enter Booking Details",
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.brown[800])),
        const SizedBox(height: 20),

        TextFormField(
          controller: nameController,
          decoration: const InputDecoration(labelText: "Name"),
          validator: (val) => val == null || val.isEmpty ? "Enter Name" : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: emailController,
          decoration: const InputDecoration(labelText: "Email"),
          keyboardType: TextInputType.emailAddress,
          validator: (val) {
            if (val == null || val.isEmpty) return "Enter Email";
            final emailRegex = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");
            if (!emailRegex.hasMatch(val)) return "Enter a valid email";
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: phoneController,
          decoration: InputDecoration(
            labelText: "Mobile Number",
            hintText: "Enter mobile number",
            suffixIcon: isFetchingPhone
                ? const Padding(
                padding: EdgeInsets.all(12.0),
                child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)))
                : null,
          ),
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10)
          ],
          validator: (val) =>
          val == null || !RegExp(r'^\d{10}$').hasMatch(val)
              ? "Enter valid 10-digit number"
              : null,
        ),
        const SizedBox(height: 20),

        // Dates
        Row(children: [
          Expanded(
            child: _buildDateSelector("Check-in Date", checkInDate, () async {
              DateTime? selected = await showDatePicker(
                  context: context,
                  initialDate: checkInDate ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now().add(const Duration(days: 365)));
              if (selected != null) {
                setState(() {
                  checkInDate = selected;
                  // If hotel mode keep checkOut logic intact
                  if (!isPgMode &&
                      (checkOutDate == null ||
                          checkOutDate!
                              .isBefore(checkInDate!.add(const Duration(days: 1))))) {
                    checkOutDate = checkInDate!.add(const Duration(days: 1));
                  }
                });
              }
            }),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
            _buildDateSelector("Check-out Date", checkOutDate, () async {
              // For PG mode checkout optional; allow selecting or clearing
              if (isPgMode) {
                DateTime? selected = await showDatePicker(
                    context: context,
                    initialDate: checkOutDate ??
                        (checkInDate ?? DateTime.now())
                            .add(const Duration(days: 30)),
                    firstDate: checkInDate ?? DateTime.now(),
                    lastDate:
                    DateTime.now().add(const Duration(days: 365 * 2)));
                if (selected != null) {
                  setState(() {
                    checkOutDate = selected;
                  });
                }
              } else {
                DateTime? selected = await showDatePicker(
                    context: context,
                    initialDate: checkOutDate ??
                        (checkInDate ?? DateTime.now())
                            .add(const Duration(days: 1)),
                    firstDate:
                    (checkInDate ?? DateTime.now()).add(const Duration(days: 1)),
                    lastDate:
                    DateTime.now().add(const Duration(days: 366)));
                if (selected != null) {
                  setState(() {
                    checkOutDate = selected;
                  });
                }
              }
            }),
          ),
        ]),
        const SizedBox(height: 20),

        // Mode-specific UI
        if (!isPgMode) ...[
          // Existing hotel behavior: Adults, Children, Rooms
          _buildCounter("Adults", adults, (val) {
            adults = val;
            _updateRooms();
          }),
          _buildCounter("Children", children, (val) {
            children = val;
            _updateRooms();
          }),
          _buildCounter("Rooms", rooms, (val) => setState(() => rooms = val)),
        ] else ...[
          // PG mode: Hide Adults/Children/Rooms, show Room Type, Persons, Months
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(children: [
              const Icon(Icons.meeting_room, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                  child:
                  Text("Room Type", style: const TextStyle(fontSize: 16))),
              Text(
                  pgSelectedRoomType.isNotEmpty
                      ? pgSelectedRoomType
                      : (selectedRoomType.isNotEmpty
                      ? selectedRoomType
                      : "Not Selected"),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(height: 8),
          _buildCounter("Persons", persons, (val) {
            setState(() => persons = val);
          }, allowZero: false),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Months", style: TextStyle(fontSize: 16)),
                  DropdownButton<int>(
                    value: months,
                    items: List.generate(12, (i) => i + 1)
                        .map((m) => DropdownMenuItem<int>(
                        value: m,
                        child:
                        Text("$m month${m > 1 ? 's' : ''}")))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => months = v);
                    },
                  ),
                ]),
          ),
          const SizedBox(height: 12),
          // Show monthly price preview
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("Monthly Price", style: TextStyle(fontSize: 16)),
            Text("₹${pgMonthlyPrice.toStringAsFixed(2)}",
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("Total for selected months",
                style: TextStyle(fontSize: 16)),
            Text("₹${pgTotalForMonths.toStringAsFixed(2)}",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.green)),
          ]),
        ],

        const SizedBox(height: 20),

        if (customizationAllowed) ...[
          Text("Customize your stay?", style: const TextStyle(fontSize: 16)),
          Row(
            children: [
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text('Yes'),
                  value: true,
                  groupValue: wantsCustomization,
                  onChanged: (v) async {
                    setState(() => wantsCustomization = v ?? false);
                    if (v == true) {
                      final result = await Navigator.push<Map<String, dynamic>>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CustomizationPage(
                              hotel: hotel,
                              initialSelection: customizationSelection),
                        ),
                      );
                      if (result != null) {
                        setState(() {
                          customizationSelection = result;
                          customizationPrice =
                          (result['customizationPrice'] ?? 0.0) as double;
                        });
                      }
                    } else {
                      setState(() {
                        customizationSelection = {};
                        customizationPrice = 0.0;
                      });
                    }
                  },
                ),
              ),
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text('No'),
                  value: false,
                  groupValue: wantsCustomization,
                  onChanged: (v) {
                    setState(() {
                      wantsCustomization = v ?? false;
                      customizationSelection = {};
                      customizationPrice = 0.0;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ] else
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Text("Customization not available for this property.",
                style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          ),

        const SizedBox(height: 10),

        Center(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding:
                const EdgeInsets.symmetric(horizontal: 40, vertical: 12)),
            child: const Text("Review Booking",
                style: TextStyle(fontSize: 18)),
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                // For hotels: check daysOfStay > 0
                if (!isPgMode && daysOfStay <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          "Check-out date must be after Check-in")));
                  return;
                }
                // For PG mode: months must be >= 1
                if (isPgMode && (months < 1 || months > 120)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Please select valid months")));
                  return;
                }

                _formKey.currentState!.save();
                _updateRooms();
                setState(() => showSummary = true);
              }
            },
          ),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _buildSummary() {
    // We do NOT persist booking here. We prepare payload and hand over to payment page.
    String bookingId = "BKG${Random().nextInt(900000) + 100000}";

    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();

    // Common fields
    final baseHotelName = hotelName;
    final partnerId = hotel['Partner_ID'] ?? hotel['partner_id'] ?? '';
    final hotelId =
        hotel['Hotel_ID'] ?? hotel['hotel_id'] ?? hotel['PG_ID'] ?? hotel['pg_id'] ?? '';

    Map<String, dynamic> bookingData = {
      "Partner_ID": partnerId,
      "Hotel_ID": hotelId,
      "Booking_ID": bookingId,
      "Hotel_Name": baseHotelName,
      "Guest_Name": name,
      "Email": email,
      "User_ID": widget.userId.isNotEmpty
          ? widget.userId
          : (user['User_ID'] ??
          user['userId'] ??
          user['id'] ??
          user['user_id'] ??
          ""),
      "Payment_Type": "PENDING",
      "Hotel_Address": hotelAddress,
      "Hotel_Contact": hotelContact,
      "Hotel_Amenities": hotelAmenities,
      "Rating": hotelRating,
      "Booking_Status": "PENDING",
    };

    if (!isPgMode) {
      // Hotel flow — same as before
      bookingData.addAll({
        "Hotel_Type": hotel['Hotel_Type'] ?? hotel['HotelType'] ?? "",
        "Room_Type": hotel['Room_Type'] ?? hotel['room_type'] ?? "",
        "Check_In_Date":
        "${checkInDate!.day}-${checkInDate!.month}-${checkInDate!.year}",
        "Check_Out_Date":
        "${checkOutDate!.day}-${checkOutDate!.month}-${checkOutDate!.year}",
        "Guest_Count": (adults + children).toString(),
        "Adults": adults,
        "Children": children,
        "Total_Rooms_Booked": rooms,
        "Total_Days_at_Stay": daysOfStay,
        "Stay_Type": customizationSelection['stayType'] ?? "",
        "Type1": (customizationSelection['type1'] ?? []).join(", "),
        "Add_ons": (customizationSelection['addons'] ?? []).join(", "),
        "Room_Price_Per_Day": roomPricePerDay.toStringAsFixed(2),
        "All_Days_Price": allDayPrice.toStringAsFixed(2),
        "Customization_Price": customizationPrice.toStringAsFixed(2),
        "GST": gst.toStringAsFixed(2),
        "Total_Price": totalAmount.toStringAsFixed(2),
      });
    } else {
      // PG flow — monthly pricing, persons, months, selected room type, policies, availability, images
      final selRoomType = hotel['Selected_Room_Type'] ??
          hotel['SelectedRoomType'] ??
          hotel['Room_Type'] ??
          selectedRoomType ??
          '';
      final selRoomPrice =
          hotel['Selected_Room_Price'] ?? hotel['SelectedRoomPrice'] ?? hotel['Room_Price'] ?? '';
      final policies =
          hotel['Policies'] ?? hotel['PG_Policies'] ?? hotel['Rules'] ?? '';
      final availableCounts =
          hotel['Available_Counts'] ?? hotel['available_counts'] ?? {
            "Single":
            hotel['Total_Single_Sharing_Rooms'] ?? hotel['Total_Single_Sharing_Rooms'] ?? 0,
            "Double":
            hotel['Total_Double_ShARING_ROOMS'] ?? hotel['Total_Double_Sharing_Rooms'] ?? 0,
            "Three": hotel['Total_Three_Sharing_Rooms'] ?? 0,
            "Four": hotel['Total_Four_Sharing_Rooms'] ?? 0,
            "Five": hotel['Total_Five_Sharing_Rooms'] ?? 0,
          };

      // Use canonical monthly price numeric
      final monthlyPrice = pgMonthlyPrice;

      bookingData.addAll({
        "Room_Type": selRoomType,
        "Selected_Room_Type": selRoomType,
        "Selected_Room_Price": selRoomPrice.toString(),
        "Monthly_Price": monthlyPrice.toStringAsFixed(2),
        "Months": months,
        "Persons": persons,
        "Check_In_Date": checkInDate == null
            ? ""
            : "${checkInDate!.day}-${checkInDate!.month}-${checkInDate!.year}",
        // Check-out optional; include if present
        "Check_Out_Date": checkOutDate == null
            ? ""
            : "${checkOutDate!.day}-${checkOutDate!.month}-${checkOutDate!.year}",
        "Guest_Count": persons.toString(),
        "Total_Rooms_Booked": 1, // PG booking is per room; keep 1
        "Total_Months_Booked": months,
        "Room_Price_Per_Month": monthlyPrice.toStringAsFixed(2),
        // PG total = price * persons * months
        "All_Months_Price":
        (monthlyPrice * persons * months).toStringAsFixed(2),
        "Customization_Price": customizationPrice.toStringAsFixed(2),
        "GST": gst.toStringAsFixed(2),
        "Total_Price": totalAmount.toStringAsFixed(2),
        "Policies": policies,
        "Available_Counts": availableCounts,
        "PG_Images": hotel['PG_Images'] ??
            hotel['pg_images'] ??
            hotel['PG_Images_Normalized'] ??
            [],
        "Hotel_Location":
        hotel['Hotel_Location'] ?? hotel['PG_Location'] ?? hotelAddress,
      });
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("Booking Summary",
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.brown[800])),
      const SizedBox(height: 10),

      // Booking Details Card
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _summaryRow("Booking ID", bookingId),
            _summaryRow("Property", baseHotelName),
            _summaryRow("Customer", name),
            _summaryRow("Email", email),
            _summaryRow("Mobile", phone),
            if (!isPgMode) ...[
              _summaryRow("Check-in Date",
                  "${checkInDate!.day}-${checkInDate!.month}-${checkInDate!.year}"),
              _summaryRow("Check-out Date",
                  "${checkOutDate!.day}-${checkOutDate!.month}-${checkOutDate!.year}"),
              _summaryRow("Days of Stay", "$daysOfStay"),
              _summaryRow("Rooms", "$rooms"),
              _summaryRow("Adults", "$adults"),
              _summaryRow("Children", "$children"),
            ] else ...[
              _summaryRow("Selected Room Type",
                  bookingData["Selected_Room_Type"] ?? ""),
              _summaryRow("Persons", "${bookingData["Persons"]}"),
              _summaryRow("Months", "${bookingData["Months"]}"),
              if ((bookingData["Check_In_Date"] ?? "")
                  .toString()
                  .isNotEmpty)
                _summaryRow("Check-in Date", bookingData["Check_In_Date"]),
              if ((bookingData["Check_Out_Date"] ?? "")
                  .toString()
                  .isNotEmpty)
                _summaryRow("Check-out Date", bookingData["Check_Out_Date"]),
            ],
            if (customizationSelection.isNotEmpty) ...[
              _summaryRow("Stay Type",
                  customizationSelection['stayType'] ?? ""),
              _summaryRow(
                  "Type1 Selections",
                  (customizationSelection['type1'] ?? [])
                      .join(", ")),
              _summaryRow("Add-ons",
                  (customizationSelection['addons'] ?? []).join(", ")),
            ],
          ]),
        ),
      ),

      // Billing Card
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Text("Billing Details",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[900])),
            const SizedBox(height: 10),
            if (!isPgMode) ...[
              _summaryRow("Room Price/Day",
                  "₹${roomPricePerDay.toStringAsFixed(2)}"),
              _summaryRow("Total (Days × Rooms × Price)",
                  "₹${allDayPrice.toStringAsFixed(2)}"),
            ] else ...[
              _summaryRow("Room Price/Month",
                  "₹${pgMonthlyPrice.toStringAsFixed(2)}"),
              _summaryRow("Months", "$months"),
              _summaryRow("Persons", "$persons"),
              _summaryRow("Total (Price × Persons × Months)",
                  "₹${pgTotalForMonths.toStringAsFixed(2)}"),
            ],
            _summaryRow("Customization Price",
                "₹${customizationPrice.toStringAsFixed(2)}"),
            _summaryRow(
                "GST (5%)", "₹${gst.toStringAsFixed(2)}"),
            _summaryRow(
                "Total Amount", "₹${totalAmount.toStringAsFixed(2)}"),
          ]),
        ),
      ),

      const SizedBox(height: 8),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
              "Note: Customizations are applicable for only one day (hotel) or as specified (PG).",
              style: const TextStyle(fontStyle: FontStyle.italic))),
      const SizedBox(height: 16),

      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.payment),
          label: const Text("Proceed to Payment"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          onPressed: () async {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    HotelPaymentPage(bookingData: bookingData),
              ),
            );
          },
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.cancel),
          label: const Text("Cancel"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => setState(() => showSummary = false),
        ),
      ]),
      const SizedBox(height: 30),
    ]);
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child:
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            flex: 4,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16))),
        Expanded(
            flex: 6,
            child: Text(value,
                style: const TextStyle(fontSize: 16),
                softWrap: true)),
      ]),
    );
  }
}

// -------------------- Customization Page --------------------
// (unchanged — keep as you already have it)
class CustomizationPage extends StatefulWidget {
  final Map hotel;
  final Map<String, dynamic> initialSelection;

  const CustomizationPage({required this.hotel, required this.initialSelection, Key? key}) : super(key: key);

  @override
  State<CustomizationPage> createState() => _CustomizationPageState();
}

class _CustomizationPageState extends State<CustomizationPage> {
  String stayType = "Family"; // Family, Business, Vacation, Type4

  // Type1 options A,B,C,D with prices
  final List<Map<String, dynamic>> type1Options = [
    {"label": "A", "price": 100.0},
    {"label": "B", "price": 200.0},
    {"label": "C", "price": 300.0},
    {"label": "D", "price": 400.0},
  ];
  Map<String, bool> type1Selected = {};

  // Add-ons depending on hotel type
  List<Map<String, dynamic>> addons = [];
  Map<String, bool> addonsSelected = {};

  @override
  void initState() {
    super.initState();
    // load previous selection
    stayType = widget.initialSelection['stayType'] ?? "Family";

    final List initialType1 = (widget.initialSelection['type1'] ?? []);
    for (var opt in type1Options) {
      type1Selected[opt['label']] = initialType1.contains(opt['label']);
    }

    final hotelType = (widget.hotel['Hotel_Type'] ?? widget.hotel['HotelType'] ?? "").toString().toLowerCase();
    if (hotelType.contains('resort')) {
      addons = [
        {"label": "Firecamp", "price": 500.0},
        {"label": "Music Box", "price": 0.0},
        {"label": "Pool Party", "price": 1000.0},
        {"label": "Spa Session", "price": 800.0},
        {"label": "Bonfire Snacks", "price": 250.0},
      ];
    } else {
      addons = [
        {"label": "Meals (Menu at hotel)", "price": 0.0},
        {"label": "Snacks (Menu at hotel)", "price": 0.0},
        {"label": "Complimentary Tea/Coffee", "price": 0.0},
      ];
    }

    final List initialAddons = (widget.initialSelection['addons'] ?? []);
    for (var a in addons) {
      addonsSelected[a['label']] = initialAddons.contains(a['label']);
    }
  }

  double computeCustomizationPrice() {
    double total = 0.0;
    for (var opt in type1Options) {
      if (type1Selected[opt['label']] == true) total += opt['price'] as double;
    }
    for (var a in addons) {
      if (addonsSelected[a['label']] == true) total += a['price'] as double;
    }
    return total;
  }

  Widget _buildSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double spacing = 8.0;
    final stayTypes = ['Family', 'Business', 'Vacation', 'Type4'];

    return Scaffold(
      appBar: AppBar(title: const Text('Customize your stay'), backgroundColor: Colors.green, elevation: 1),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10),
        child: Column(children: [
          Expanded(
            child: ListView(shrinkWrap: true, physics: const BouncingScrollPhysics(), children: [
              _buildSectionTitle('Stay Type'),
              GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
                childAspectRatio: 3.8,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: stayTypes.map((t) {
                  final selected = (stayType == t);
                  return GestureDetector(
                    onTap: () => setState(() => stayType = t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: selected ? Colors.green.withOpacity(0.12) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: selected ? Colors.green : Colors.grey.shade300, width: selected ? 1.6 : 1),
                        boxShadow: selected ? [BoxShadow(color: Colors.green.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))] : null,
                      ),
                      child: Row(children: [
                        Radio<String>(value: t, groupValue: stayType, onChanged: (v) => setState(() => stayType = v!), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.compact),
                        const SizedBox(width: 4),
                        Flexible(child: Text(t, style: const TextStyle(fontSize: 14))),
                      ]),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              _buildSectionTitle('Type1 Options'),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: type1Options.map((opt) {
                  final lbl = opt['label'] as String;
                  final price = opt['price'] as double;
                  final checked = type1Selected[lbl] ?? false;
                  return SizedBox(
                    width: (MediaQuery.of(context).size.width - 48) / 2,
                    child: Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                      child: CheckboxListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        value: checked,
                        onChanged: (v) => setState(() => type1Selected[lbl] = v ?? false),
                        title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(lbl, style: const TextStyle(fontSize: 14)), Text('₹${price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13))]),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              _buildSectionTitle('Add-ons'),
              Column(children: addons.map((a) {
                final key = a['label'] as String;
                final price = a['price'] as double;
                final checked = addonsSelected[key] ?? false;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    value: checked,
                    onChanged: (v) => setState(() => addonsSelected[key] = v ?? false),
                    title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Flexible(child: Text(key, style: const TextStyle(fontSize: 14))), Text(price > 0 ? '₹${price.toStringAsFixed(0)}' : 'Menu-based', style: const TextStyle(fontSize: 13))]),
                  ),
                );
              }).toList()),
              const SizedBox(height: 8),
              Text('Note: Menu and food prices to be paid separately at hotel.', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              const SizedBox(height: 16),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Estimated customization', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('₹${computeCustomizationPrice().toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                ]),
              ),
              ElevatedButton(
                onPressed: () {
                  final selectedType1 = type1Selected.entries.where((e) => e.value).map((e) => e.key).toList();
                  final selectedAddons = addonsSelected.entries.where((e) => e.value).map((e) => e.key).toList();
                  final price = computeCustomizationPrice();
                  final result = {'stayType': stayType, 'type1': selectedType1, 'addons': selectedAddons, 'customizationPrice': price};
                  Navigator.pop(context, result);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Text('Save', style: TextStyle(fontSize: 14)),
              ),
            ]),
          )
        ]),
      ),
    );
  }
}
