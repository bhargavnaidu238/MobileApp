import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hotel_booking_app/services/api_service.dart';

class HotelPaymentPage extends StatefulWidget {
  final Map bookingData;

  const HotelPaymentPage({Key? key, required this.bookingData})
      : super(key: key);

  @override
  State<HotelPaymentPage> createState() => _HotelPaymentPageState();
}

class _HotelPaymentPageState extends State<HotelPaymentPage> {

  String selectedPayment = '';
  bool useWallet = false;
  bool _isProcessing = false;
  bool _bookingPosted = false; // guard to prevent double-post

  final TextEditingController couponController = TextEditingController();
  final TextEditingController upiController = TextEditingController();
  final TextEditingController cardNumberController = TextEditingController();
  final TextEditingController cardNameController = TextEditingController();
  final TextEditingController expiryController = TextEditingController();
  final TextEditingController cvvController = TextEditingController();

  // ---- PRICING + WALLET + COUPON STATE ----
  double _baseTotal = 0.0; // original Total_Price from booking
  double _payableAfterCoupon = 0.0; // baseTotal - couponDiscount
  double _finalPayable = 0.0; // after wallet deduction

  double _couponDiscount = 0.0;
  String? _appliedCouponCode;
  String? _appliedCouponTitle;
  String? _couponMessage;
  bool _couponValid = false;

  double _walletBalance = 0.0; // from DB
  double _walletMaxUsable = 0.0; // 50% of payableAfterCoupon (Option B)
  double _walletUsed = 0.0; // how much user is using this booking (B2 rule applied)

  @override
  void initState() {
    super.initState();
    _initPricesFromBooking();
    _fetchWalletFromDb();
  }

  void _initPricesFromBooking() {
    final rawTotal = widget.bookingData['Total_Price'];
    double parsed = 0.0;
    if (rawTotal is num) {
      parsed = rawTotal.toDouble();
    } else if (rawTotal is String) {
      parsed = double.tryParse(rawTotal) ?? 0.0;
    }
    _baseTotal = parsed;
    _payableAfterCoupon = _baseTotal;
    _finalPayable = _baseTotal;
  }

  Future<void> _fetchWalletFromDb() async {
    // We expect bookingData to contain 'User_ID'
    final userId = (widget.bookingData['User_ID'] ?? '').toString().trim();
    if (userId.isEmpty) {
      debugPrint("❌ No User_ID in bookingData, cannot fetch wallet");
      return;
    }

    try {
      final uri =
      Uri.parse("${ApiConfig.baseUrl}/wallet?userId=${Uri.encodeComponent(userId)}");
      debugPrint("📡 GET Wallet -> $uri");

      final resp =
      await http.get(uri).timeout(const Duration(seconds: 15));

      debugPrint("📩 Wallet status: ${resp.statusCode}");
      debugPrint("📩 Wallet body: ${resp.body}");

      if (resp.statusCode != 200) return;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final balance = (data["balance"] as num?)?.toDouble() ?? 0.0;

      setState(() {
        _walletBalance = balance;
      });

      _recalculateWalletUsage();
    } catch (e) {
      debugPrint("❌ Wallet fetch error: $e");
    }
  }

  // ---- COUPON ----

  Future<void> _applyCoupon() async {
    // ✅ Do NOT force uppercase – backend may be case-sensitive
    final code = couponController.text.trim();

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a coupon code.")),
      );
      return;
    }

    // ✅ Ensure userId exists
    final userId = (widget.bookingData['User_ID'] ?? '').toString().trim();
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not found for coupon validation.")),
      );
      return;
    }

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/coupon/validate');
      debugPrint("🔗 FINAL Coupon URL = $uri");
      // ✅ Force baseAmount to numeric double (prevents backend mismatch)
      final double baseAmount =
      double.parse(_baseTotal.toString());

      final body = jsonEncode({
        "userId": userId,
        "couponCode": code,
        "baseAmount": baseAmount,
      });

      debugPrint("📡 POST Coupon -> $uri");
      debugPrint("📤 Coupon Request Body: $body");
      debugPrint("💰 Base Amount Type: ${baseAmount.runtimeType}");

      final resp = await http
          .post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: body,
      )
          .timeout(const Duration(seconds: 20));

      debugPrint("📩 Coupon status: ${resp.statusCode}");
      debugPrint("📩 Coupon raw body: ${resp.body}");

      if (resp.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to validate coupon (${resp.statusCode})"),
          ),
        );
        return;
      }

      final Map<String, dynamic> data =
      jsonDecode(resp.body) as Map<String, dynamic>;

      debugPrint("🧾 Parsed Coupon Response: $data");

      // ✅ Defensive parsing – handles bool OR string
      final bool valid =
          data["valid"] != null && data["valid"].toString() == "true";

      final String message =
      (data["message"] ?? "").toString();

      final double discountAmount =
          (data["discountAmount"] as num?)?.toDouble() ?? 0.0;

      final double discountedAmount =
          (data["discountedAmount"] as num?)?.toDouble() ?? baseAmount;

      final String title =
      (data["couponTitle"] ?? code).toString();

      debugPrint("✅ Coupon valid: $valid");
      debugPrint("🏷️ Coupon title: $title");
      debugPrint("💸 Discount: $discountAmount");
      debugPrint("💰 Payable after coupon: $discountedAmount");

      if (!valid) {
        setState(() {
          _couponValid = false;
          _couponDiscount = 0.0;
          _payableAfterCoupon = baseAmount;
          _appliedCouponCode = null;
          _appliedCouponTitle = null;
          _couponMessage =
          message.isNotEmpty ? message : "Coupon invalid.";
        });

        _recalculateWalletUsage();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_couponMessage!)),
        );
        return;
      }

      // ✅ Coupon valid → apply coupon first, then wallet
      setState(() {
        _couponValid = true;
        _couponDiscount = discountAmount;
        _payableAfterCoupon = discountedAmount;
        _appliedCouponCode = code;
        _appliedCouponTitle = title;
        _couponMessage = "$title applied successfully";
      });

      _recalculateWalletUsage();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_couponMessage!)),
      );
    } catch (e, stack) {
      debugPrint("❌ Coupon error: $e");
      debugPrint("📉 Stacktrace: $stack");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error applying coupon. Please try again.")),
      );
    }
  }


  // ---- WALLET LOGIC (Option B + B2) ----
  //
  // B: Coupon is applied first
  // B2: Wallet can pay max 50% of payableAfterCoupon, but user must pay at least ₹1 via gateway

  void _recalculateWalletUsage() {
    final amountAfterCoupon = _payableAfterCoupon;

    // Step 1: max wallet allowed (50% of amountAfterCoupon)
    final fiftyPercent = amountAfterCoupon * 0.5;
    _walletMaxUsable =
    (_walletBalance < fiftyPercent) ? _walletBalance : fiftyPercent;

    double walletUse = 0.0;
    if (useWallet && amountAfterCoupon > 0) {
      // attempt to use max wallet
      walletUse = _walletMaxUsable;

      // B2 rule: user MUST pay at least ₹1
      final tempFinal = amountAfterCoupon - walletUse;
      if (tempFinal < 1.0) {
        final requiredWallet =
            amountAfterCoupon - 1.0; // leave ₹1 to pay
        if (requiredWallet <= 0) {
          walletUse = 0.0;
        } else {
          walletUse = requiredWallet.clamp(0.0, _walletMaxUsable);
        }
      }
    }

    final finalPayable =
    (amountAfterCoupon - walletUse).clamp(0.0, double.infinity);

    setState(() {
      _walletUsed = walletUse;
      _finalPayable = finalPayable;
    });
  }

  @override
  void dispose() {
    couponController.dispose();
    upiController.dispose();
    cardNumberController.dispose();
    cardNameController.dispose();
    expiryController.dispose();
    cvvController.dispose();
    super.dispose();
  }

  // ---------------- MOCK PAYMENT GATEWAY (Option B) ----------------

  Future<void> _openMockGateway(String paymentType) async {
    if (_finalPayable <= 0) {
      // just in case
      _confirmPayment(paymentType, paid: true);
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool processing = false;

        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lock, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text(
                          "Secure Payment Gateway (Mock)",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Paying to: ${widget.bookingData['Hotel_Name'] ?? 'Hotel'}",
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Payment Method: $paymentType",
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    if (useWallet && _walletUsed > 0)
                      Text(
                        "Wallet used: ₹${_walletUsed.toStringAsFixed(2)}",
                        style: const TextStyle(fontSize: 13),
                      ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Amount to Pay",
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600),
                          ),
                          Text(
                            "₹${_finalPayable.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (processing)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed:
                          processing ? null : () => Navigator.of(ctx).pop(),
                          child: const Text("Cancel"),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          onPressed: processing
                              ? null
                              : () async {
                            setStateDialog(() {
                              processing = true;
                            });
                            await Future.delayed(
                                const Duration(seconds: 1));
                            Navigator.of(ctx).pop();
                            // After "successful" payment → confirm
                            _confirmPayment(paymentType, paid: true);
                          },
                          child: Text(
                              "Pay ₹${_finalPayable.toStringAsFixed(2)}"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // CONFIRM PAYMENT → Create booking only after confirmation (once)
  Future<void> _confirmPayment(String paymentType, {bool paid = true}) async {
    if (_isProcessing || _bookingPosted) return;
    setState(() => _isProcessing = true);

    final booking = Map<String, dynamic>.from(widget.bookingData);

    final isPayAtHotel = paymentType.toLowerCase().contains("pay at hotel");
    final String paymentMethodType = isPayAtHotel ? "Pay at Hotel" : "Online";
    final String paidVia = isPayAtHotel ? "" : paymentType;
    final String paymentStatus = isPayAtHotel ? "Pending" : "Paid";

    double amountPaidOnline = isPayAtHotel ? 0.0 : _finalPayable;
    double dueAtHotel = isPayAtHotel ? _finalPayable : 0.0;

    // 🛠 FIXED — Add missing booking metadata back into payload
    booking["Check_In_Date"] = widget.bookingData["Check_In_Date"] ?? booking["Check_In_Date"];
    booking["Check_Out_Date"] = widget.bookingData["Check_Out_Date"] ?? booking["Check_Out_Date"];
    booking["Hotel_Contact"] = widget.bookingData["Hotel_Contact"];
    booking["Hotel_Address"] = widget.bookingData["Hotel_Address"];

    booking["Transaction_ID"] = isPayAtHotel
        ? ""
        : "TXN-${DateTime.now().millisecondsSinceEpoch}";

    // Payment + pricing metadata
    booking["Payment_Type"] = paymentMethodType;
    booking["Paid_Via"] = paidVia;
    booking["Payment_Status"] = paymentStatus;

    booking["Total_Price"] = _baseTotal;
    booking["Original_Total_Price"] = _baseTotal;
    booking["Final_Payable_Amount"] = _finalPayable;
    booking["Amount_Paid_Online"] = amountPaidOnline;
    booking["Due_Amount_At_Hotel"] = dueAtHotel;

    booking["Wallet_Used"] = useWallet ? "Yes" : "No";
    booking["Wallet_Amount"] = _walletUsed;
    booking["Coupon_Code"] = _appliedCouponCode ?? couponController.text.trim();
    booking["Coupon_Discount_Amount"] = _couponDiscount;

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/booking');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(booking),
      );

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        final bookingId = decoded["booking_id"]?.toString();

        _bookingPosted = true;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Booking Confirmed — ID: $bookingId")),
        );

        Future.delayed(const Duration(milliseconds: 900), () {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/history',
                (route) => true,
            arguments: {
              'email': booking['Email'],
              'userId': booking['User_ID']
            },
          );
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Booking failed: ${resp.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving booking: $e")),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }
  Widget _buildBookingSummary(Map booking) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.green.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            booking['Hotel_Name'] ?? 'Unknown Hotel',
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            booking['Hotel_Address'] ?? '',
            style:
            const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const Divider(color: Colors.white54, height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoItem(Icons.king_bed, "Room",
                  booking['Room_Type'] ?? 'Standard', Colors.white),
              _infoItem(
                  Icons.attach_money,
                  "Base Price",
                  "₹${_baseTotal.toStringAsFixed(2)}",
                  Colors.white),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoItem(Icons.calendar_today, "Check-In",
                  booking['Check_In_Date'] ?? '-', Colors.white),
              _infoItem(Icons.calendar_today_outlined, "Check-Out",
                  booking['Check_Out_Date'] ?? '-', Colors.white),
            ],
          ),
          const SizedBox(height: 12),

          // Pricing breakdown
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _priceRow("Base Amount", _baseTotal, Colors.white),
                _priceRow(
                    "Coupon Discount",
                    -_couponDiscount,
                    _couponDiscount > 0
                        ? Colors.lightGreenAccent
                        : Colors.white),
                _priceRow("Amount after Coupon",
                    _payableAfterCoupon, Colors.white),
                _priceRow(
                    "Wallet Used",
                    -_walletUsed,
                    _walletUsed > 0
                        ? Colors.amberAccent
                        : Colors.white),
                const Divider(color: Colors.white54),
                _priceRow("Final Payable", _finalPayable, Colors.white,
                    isBold: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, double amount, Color color,
      {bool isBold = false}) {
    final style = TextStyle(
      fontSize: 14,
      color: color,
      fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
    );
    final formatted = "₹${amount.toStringAsFixed(2)}";
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(formatted, style: style),
        ],
      ),
    );
  }

  Widget _infoItem(
      IconData icon, String label, String value, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: textColor.withOpacity(0.8))),
        ]),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: textColor)),
      ],
    );
  }

  Widget _buildPaymentButtons() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          "To Pay: ₹${_finalPayable.toStringAsFixed(2)}",
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.payment, color: Colors.white),
              label: const Text("Pay Now",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: (_isProcessing || _bookingPosted)
                  ? null
                  : () {
                String type;
                if (selectedPayment == 'UPI') {
                  type =
                  'UPI: ${upiController.text.trim()}';
                } else if (selectedPayment == 'Card') {
                  type =
                  'Card (${cardNameController.text.trim()})';
                } else if (selectedPayment.isNotEmpty) {
                  type = selectedPayment;
                } else {
                  type = 'Online Payment';
                }
                // Open Mock Gateway for online payments
                _openMockGateway(type);
              },
            ),
            ElevatedButton.icon(
              icon:
              const Icon(Icons.meeting_room, color: Colors.white),
              label: const Text("Pay at Hotel",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 30, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: (_isProcessing || _bookingPosted)
                  ? null
                  : () =>
                  _confirmPayment("Pay at Hotel", paid: false),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.bookingData;

    return Scaffold(
      appBar: AppBar(
          title: const Text("Confirm Payment"),
          backgroundColor: Colors.green),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBookingSummary(booking),
            const SizedBox(height: 20),

            // COUPON SECTION
            const Text("🎟 Apply Coupon",
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: couponController,
              decoration: InputDecoration(
                hintText: "Enter coupon code",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                suffixIcon: TextButton(
                  onPressed: _applyCoupon,
                  child: const Text("Apply"),
                ),
              ),
            ),
            if (_couponMessage != null &&
                _couponMessage!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  _couponMessage!,
                  style: TextStyle(
                    fontSize: 13,
                    color: _couponValid
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // WALLET SECTION
            Row(
              children: [
                Checkbox(
                  value: useWallet,
                  onChanged: (v) {
                    setState(() {
                      useWallet = v ?? false;
                    });
                    _recalculateWalletUsage();
                  },
                  activeColor: Colors.green,
                ),
                Expanded(
                  child: Text(
                    "Use Wallet (Available: ₹${_walletBalance.toStringAsFixed(2)} • Max this booking: ₹${_walletMaxUsable.toStringAsFixed(2)})",
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Text("💳 Choose Payment Method",
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text("PhonePe"),
                    value: "PhonePe",
                    groupValue: selectedPayment,
                    onChanged: (v) =>
                        setState(() => selectedPayment = v ?? ''),
                  ),
                  RadioListTile<String>(
                    title: const Text("Google Pay"),
                    value: "Google Pay",
                    groupValue: selectedPayment,
                    onChanged: (v) =>
                        setState(() => selectedPayment = v ?? ''),
                  ),
                  RadioListTile<String>(
                    title: const Text("Enter UPI ID"),
                    value: "UPI",
                    groupValue: selectedPayment,
                    onChanged: (v) =>
                        setState(() => selectedPayment = v ?? ''),
                  ),
                  if (selectedPayment == "UPI")
                    _buildUPISection(),
                  RadioListTile<String>(
                    title: const Text("Credit / Debit Card"),
                    value: "Card",
                    groupValue: selectedPayment,
                    onChanged: (v) =>
                        setState(() => selectedPayment = v ?? ''),
                  ),
                  if (selectedPayment == "Card")
                    _buildCardSection(),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildPaymentButtons(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildUPISection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          TextField(
            controller: upiController,
            decoration: const InputDecoration(
              hintText: "Enter your UPI ID",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              if (upiController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Enter UPI ID first")),
                );
                return;
              }
              final type = "UPI: ${upiController.text.trim()}";
              _openMockGateway(type);
            },
            label: const Text("Confirm & Pay"),
          ),
        ],
      ),
    );
  }

  Widget _buildCardSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          TextField(
            controller: cardNumberController,
            decoration: const InputDecoration(
                labelText: "Card Number",
                border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: cardNameController,
            decoration: const InputDecoration(
                labelText: "Name on Card",
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: expiryController,
                  decoration: const InputDecoration(
                      labelText: "Expiry (MM/YY)",
                      border: OutlineInputBorder()),
                  keyboardType: TextInputType.datetime,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: cvvController,
                  decoration: const InputDecoration(
                      labelText: "CVV",
                      border: OutlineInputBorder()),
                  obscureText: true,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.credit_card, color: Colors.white),
            label: const Text("Confirm & Pay"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              if (cardNumberController.text.isEmpty ||
                  cardNameController.text.isEmpty ||
                  expiryController.text.isEmpty ||
                  cvvController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Enter complete card details")),
                );
                return;
              }
              const type = "Card";
              _openMockGateway(type);
            },
          ),
        ],
      ),
    );
  }
}
