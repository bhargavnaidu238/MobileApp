import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'hotel_payment.dart';
import 'package:http/http.dart' as http;
import 'package:hotel_booking_app/services/api_service.dart';

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

  int adults = 1;
  int children = 0;
  int rooms = 1;
  int persons = 1;
  int months = 1;

  String selectedRoomType = '';
  bool isFetchingPhone = false;
  bool _disposed = false;

  DateTime? checkInDate;
  DateTime? checkOutDate;

  bool wantsCustomization = false;
  Map<String, dynamic> customizationSelection = {};
  double customizationPrice = 0.0;
  bool showSummary = false;

  Map<String, bool> selectedExtraRooms = {};

  final Color primaryGreen = const Color(0xFF2E7D32);
  final Color scaffoldBg = const Color(0xFFE1EDD8);

  bool get isPgMode {
    if (hotel['is_hotel'] == true) return false;
    if (hotel.containsKey('PG_ID') || hotel.containsKey('PG_Name')) return true;
    if ((hotel['Hotel_Name'] ?? '').toString().trim().isEmpty &&
        (hotel['PG_Name'] ?? '').toString().trim().isNotEmpty) {
      return true;
    }
    return false;
  }

  Map<String, dynamic> get availableRoomsMap {
    if (hotel['Available_Rooms_Map'] != null && hotel['Available_Rooms_Map'] is Map) {
      return Map<String, dynamic>.from(hotel['Available_Rooms_Map']);
    }
    final rawData = hotel['Room_Price'] ?? hotel['Room_Prices'] ?? hotel['room_price'];
    if (rawData is Map) return Map<String, dynamic>.from(rawData);
    if (rawData is String && rawData.isNotEmpty) {
      Map<String, dynamic> parsed = {};
      try {
        final parts = rawData.split(',');
        for (var part in parts) {
          final kv = part.split(':');
          if (kv.length >= 2) {
            parsed[kv[0].trim()] = kv[1].trim();
          }
        }
        return parsed;
      } catch (e) {
        return {};
      }
    }
    return {};
  }

  @override
  void initState() {
    super.initState();
    hotel = Map<String, dynamic>.from(widget.hotel);
    user = Map<String, dynamic>.from(widget.user);

    final initName = (user['Guest_Name'] ?? user['name'] ?? "${(user['firstName'] ?? '')} ${(user['lastName'] ?? '')}".trim() ?? user['username'] ?? "").toString();
    final initEmail = (user['Email'] ?? user['email'] ?? user['mail'] ?? "").toString();
    final initPhone = (user['Mobile'] ?? user['mobile'] ?? user['phone'] ?? "").toString();

    nameController = TextEditingController(text: initName);
    emailController = TextEditingController(text: initEmail);
    phoneController = TextEditingController(text: initPhone);

    if (user['Check_In_Date'] != null) {
      try {
        List<String> d = user['Check_In_Date'].toString().split('-');
        checkInDate = DateTime(int.parse(d[2]), int.parse(d[1]), int.parse(d[0]));
      } catch (e) { checkInDate = DateTime.now(); }
    } else {
      checkInDate = DateTime.now();
    }

    if (user['Check_Out_Date'] != null) {
      try {
        List<String> d = user['Check_Out_Date'].toString().split('-');
        checkOutDate = DateTime(int.parse(d[2]), int.parse(d[1]), int.parse(d[0]));
      } catch (e) { checkOutDate = DateTime.now().add(const Duration(days: 1)); }
    } else if (!isPgMode) {
      checkOutDate = DateTime.now().add(const Duration(days: 1));
    }

    if (isPgMode) {
      persons = int.tryParse(user['Persons']?.toString() ?? hotel['Persons']?.toString() ?? '1') ?? 1;
      months = int.tryParse(user['Months']?.toString() ?? hotel['Months']?.toString() ?? '1') ?? 1;
    } else {
      rooms = int.tryParse(user['Total_Rooms_Booked']?.toString() ?? '1') ?? 1;
      adults = int.tryParse(user['Adults']?.toString() ?? '1') ?? 1;
    }

    if (phoneController.text.trim().isEmpty && emailController.text.trim().isNotEmpty) {
      _fetchPhoneFromProfile(emailController.text.trim());
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

  String get hotelName => (hotel['Hotel_Name'] ?? hotel['HotelName'] ?? hotel['Name'] ?? hotel['PG_Name'] ?? '').toString();
  String get hotelAddress {
    final address = hotel['Address'] ?? hotel['Hotel_Address'] ?? hotel['Hotel_Location'] ?? hotel['PG_Location'] ?? '';
    final city = hotel['City'] ?? '';
    final state = hotel['State'] ?? '';
    final country = hotel['Country'] ?? '';
    final pincode = hotel['Pincode'] ?? '';
    final parts = [address, city, state, country, pincode].where((e) => e != null && e.toString().trim().isNotEmpty).map((e) => e.toString().trim()).toList();
    return parts.isEmpty ? '' : parts.join(', ');
  }
  String get hotelContact => (hotel['Hotel_Contact'] ?? hotel['Contact'] ?? hotel['Phone'] ?? hotel['PG_Contact'] ?? '').toString();

  int get daysOfStay {
    if (checkInDate == null || checkOutDate == null) return 0;
    final diff = checkOutDate!.difference(checkInDate!).inDays;
    return diff >= 0 ? diff : 0;
  }

  double get roomPricePerDay {
    final rp = hotel['Selected_Room_Price'] ?? hotel['Room_Price'] ?? hotel['room_price'] ?? hotel['RoomPrice'] ?? hotel['Price'] ?? '';
    final s = rp?.toString() ?? '';
    if (s.isEmpty) return 0.0;
    final first = s.split(',').first.trim();
    final cleaned = first.split(':').last.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  double get totalRoomPricePerDay {
    int extraCount = selectedExtraRooms.values.where((v) => v == true).length;
    int baseTypeCount = (rooms - extraCount) > 0 ? (rooms - extraCount) : 1;
    double total = roomPricePerDay * baseTypeCount;
    selectedExtraRooms.forEach((type, isSelected) {
      if (isSelected) {
        final p = availableRoomsMap[type]?.toString() ?? '0';
        total += double.tryParse(p.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
      }
    });
    return total;
  }

  double get allDayPrice => totalRoomPricePerDay * (daysOfStay > 0 ? daysOfStay : 1);

  double get pgMonthlyPrice {
    final selPrice = hotel['Selected_Room_Price'] ?? hotel['selected_room_price'];
    if (selPrice != null) return double.tryParse(selPrice.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    if (availableRoomsMap.isEmpty) return 0.0;
    final key = (hotel['Selected_Room_Type'] ?? selectedRoomType ?? '').toString();
    if (key.isNotEmpty && availableRoomsMap.containsKey(key)) return double.tryParse(availableRoomsMap[key].toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    return double.tryParse(availableRoomsMap.values.first.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
  }

  double get pgTotalForMonths => pgMonthlyPrice * persons * months;
  double get gst => 0.05 * ((isPgMode ? pgTotalForMonths : allDayPrice) + customizationPrice);
  double get totalAmount => (isPgMode ? pgTotalForMonths : allDayPrice) + customizationPrice + gst;

  void _updateRooms() {
    final totalGuests = adults + children;
    if (totalGuests > 4) {
      int calculatedRooms = (totalGuests / 4).ceil();
      if (rooms < calculatedRooms) rooms = calculatedRooms;
    }
    int maxAllowed = rooms - 1;
    int current = selectedExtraRooms.values.where((v) => v == true).length;
    if (current > maxAllowed) selectedExtraRooms.clear();
    if (!_disposed) setState(() {});
  }

  Future<void> _fetchPhoneFromProfile(String email) async {
    setState(() => isFetchingPhone = true);
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/updateProfile?email=${Uri.encodeComponent(email)}&userId=${Uri.encodeComponent(widget.userId)}');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (!_disposed && response.statusCode == 200 && response.body.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final fetchedPhone = (data['mobile'] ?? data['phone'] ?? "").toString();
        if (fetchedPhone.trim().isNotEmpty) phoneController.text = fetchedPhone.trim();
      }
    } catch (e) {} finally { if (!_disposed) setState(() => isFetchingPhone = false); }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 16.0),
      child: Text(title, style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildDesignCard({required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16.0), child: Column(children: children)),
    );
  }

  Widget _buildCounter(String label, int value, Function(int) onChanged, {bool allowZero = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        Row(children: [
          IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: (value > (allowZero ? 0 : 1)) ? () => onChanged(value - 1) : null),
          Text("$value", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.green), onPressed: () => onChanged(value + 1)),
        ])
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayHotelName = hotelName.isNotEmpty ? hotelName : (isPgMode ? 'Paying Guest' : 'Hotel');
    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(title: Text("Booking - $displayHotelName"), backgroundColor: primaryGreen, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: showSummary ? _buildSummary() : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    int maxExtraSelectable = rooms - 1;
    int currentSelectedCount = selectedExtraRooms.values.where((v) => v == true).length;

    return Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildSectionHeader("GUEST INFORMATION"),
        _buildDesignCard(children: [
          TextFormField(
            controller: nameController,
            decoration: InputDecoration(labelText: "Full Name", prefixIcon: Icon(Icons.person, color: primaryGreen), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            validator: (val) => val == null || val.isEmpty ? "Enter Name" : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: emailController,
            decoration: InputDecoration(labelText: "Email Address", prefixIcon: Icon(Icons.email, color: primaryGreen), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: phoneController,
            decoration: InputDecoration(
              labelText: "Mobile",
              prefixIcon: Icon(Icons.phone, color: primaryGreen),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: isFetchingPhone ? const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null,
            ),
            keyboardType: TextInputType.text,
          ),
        ]),

        _buildSectionHeader("STAY DATES"),
        _buildDesignCard(children: [
          Row(children: [
            Expanded(child: _buildDateBox("Check-In", checkInDate, () async {
              DateTime? selected = await showDatePicker(context: context, initialDate: checkInDate ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 365)));
              if (selected != null) { setState(() { checkInDate = selected; if (!isPgMode && (checkOutDate == null || checkOutDate!.isBefore(checkInDate!.add(const Duration(days: 1))))) checkOutDate = checkInDate!.add(const Duration(days: 1)); }); }
            })),
            const SizedBox(width: 10),
            Expanded(child: _buildDateBox("Check-Out", checkOutDate, () async {
              DateTime? selected = await showDatePicker(context: context, initialDate: checkOutDate ?? (checkInDate ?? DateTime.now()).add(const Duration(days: 1)), firstDate: (checkInDate ?? DateTime.now()).add(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 366)));
              if (selected != null) setState(() => checkOutDate = selected);
            })),
          ]),
        ]),

        _buildSectionHeader(isPgMode ? "PG SELECTION" : "ROOMS & GUESTS"),
        _buildDesignCard(children: [
          if (!isPgMode) ...[
            _buildCounter("Adults", adults, (val) { adults = val; _updateRooms(); }),
            const Divider(),
            _buildCounter("Children", children, (val) { children = val; _updateRooms(); }, allowZero: true),
            const Divider(),
            _buildCounter("Rooms", rooms, (val) { setState(() => rooms = val); _updateRooms(); }),
          ] else ...[
            _buildCounter("Persons", persons, (val) => setState(() => persons = val)),
            const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("Months", style: TextStyle(fontSize: 16)),
              DropdownButton<int>(value: months, items: List.generate(12, (i) => i + 1).map((m) => DropdownMenuItem<int>(value: m, child: Text("$m month${m > 1 ? 's' : ''}"))).toList(), onChanged: (v) => setState(() => months = v!)),
            ]),
          ],
        ]),

        if (!isPgMode && rooms > 1 && availableRoomsMap.isNotEmpty) ...[
          _buildSectionHeader("SELECT EXTRA ROOM TYPES"),
          _buildDesignCard(children: [
            Text("Default Selection: 1x ${hotel['Selected_Room_Type']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
            Text("Remaining selection count: ${maxExtraSelectable - currentSelectedCount}", style: const TextStyle(fontSize: 12, color: Colors.orange)),
            const Divider(),
            ...availableRoomsMap.entries.where((e) => e.key != hotel['Selected_Room_Type']).map((entry) {
              bool isChecked = selectedExtraRooms[entry.key.toString()] ?? false;
              bool canSelectMore = currentSelectedCount < maxExtraSelectable;
              return CheckboxListTile(
                activeColor: primaryGreen,
                contentPadding: EdgeInsets.zero,
                title: Text(entry.key.toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                subtitle: Text("Price: ₹${entry.value}"),
                value: isChecked,
                onChanged: (canSelectMore || isChecked) ? (bool? val) => setState(() => selectedExtraRooms[entry.key.toString()] = val ?? false) : null,
              );
            }).toList(),
          ]),
        ],

        const SizedBox(height: 30),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text("REVIEW BOOKING", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), onPressed: () {
          if (_formKey.currentState!.validate()) {
            if (!isPgMode && daysOfStay <= 0) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Check-out date must be after Check-in"))); return; }
            setState(() => showSummary = true);
          }
        })),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _buildDateBox(String title, DateTime? date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          Text(date == null ? "Select" : "${date.day}-${date.month}-${date.year}", style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Widget _buildSummary() {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final partnerId = hotel['Partner_ID'] ?? hotel['partner_id'] ?? '';
    final hotelId = hotel['Hotel_ID'] ?? hotel['hotel_id'] ?? hotel['PG_ID'] ?? hotel['pg_id'] ?? '';

    String mainRoom = (hotel['Selected_Room_Type'] ?? hotel['selected_room_type'] ?? "").toString();
    String extraRoomsStr = selectedExtraRooms.entries.where((e) => e.value).map((e) => e.key).join(", ");

    // Keys MUST match Java Backend exactly
    Map<String, dynamic> bookingData = {
      "partner_id": partnerId,
      "hotel_id": hotelId,
      "hotel_name": hotelName,
      "guest_name": name,
      "email": email,
      "user_id": widget.userId.isNotEmpty ? widget.userId : (user['User_ID'] ?? user['userId'] ?? ""),
      "mobile": phone,
      "payment_method_type": "Online",
      "paid_via": "Wallet/Online",
      "payment_status": "Pending",
      "hotel_address": hotelAddress,
      "hotel_contact": hotelContact,
      "total_price": totalAmount.toStringAsFixed(2),
      "final_payable_amount": totalAmount.toStringAsFixed(2),
      "original_total_price": totalAmount.toStringAsFixed(2),
      "amount_paid_online": totalAmount.toStringAsFixed(2),
      "due_amount_at_hotel": "0.0",
      "wallet_amount": "0.0",
      "wallet_used": "No",
      "coupon_discount_amount": "0.0",
      "coupon_code": "",
      "gst": gst.toStringAsFixed(2),
      "check_in_date": "${checkInDate!.day}-${checkInDate!.month}-${checkInDate!.year}",
    };

    if (!isPgMode) {
      bookingData.addAll({
        "hotel_type": hotel['Hotel_Type'] ?? hotel['hotel_type'] ?? "Hotel",
        "check_out_date": "${checkOutDate!.day}-${checkOutDate!.month}-${checkOutDate!.year}",
        "guest_count": (adults + children),
        "adults": adults,
        "children": children,
        "total_rooms_booked": rooms,
        "total_days_at_stay": daysOfStay,
        "room_price_per_day": totalRoomPricePerDay.toStringAsFixed(2),
        "all_days_price": allDayPrice.toStringAsFixed(2),
        "room_type": mainRoom + (extraRoomsStr.isNotEmpty ? ", $extraRoomsStr" : ""),
      });
    } else {
      bookingData.addAll({
        "hotel_type": "PG",
        "selected_room_type": mainRoom,
        "room_price_per_month": pgMonthlyPrice.toStringAsFixed(2),
        "All_months_Price": pgTotalForMonths.toStringAsFixed(2),
        "months": months,
        "Persons": persons,
        "check_out_date": checkOutDate == null ? "" : "${checkOutDate!.day}-${checkOutDate!.month}-${checkOutDate!.year}",
      });
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildSectionHeader("A) BOOKING SUMMARY"),
      _buildDesignCard(children: [
        _summaryRow("Property", hotelName),
        _summaryRow("Customer Name", name),
        _summaryRow("Email", email),
        _summaryRow("Mobile", phone),
        if (!isPgMode) ...[
          _summaryRow("Check-In Date", bookingData["check_in_date"]),
          _summaryRow("Check-Out Date", bookingData["check_out_date"]),
          _summaryRow("Days of Stay", "$daysOfStay"),
          _summaryRow("Rooms", "$rooms"),
          _summaryRow("Room Type", mainRoom),
          if (extraRoomsStr.isNotEmpty) _summaryRow("Extra Rooms", extraRoomsStr),
        ] else ...[
          _summaryRow("Room Type", mainRoom),
          _summaryRow("Persons", "$persons"),
          _summaryRow("Months", "$months"),
        ],
      ]),

      _buildSectionHeader("B) BILLING DETAILS"),
      _buildDesignCard(children: [
        _summaryRow("Base Stay Price", "₹${(isPgMode ? pgTotalForMonths : allDayPrice).toStringAsFixed(2)}"),
        _summaryRow("GST (5%)", "₹${gst.toStringAsFixed(2)}"),
        const Divider(height: 20, thickness: 1),
        _summaryRow("Total Payable", "₹${totalAmount.toStringAsFixed(2)}"),
      ]),

      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        Expanded(
          child: ElevatedButton.icon(
              icon: const Icon(Icons.payment, color: Colors.white),
              label: const Text("Proceed to Payment", style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => HotelPaymentPage(bookingData: bookingData)))
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
              icon: const Icon(Icons.edit, color: Colors.white),
              label: const Text("Modify", style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () => setState(() => showSummary = false)
          ),
        ),
      ]),
      const SizedBox(height: 40),
    ]);
  }

  Widget _summaryRow(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: 4, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54))),
      Expanded(flex: 6, child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), softWrap: true)),
    ]));
  }
}