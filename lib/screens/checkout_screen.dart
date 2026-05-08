import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hypersdkflutter/hypersdkflutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/cart_provider.dart';
import '../services/payment_service.dart';

enum _PayState { form, creating, waiting, verifying, success, failed, error }

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _hyperSDK = HyperSDK();

  // ── State ──────────────────────────────────────────────────────────────────
  _PayState _state = _PayState.form;

  // ── Form controllers (persist across visits) ───────────────────────────────
  final _emailCtrl     = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _addressCtrl   = TextEditingController();
  final _cityCtrl      = TextEditingController();
  final _stateCtrl     = TextEditingController();
  final _pinCtrl       = TextEditingController();

  // ── Form fields ────────────────────────────────────────────────────────────
  String _firstName = '';
  String _email     = '';
  String _phone     = '';
  String _country   = 'India';

  // ── Payment result ─────────────────────────────────────────────────────────
  String? _orderId;
  String? _txnId;
  String? _errorMessage;
  double  _orderTotal = 0;
  bool    _processCalled = false;

  static const _countries = [
    'India', 'United States', 'United Kingdom', 'Canada', 'Australia',
  ];

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initiateHyperSDK();
    _loadSavedFields();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pinCtrl.dispose();
    _hyperSDK.dispose();
    super.dispose();
  }

  Future<void> _loadSavedFields() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _emailCtrl.text     = p.getString('co_email')     ?? '';
      _phoneCtrl.text     = p.getString('co_phone')     ?? '';
      _firstNameCtrl.text = p.getString('co_firstName') ?? '';
      _lastNameCtrl.text  = p.getString('co_lastName')  ?? '';
      _addressCtrl.text   = p.getString('co_address')   ?? '';
      _cityCtrl.text      = p.getString('co_city')      ?? '';
      _stateCtrl.text     = p.getString('co_state')     ?? '';
      _pinCtrl.text       = p.getString('co_pin')       ?? '';
      _country            = p.getString('co_country')   ?? 'India';
    });
  }

  Future<void> _saveFields() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('co_email',     _emailCtrl.text);
    await p.setString('co_phone',     _phoneCtrl.text);
    await p.setString('co_firstName', _firstNameCtrl.text);
    await p.setString('co_lastName',  _lastNameCtrl.text);
    await p.setString('co_address',   _addressCtrl.text);
    await p.setString('co_city',      _cityCtrl.text);
    await p.setString('co_state',     _stateCtrl.text);
    await p.setString('co_pin',       _pinCtrl.text);
    await p.setString('co_country',   _country);
  }

  // Boots the Juspay payment engine. Must complete before process() is called.
  Future<void> _initiateHyperSDK() async {
    try {
      if (!await _hyperSDK.isInitialised()) {
        await _hyperSDK.initiate(
          {
            'requestId': DateTime.now().millisecondsSinceEpoch.toString(),
            'service': 'in.juspay.hyperpay',
            'payload': {
              'action': 'initiate',
              'merchantId': 'iimkashipur',
              'clientId': 'aivo',
              'environment': 'sandbox',
            },
          },
          _hyperSDKCallbackHandler,
        );
      }
    } catch (_) {
      // Non-fatal; process() will trigger its own init if needed
    }
  }

  // ── Payment flow ───────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    await _saveFields();

    final cart     = context.read<CartProvider>();
    final subtotal = cart.total;
    final shipping = subtotal >= 75 ? 0.0 : 9.99;
    final tax      = subtotal * 0.08;
    _orderTotal    = subtotal + shipping + tax;
    _processCalled = false;

    setState(() => _state = _PayState.creating);

    try {
      // Derive a stable, alphanumeric customer_id from the email address
      final customerId = _email
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
          .substring(0, _email.length.clamp(0, 40));

      final session = await PaymentService.createSession(
        amount:        _orderTotal,
        customerId:    customerId,
        customerEmail: _email,
        customerPhone: _phone,
      );

      _orderId = session['order_id'] as String;
      final rawPayload = session['sdk_payload'];
      if (rawPayload == null) {
        throw const PaymentException('Invalid session: missing sdk_payload');
      }
      final sdkPayload = rawPayload is String
          ? jsonDecode(rawPayload) as Map<String, dynamic>
          : rawPayload as Map<String, dynamic>;

      // Ensure the SDK engine is ready before opening the payment sheet
      if (!await _hyperSDK.isInitialised()) {
        await _initiateHyperSDK();
      }

      setState(() => _state = _PayState.waiting);

      // Launch the Juspay payment sheet.
      // process() is instance-based; the callback fires on MethodChannel events.
      _processCalled = true;
      await _hyperSDK.process(sdkPayload, _hyperSDKCallbackHandler);
    } on PaymentException catch (e) {
      if (!mounted) return;
      setState(() {
        _state        = _PayState.error;
        _errorMessage = e.message;
      });
    } catch (e, st) {
      debugPrint('Payment error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _state        = _PayState.error;
        _errorMessage = 'Error: $e';
      });
    }
  }

  // Receives all MethodChannel events from the Juspay SDK
  void _hyperSDKCallbackHandler(MethodCall methodCall) {
    switch (methodCall.method) {
      case 'hide_loader':
        // SDK UI is ready — clear our own loading overlay
        if (mounted && _state == _PayState.waiting) {
          setState(() {}); // triggers a rebuild; SDK sheet is now on top
        }
        break;

      case 'process_result':
        // Terminal event — handle async but don't await here (void callback)
        _handleProcessResult(methodCall.arguments);
        break;
    }
  }

  Future<void> _handleProcessResult(dynamic arguments) async {
    Map<String, dynamic> args;
    try {
      args = jsonDecode(arguments as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final error   = args['error'] as bool? ?? false;
    final payload = args['payload'] as Map<String, dynamic>? ?? {};
    // Juspay v4 returns status in lowercase (e.g. "charged", "backpressed")
    final status  = (payload['status'] as String? ?? '').toLowerCase();

    if (!error && status == 'charged') {
      // Happy path — verify with backend before marking success
      if (!mounted) return;
      setState(() => _state = _PayState.verifying);
      await _verifyAndFinish();
      return;
    }

    // User dismissed the sheet without initiating a transaction
    if (status == 'backpressed') {
      if (mounted) setState(() => _state = _PayState.form);
      return;
    }

    // User initiated a txn then pressed back, or txn is pending
    if (status == 'user_aborted' ||
        status == 'pending_vbv' ||
        status == 'authorizing') {
      // Still need to verify — the txn may have completed server-side
      if (!mounted) return;
      setState(() => _state = _PayState.verifying);
      await _verifyAndFinish();
      return;
    }

    // Terminal failure statuses
    if (mounted) {
      setState(() {
        _state        = _PayState.failed;
        _errorMessage = 'Payment ${status.replaceAll('_', ' ')}. You may try again.';
      });
    }
  }

  Future<void> _verifyAndFinish() async {
    try {
      final verified      = await PaymentService.verifyOrder(_orderId!);
      final backendStatus = verified['status'] as String? ?? '';
      final paidAmount    = double.tryParse(
              verified['amount']?.toString() ?? '0') ?? 0;

      if (!mounted) return;

      if (backendStatus == 'CHARGED' &&
          (paidAmount - _orderTotal).abs() < 0.50) {
        // ✓ Confirmed + amount matches — fulfil the order
        context.read<CartProvider>().clearCart();
        _txnId = verified['txn_id'] as String?;
        setState(() => _state = _PayState.success);
      } else if (backendStatus == 'CHARGED') {
        // ⚠ Amount mismatch — possible under-payment fraud; do NOT fulfil
        setState(() {
          _state        = _PayState.error;
          _errorMessage = 'Payment amount mismatch detected.\n'
              'Contact support with Order ID: $_orderId';
        });
      } else {
        setState(() {
          _state        = _PayState.failed;
          _errorMessage = 'Payment status: $backendStatus.\nYou may try again or contact support.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      // Verification failed — do NOT mark success; surface error with order ID
      setState(() {
        _state        = _PayState.error;
        _errorMessage = 'Verification failed. If money was deducted, '
            'contact support with Order ID: $_orderId';
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return switch (_state) {
      _PayState.success => _buildSuccess(),
      _PayState.failed  => _buildFailed(),
      _PayState.error   => _buildError(),
      _                 => _buildFormWrapper(),
    };
  }

  Widget _buildFormWrapper() {
    return PopScope(
      // Prevent accidental back-navigation during payment processing
      canPop: _state == _PayState.form,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_state == _PayState.waiting && Platform.isAndroid && _processCalled) {
          // Delegate back press to the SDK — it manages its own back-stack
          final result = await _hyperSDK.onBackPress();
          if (result.toLowerCase() != 'true') {
            // SDK released the back press — return to form
            if (mounted) setState(() => _state = _PayState.form);
          }
        }
        // For creating/verifying states: silently block back press
      },
      child: Stack(
        children: [
          _buildForm(),
          if (_state != _PayState.form) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    final message = switch (_state) {
      _PayState.creating  => 'Preparing payment...',
      _PayState.waiting   => 'Opening payment sheet...',
      _PayState.verifying => 'Verifying payment...',
      _                   => 'Please wait...',
    };

    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFF1C1917),
                strokeWidth: 2.5,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF57534E)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    final cart     = context.watch<CartProvider>();
    final subtotal = cart.total;
    final shipping = subtotal >= 75 ? 0.0 : 9.99;
    final tax      = subtotal * 0.08;
    final total    = subtotal + shipping + tax;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Checkout',
          style: TextStyle(
              color: Color(0xFF1C1917),
              fontWeight: FontWeight.w700,
              fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1C1917)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Order summary ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    ...cart.items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: item.product.image,
                                  width: 52,
                                  height: 64,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.product.name,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1C1917)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${item.size} · ${item.color}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFFA8A29E)),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '₹${(item.product.price * item.quantity).toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1C1917)),
                              ),
                            ],
                          ),
                        )),
                    const Divider(color: Color(0xFFE7E5E4)),
                    _SummaryRow(
                        label: 'Subtotal',
                        value: '₹${subtotal.toStringAsFixed(0)}'),
                    _SummaryRow(
                      label: 'Shipping',
                      value: shipping == 0
                          ? 'Free'
                          : '₹${shipping.toStringAsFixed(2)}',
                      valueColor:
                          shipping == 0 ? const Color(0xFF059669) : null,
                    ),
                    _SummaryRow(
                        label: 'Tax (8%)',
                        value: '₹${tax.toStringAsFixed(2)}'),
                    const Divider(color: Color(0xFFE7E5E4)),
                    _SummaryRow(
                        label: 'Total',
                        value: '₹${total.toStringAsFixed(0)}',
                        bold: true),
                  ],
                ),
              ),

              // ── Contact ────────────────────────────────────────────────────
              const SizedBox(height: 28),
              const Text(
                'Contact',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1917)),
              ),
              const SizedBox(height: 12),
              _Field(
                hint: 'Email address',
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                onSaved: (v) => _email = v ?? '',
                validator: (v) =>
                    (v?.contains('@') ?? false) ? null : 'Enter a valid email',
              ),
              const SizedBox(height: 12),
              _Field(
                hint: 'Phone number',
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                onSaved: (v) => _phone = v ?? '',
                validator: (v) => (v?.length ?? 0) >= 10
                    ? null
                    : 'Enter a valid 10-digit phone number',
              ),

              // ── Shipping address ───────────────────────────────────────────
              const SizedBox(height: 28),
              const Text(
                'Shipping Address',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1917)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      hint: 'First name',
                      controller: _firstNameCtrl,
                      onSaved: (v) => _firstName = v ?? '',
                      validator: (v) =>
                          (v?.isNotEmpty ?? false) ? null : 'Required',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      hint: 'Last name',
                      controller: _lastNameCtrl,
                      validator: (v) =>
                          (v?.isNotEmpty ?? false) ? null : 'Required',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Field(
                hint: 'Address',
                controller: _addressCtrl,
                validator: (v) =>
                    (v?.isNotEmpty ?? false) ? null : 'Required',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      hint: 'City',
                      controller: _cityCtrl,
                      validator: (v) =>
                          (v?.isNotEmpty ?? false) ? null : 'Required',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _Field(hint: 'State', controller: _stateCtrl)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      hint: 'PIN code',
                      controller: _pinCtrl,
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          (v?.isNotEmpty ?? false) ? null : 'Required',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE7E5E4)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _country,
                          isExpanded: true,
                          style: const TextStyle(
                              fontSize: 14, color: Color(0xFF57534E)),
                          items: _countries
                              .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _country = v!),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // ── Pay button ─────────────────────────────────────────────────
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C1917),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Pay with Juspay  ·  ₹${total.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── Result screens ──────────────────────────────────────────────────────────

  Widget _buildSuccess() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                    color: Color(0xFFD1FAE5), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    size: 40, color: Color(0xFF059669)),
              ),
              const SizedBox(height: 24),
              const Text(
                'Payment Successful!',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1C1917)),
              ),
              const SizedBox(height: 8),
              Text('Thank you, $_firstName!',
                  style: const TextStyle(
                      fontSize: 16, color: Color(0xFF78716C))),
              const SizedBox(height: 8),
              Text(
                'Order ID: $_orderId'
                '${_txnId != null ? '\nTxn: $_txnId' : ''}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFFA8A29E), height: 1.6),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C1917),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Continue Shopping',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFailed() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                    color: Color(0xFFFEE2E2), shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded,
                    size: 40, color: Color(0xFFDC2626)),
              ),
              const SizedBox(height: 24),
              const Text(
                'Payment Failed',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1C1917)),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF78716C), height: 1.5),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => setState(() {
                    _state        = _PayState.form;
                    _errorMessage = null;
                    _processCalled = false;
                  }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C1917),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Try Again',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                    color: Color(0xFFFFF7ED), shape: BoxShape.circle),
                child: const Icon(Icons.warning_amber_rounded,
                    size: 40, color: Color(0xFFF97316)),
              ),
              const SizedBox(height: 24),
              const Text(
                'Something Went Wrong',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1C1917)),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF78716C), height: 1.5),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => setState(() {
                    _state        = _PayState.form;
                    _errorMessage = null;
                    _processCalled = false;
                  }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C1917),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Retry',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Form field ────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final String hint;
  final TextInputType? keyboardType;
  final void Function(String?)? onSaved;
  final FormFieldValidator<String>? validator;
  final TextEditingController? controller;

  const _Field({
    required this.hint,
    this.keyboardType,
    this.onSaved,
    this.validator,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      onSaved: onSaved,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(fontSize: 14, color: Color(0xFFA8A29E)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE7E5E4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE7E5E4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF78716C)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }
}

// ── Summary row ───────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: bold ? const Color(0xFF1C1917) : const Color(0xFF78716C),
              fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: valueColor ??
                  (bold ? const Color(0xFF1C1917) : const Color(0xFF78716C)),
              fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
