import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/services/api_client.dart';
import '../../../data/models/address_model.dart';
import '../../../data/models/order_model.dart';
import '../../../data/providers/cart_notifier.dart';
import '../../../data/providers/auth_notifier.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/orders_api.dart';
import '../../../data/services/addresses_api.dart';
import '../../../data/services/auth_api.dart';
import '../../../data/services/coupons_api.dart';
import '../../../ui/widgets/address_selector.dart';
import '../../../ui/widgets/buyer_verification_banner.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contactController = TextEditingController();
  final _notesController = TextEditingController();
  String _paymentMethod = 'cod';
  int _currentStep = 0;
  bool _isLoading = false;
  bool _isLoadingAddresses = true;

  // Address state
  List<SavedAddress> _savedAddresses = [];
  SavedAddress? _selectedAddress;
  bool _showNewAddressForm = false;
  AddressData? _newAddressData;
  bool _saveAddressForNextTime = true;

  // Coupon state
  final _couponController = TextEditingController();
  String? _appliedCouponCode;
  double _couponDiscount = 0;
  bool _validatingCoupon = false;

  // New address form controllers
  final _newAddressLabelController = TextEditingController();
  final _streetController = TextEditingController();
  final _barangayController = TextEditingController();
  final _municipalityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _regionController = TextEditingController();
  final _postalCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    final notifier = ref.read(cartProvider.notifier);
    if (ref.read(cartProvider).isBuyNowCheckout) {
      notifier.clearBuyNowCheckout();
    }
    _contactController.dispose();
    _notesController.dispose();
    _newAddressLabelController.dispose();
    _streetController.dispose();
    _barangayController.dispose();
    _municipalityController.dispose();
    _provinceController.dispose();
    _regionController.dispose();
    _postalCodeController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadSavedAddresses(),
      _loadUserProfile(),
    ]);
  }

  Future<void> _loadSavedAddresses() async {
    setState(() => _isLoadingAddresses = true);
    try {
      developer.log('Fetching saved addresses...', name: 'CheckoutScreen');
      final addresses = await AddressesApi.loadAddresses();
      developer.log('Loaded ${addresses.length} addresses',
          name: 'CheckoutScreen');

      if (addresses.isNotEmpty) {
        setState(() {
          _savedAddresses = addresses;
          _selectedAddress = addresses.firstWhere(
            (a) => a.isDefault,
            orElse: () => addresses.first,
          );
          developer.log('Selected address: ${_selectedAddress?.label}',
              name: 'CheckoutScreen');
        });
        await _recalculateCheckoutShipping();
      } else {
        setState(() => _showNewAddressForm = true);
        developer.log('No addresses available, showing new address form',
            name: 'CheckoutScreen');
      }
    } catch (e, stackTrace) {
      developer.log('Error loading addresses: $e',
          name: 'CheckoutScreen', error: e, stackTrace: stackTrace);
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: 'Failed to load addresses: $e',
          variant: AlertVariant.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingAddresses = false);
      }
    }
  }

  Future<void> _loadUserProfile() async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user != null &&
        user.contactNumber != null &&
        user.contactNumber!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _contactController.text = user.contactNumber!;
        });
      }
    }
  }

  Future<void> _selectAddress(SavedAddress address) async {
    setState(() => _selectedAddress = address);
    await _recalculateCheckoutShipping();
  }

  Future<void> _recalculateCheckoutShipping() async {
    final cart = ref.read(cartProvider);
    if (cart.checkoutItems.isEmpty) return;

    final addr = _getSelectedAddressData();
    if (addr.regionName.isEmpty && addr.regionCode.isEmpty) return;

    await ref.read(cartProvider.notifier).calculateCheckoutShipping(
          buyerRegion: addr.regionName,
          buyerProvince: addr.provinceName,
          buyerMunicipality: addr.municipalityName,
          buyerRegionCode: addr.regionCode,
          buyerProvinceCode: addr.provinceCode,
          buyerMunicipalityCode: addr.municipalityCode,
        );
  }

  AddressData _getSelectedAddressData() {
    if (_selectedAddress != null && !_showNewAddressForm) {
      return _selectedAddress!.addressData;
    }
    if (_newAddressData != null) {
      return _newAddressData!;
    }
    return AddressData(
      streetAddress: _streetController.text,
      barangayName: _barangayController.text,
      municipalityName: _municipalityController.text,
      provinceName: _provinceController.text,
      regionName: _regionController.text,
      postalCode: _postalCodeController.text,
      regionCode: '',
      provinceCode: '',
      municipalityCode: '',
      barangayCode: '',
    );
  }

  Future<bool> _persistNewAddressIfNeeded() async {
    if (!_showNewAddressForm && _selectedAddress != null) return true;
    final data = _getSelectedAddressData();
    if (data.regionName.isEmpty || data.municipalityName.isEmpty) {
      AlertService.showSnackBar(
        context: context,
        message: 'Please complete your delivery address',
        variant: AlertVariant.warning,
      );
      return false;
    }
    if (!_saveAddressForNextTime) return true;
    final label = _newAddressLabelController.text.trim().isNotEmpty
        ? _newAddressLabelController.text.trim()
        : 'Home';
    final saved = await AddressesApi.addAddress(
      label: label,
      addressData: data,
      isDefault: _savedAddresses.isEmpty,
    );
    if (saved != null) {
      await _loadSavedAddresses();
      setState(() {
        _selectedAddress = saved;
        _showNewAddressForm = false;
      });
    }
    return true;
  }

  Future<void> _applyCoupon(double subtotal) async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;
    final cart = ref.read(cartProvider);
    final storeId = cart.checkoutItems.isNotEmpty
        ? int.tryParse(cart.checkoutItems.first.sellerId)
        : null;
    setState(() => _validatingCoupon = true);
    try {
      final result = await CouponsApi.validateCoupon(
        code: code,
        subtotal: subtotal,
        storeId: storeId,
      );
      if (!mounted) return;
      if (result.valid) {
        setState(() {
          _appliedCouponCode = code.toUpperCase();
          _couponDiscount = result.discount;
        });
        AlertService.showSnackBar(
          context: context,
          message: result.message,
          variant: AlertVariant.success,
        );
      } else {
        setState(() {
          _appliedCouponCode = null;
          _couponDiscount = 0;
        });
        AlertService.showSnackBar(
          context: context,
          message: result.message,
          variant: AlertVariant.error,
        );
      }
    } catch (e) {
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: e.toString().replaceFirst('Exception: ', ''),
          variant: AlertVariant.error,
        );
      }
    } finally {
      if (mounted) setState(() => _validatingCoupon = false);
    }
  }

  Future<void> _goToNextStep() async {
    if (_currentStep == 0) {
      final ok = await _persistNewAddressIfNeeded();
      if (!ok) return;
      await _recalculateCheckoutShipping();
    }
    setState(() => _currentStep++);
  }

  Future<void> _placeOrder() async {
    final authBefore = ref.read(authProvider);
    if (authBefore.user?.role == UserRole.buyer) {
      await ref.read(authProvider.notifier).refreshBuyerProfile();
    }
    final auth = ref.read(authProvider);
    final isVerified = auth.isVerified;
    final role = auth.user?.role;
    if (!isVerified &&
        role != UserRole.seller &&
        role != UserRole.rider &&
        role != UserRole.admin) {
      await AlertService.showInfo(
        context: context,
        title: 'Account pending verification',
        message: BuyerVerificationBanner.message,
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final cart = ref.read(cartProvider);
      final cartNotifier = ref.read(cartProvider.notifier);
      final shippingAddress = _getSelectedAddressData();
      final notes =
          _notesController.text.isNotEmpty ? _notesController.text : null;

      final itemsBySeller = <String, List<Map<String, dynamic>>>{};
      for (final item in cart.checkoutItems) {
        final map = <String, dynamic>{
          'productId': item.productId,
          'quantity': item.quantity,
          'price': item.price,
          '_cartItemId': item.id,
        };
        if (item.size != null || item.color != null) {
          map['variant'] = {
            if (item.size != null) 'size': item.size,
            if (item.color != null) 'color': item.color,
          };
        }
        itemsBySeller.putIfAbsent(item.sellerId, () => []).add(map);
      }

      final placedOrders = <Order>[];
      final failedStores = <String>[];
      final succeededItemIds = <String>[];

      for (final entry in itemsBySeller.entries) {
        final sellerId = entry.key;
        final sellerItems = entry.value;
        final apiItems = sellerItems.map((m) {
          final copy = Map<String, dynamic>.from(m);
          copy.remove('_cartItemId');
          return copy;
        }).toList();

        final shippingFee = cart.shippingFeeBySeller[sellerId] ?? 0.0;

        try {
          final order = await OrdersApi.createOrder(
            items: apiItems,
            shippingAddress: shippingAddress,
            paymentMethod: _paymentMethod,
            notes: notes,
            couponCode: _appliedCouponCode,
            shippingFee: shippingFee,
          );
          placedOrders.add(order);
          for (final m in sellerItems) {
            final id = m['_cartItemId']?.toString();
            if (id != null && id.isNotEmpty) succeededItemIds.add(id);
          }
        } catch (e) {
          developer.log(
            'Checkout failed for seller $sellerId: $e',
            name: 'CheckoutScreen',
          );
          final name = cart.checkoutItems
              .firstWhere((i) => i.sellerId == sellerId)
              .sellerName;
          failedStores.add(name);
        }
      }

      if (placedOrders.isEmpty) {
        throw Exception(
          failedStores.isEmpty
              ? 'No orders were placed'
              : 'Could not place orders for: ${failedStores.join(', ')}',
        );
      }

      if (cart.isBuyNowCheckout) {
        cartNotifier.clearBuyNowCheckout();
      } else if (succeededItemIds.isNotEmpty) {
        await cartNotifier.removeItemsWithIds(succeededItemIds);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        final orderLines =
            placedOrders.map((o) => 'Order #${o.orderNumber}').join('\n');
        var body =
            '$orderLines\n\nTrack your orders under My Orders. You will get in-app updates.';
        if (failedStores.isNotEmpty) {
          body +=
              '\n\nSome stores could not be checked out: ${failedStores.join(', ')}. '
              'Those items remain in your cart.';
        }
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(
              placedOrders.length > 1 ? 'Orders placed!' : 'Order placed!',
            ),
            content: Text(body),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('${AppRouter.buyerDashboard}?tab=orders');
                },
                child: const Text('View Orders'),
              ),
            ],
          ),
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        'Order placement failed',
        name: 'CheckoutScreen',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        setState(() => _isLoading = false);
        final msg = e.toString().replaceFirst('Exception: ', '');
        AlertService.showSnackBar(
          context: context,
          message: msg.contains('not yet verified')
              ? msg
              : 'Failed to place order: $msg',
          variant: AlertVariant.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cart = ref.watch(cartProvider);
    final subtotal = cart.checkoutSubtotal;
    final shipping = cart.checkoutShipping;
    final discountedSubtotal =
        (subtotal - _couponDiscount).clamp(0.0, double.infinity);
    final total = discountedSubtotal + shipping;

    if (cart.checkoutItems.isEmpty) {
      return Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.background,
        appBar: AppBar(
          title: const Text('Checkout'),
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                size: 64,
                color: isDark
                    ? AppColors.darkMutedForeground
                    : AppColors.mutedForeground,
              ),
              const SizedBox(height: 16),
              Text(
                'No items selected',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: isDark ? Colors.white : AppColors.foreground,
                    ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  final fromSellerBrowse =
                      GoRouterState.of(context).uri.queryParameters['from'] ==
                          'seller-browse';
                  context.go(
                    fromSellerBrowse
                        ? AppRouter.sellerBrowseCart
                        : AppRouter.cart,
                  );
                },
                child: const Text('Go to Cart'),
              ),
            ],
          ),
        ),
      );
    }

    final fromSellerBrowse =
        GoRouterState.of(context).uri.queryParameters['from'] ==
            'seller-browse';
    final isSellerCheckout = fromSellerBrowse ||
        ref.watch(authProvider).user?.role == UserRole.seller;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Checkout'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (isSellerCheckout)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Material(
                  color: AppColors.rosewood.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 20, color: AppColors.rosewood),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Checking out as a customer — this order is separate from your seller dashboard.',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isDark ? Colors.white70 : AppColors.charcoal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Progress Indicator
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: List.generate(
                  2,
                  (index) => Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _currentStep >= index
                                ? AppColors.primary
                                : isDark
                                    ? AppColors.darkMuted
                                    : const Color(0xFFE5E7EB),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: _currentStep >= index
                                        ? Colors.white
                                        : isDark
                                            ? AppColors.darkMutedForeground
                                            : AppColors.mutedForeground,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ['Address', 'Review & Place'][index],
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.foreground,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 600.ms)
                .slideY(begin: 0.2, duration: 600.ms),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Products Preview Section (visible on all steps)
                    _buildProductsPreview(cart.checkoutItems, isDark),
                    const SizedBox(height: 24),

                    if (_currentStep == 0) _buildAddressStep(isDark),
                    if (_currentStep == 1)
                      _buildConfirmStep(total, subtotal, isDark),
                    const SizedBox(height: 24),
                    // Order Summary
                    Text(
                      'Order Summary',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.foreground,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        border: Border.all(
                          color:
                              isDark ? AppColors.darkBorder : AppColors.border,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Subtotal',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.foreground,
                                    ),
                              ),
                              Text(
                                '${FormatUtils.peso(subtotal)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.foreground,
                                    ),
                              ),
                            ],
                          ),
                          if (_couponDiscount > 0) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Coupon discount',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppColors.delivered,
                                      ),
                                ),
                                Text(
                                  '-${FormatUtils.peso(_couponDiscount)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppColors.delivered,
                                      ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Shipping',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.foreground,
                                    ),
                              ),
                              Text(
                                '${FormatUtils.peso(shipping)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.foreground,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Divider(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.border),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.foreground,
                                    ),
                              ),
                              Text(
                                '${FormatUtils.peso(total)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Action Buttons
                    Row(
                      children: [
                        if (_currentStep > 0)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setState(() => _currentStep--),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.primary),
                                foregroundColor: AppColors.primary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Back'),
                            ),
                          ),
                        if (_currentStep > 0) const SizedBox(width: 12),
                        Expanded(
                          flex: _currentStep > 0 ? 1 : 2,
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    if (_currentStep < 1) {
                                      _goToNextStep();
                                    } else {
                                      _placeOrder();
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : Text(
                                    _currentStep == 1
                                        ? 'Place Order'
                                        : 'Continue',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Shipping Address',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.foreground,
                    ),
              ),
            ),
            TextButton(
              onPressed: () async {
                await context.push(AppRouter.addresses);
                await _loadSavedAddresses();
              },
              child: const Text('Manage addresses'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Loading indicator
        if (_isLoadingAddresses)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_savedAddresses.isNotEmpty && !_showNewAddressForm) ...[
          // Display selected address prominently
          if (_selectedAddress != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                border: Border.all(
                  color: AppColors.primary,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Change button - moved above, left-aligned
                  TextButton.icon(
                    onPressed: () => setState(() => _showNewAddressForm = true),
                    icon: const Icon(Icons.edit_location_alt, size: 18),
                    label: const Text('Change Address'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedAddress!.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (_selectedAddress!.isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Default',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(
                      color: isDark ? AppColors.darkBorder : AppColors.border),
                  const SizedBox(height: 8),
                  // Build address lines dynamically, only showing non-empty fields
                  ..._buildAddressLines(_selectedAddress!.addressData, isDark),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Other saved addresses list (compact)
          if (_savedAddresses.length > 1) ...[
            Text(
              'Other Addresses',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 8),
            ..._savedAddresses
                .where((a) => a.id != _selectedAddress?.id)
                .map((address) {
              return InkWell(
                onTap: () => _selectAddress(address),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark ? AppColors.darkMuted : AppColors.muted,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isDark ? AppColors.darkBackground : Colors.white,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: AppColors.mutedForeground,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              address.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${address.addressData.municipalityName}, ${address.addressData.provinceName}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.mutedForeground,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: TextButton(
                          onPressed: () => _selectAddress(address),
                          child: const Text('Select'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],

          // Add new address button
          TextButton.icon(
            onPressed: () => setState(() => _showNewAddressForm = true),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Add New Address'),
          ),
        ] else ...[
          // New address form with geolocation selector
          if (_savedAddresses.isEmpty) ...[
            // Empty state - no saved addresses
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_off_outlined,
                    color: AppColors.mutedForeground,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No saved addresses',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : AppColors.foreground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add your delivery address below',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else if (_showNewAddressForm && _savedAddresses.isNotEmpty)
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _showNewAddressForm = false),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Saved Addresses'),
                ),
              ],
            ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _newAddressLabelController,
            decoration: const InputDecoration(
              labelText: 'Address Label (e.g., Home, Office)',
              hintText: 'Home',
            ),
          ),
          const SizedBox(height: 16),
          // Geolocation Address Selector
          AddressSelector(
            onChange: (addressData) {
              setState(() {
                _newAddressData = addressData;
                _regionController.text = addressData.regionName;
                _provinceController.text = addressData.provinceName;
                _municipalityController.text = addressData.municipalityName;
                _barangayController.text = addressData.barangayName;
                _streetController.text = addressData.streetAddress ?? '';
                _postalCodeController.text = addressData.postalCode ?? '';
              });
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Save for next time'),
            value: _saveAddressForNextTime,
            onChanged: (v) => setState(() => _saveAddressForNextTime = v),
          ),
        ],
      ],
    )
        .animate()
        .fadeIn(duration: 600.ms, delay: 100.ms)
        .slideY(begin: 0.2, duration: 600.ms, delay: 100.ms);
  }

  Widget _buildPaymentStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Method',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.foreground,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Cash on Delivery only',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.mutedForeground,
              ),
        ),
        const SizedBox(height: 16),
        _buildPaymentOption(
          'cod',
          'Cash on Delivery',
          'Pay when you receive your order',
          Icons.money,
          isDark,
        ),
      ],
    )
        .animate()
        .fadeIn(duration: 600.ms, delay: 100.ms)
        .slideY(begin: 0.2, duration: 600.ms, delay: 100.ms);
  }

  Widget _buildPaymentOption(
    String value,
    String title,
    String subtitle,
    IconData icon,
    bool isDark,
  ) {
    final isSelected = _paymentMethod == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _paymentMethod = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : isDark
                    ? AppColors.darkBorder
                    : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.05)
              : isDark
                  ? AppColors.darkCard
                  : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : isDark
                          ? AppColors.darkBorder
                          : AppColors.border,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.foreground,
                        ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.darkMutedForeground
                              : AppColors.mutedForeground,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmStep(double total, double subtotal, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order Confirmation',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.foreground,
              ),
        ),
        const SizedBox(height: 16),

        // Shipping Address Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Shipping Address',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_selectedAddress != null && !_showNewAddressForm) ...[
                Text(
                  _selectedAddress!.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                // Build address lines dynamically, only showing non-empty fields
                ..._buildAddressLines(_selectedAddress!.addressData, isDark),
              ] else ...[
                // Build address from form controllers, only showing non-empty fields
                ..._buildAddressLinesFromControllers(
                  street: _streetController.text,
                  barangay: _barangayController.text,
                  municipality: _municipalityController.text,
                  province: _provinceController.text,
                  region: _regionController.text,
                  postalCode: _postalCodeController.text,
                  isDark: isDark,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Payment Method Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.payment_outlined,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Payment Method',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.money,
                    size: 18,
                    color: AppColors.mutedForeground,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Cash on Delivery',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : AppColors.foreground,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Pay when you receive your order',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Coupon code',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.foreground,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _couponController,
                decoration: const InputDecoration(
                  hintText: 'Enter code',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed:
                  _validatingCoupon ? null : () => _applyCoupon(subtotal),
              child: _validatingCoupon
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Apply'),
            ),
          ],
        ),
        if (_appliedCouponCode != null) ...[
          const SizedBox(height: 8),
          Text(
            'Applied: $_appliedCouponCode (-${FormatUtils.peso(_couponDiscount)})',
            style: const TextStyle(color: AppColors.delivered, fontSize: 13),
          ),
        ],
        const SizedBox(height: 24),

        // Ready to place order indicator
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.delivered.withValues(alpha: 0.1),
            border: Border.all(color: AppColors.delivered),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: AppColors.delivered,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready to place order',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.delivered,
                          ),
                    ),
                    Text(
                      'Total: ${FormatUtils.peso(total)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                isDark ? Colors.white70 : AppColors.foreground,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(duration: 600.ms, delay: 100.ms)
        .slideY(begin: 0.2, duration: 600.ms, delay: 100.ms);
  }

  Widget _buildProductsPreview(List<CartItem> items, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order Items (${items.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.foreground,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items
                .map((item) => _buildCompactOrderItem(item, isDark))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactOrderItem(CartItem item, bool isDark) {
    final imageUrl = ApiClient.resolveImageUrl(item.productImage);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl != null
                ? Image.network(
                    imageUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 50,
                      height: 50,
                      color: isDark ? AppColors.darkMuted : AppColors.muted,
                      child: const Icon(Icons.image_not_supported, size: 20),
                    ),
                  )
                : Container(
                    width: 50,
                    height: 50,
                    color: isDark ? AppColors.darkMuted : AppColors.muted,
                    child: const Icon(Icons.image_not_supported, size: 20),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Shop/Store Name
                Row(
                  children: [
                    Icon(
                      Icons.store_outlined,
                      size: 11,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.sellerName,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                // Product Name
                Text(
                  item.productName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : AppColors.foreground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Variants and Quantity
                Row(
                  children: [
                    if (item.size != null || item.color != null)
                      Text(
                        [
                          if (item.size != null) '${item.size}',
                          if (item.color != null) '${item.color}',
                        ].join(', '),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    const Spacer(),
                    Text(
                      'x${item.quantity}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${FormatUtils.peso(item.total)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build address lines dynamically, only showing non-empty fields
  List<Widget> _buildAddressLines(AddressData address, bool isDark) {
    final lines = <Widget>[];

    // Line 1: Street Address + Barangay (if available)
    final line1Parts = <String>[
      if (address.streetAddress?.isNotEmpty == true) address.streetAddress!,
      if (address.barangayName.isNotEmpty) address.barangayName,
    ];
    if (line1Parts.isNotEmpty) {
      lines.add(
        Text(
          line1Parts.join(', '),
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white : AppColors.foreground,
          ),
        ),
      );
    }

    // Line 2: Municipality + Province
    final line2Parts = <String>[
      if (address.municipalityName.isNotEmpty) address.municipalityName,
      if (address.provinceName.isNotEmpty) address.provinceName,
    ];
    if (line2Parts.isNotEmpty) {
      lines.add(
        const SizedBox(height: 4),
      );
      lines.add(
        Text(
          line2Parts.join(', '),
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.mutedForeground,
          ),
        ),
      );
    }

    // Line 3: Region + Postal Code (if available)
    final line3Parts = <String>[
      if (address.regionName.isNotEmpty) address.regionName,
      if (address.postalCode?.isNotEmpty == true) address.postalCode!,
    ];
    if (line3Parts.isNotEmpty) {
      lines.add(
        const SizedBox(height: 4),
      );
      lines.add(
        Text(
          line3Parts.join(', '),
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.mutedForeground,
          ),
        ),
      );
    }

    return lines;
  }

  /// Build address lines from form controllers, only showing non-empty fields
  List<Widget> _buildAddressLinesFromControllers({
    required String street,
    required String barangay,
    required String municipality,
    required String province,
    required String region,
    required String postalCode,
    required bool isDark,
  }) {
    final lines = <Widget>[];

    // Line 1: Street + Barangay
    final line1Parts = <String>[
      if (street.isNotEmpty) street,
      if (barangay.isNotEmpty) barangay,
    ];
    if (line1Parts.isNotEmpty) {
      lines.add(
        Text(
          line1Parts.join(', '),
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white70 : AppColors.foreground,
          ),
        ),
      );
    }

    // Line 2: Municipality + Province
    final line2Parts = <String>[
      if (municipality.isNotEmpty) municipality,
      if (province.isNotEmpty) province,
    ];
    if (line2Parts.isNotEmpty) {
      lines.add(
        Text(
          line2Parts.join(', '),
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.mutedForeground,
          ),
        ),
      );
    }

    // Line 3: Region + Postal Code
    final line3Parts = <String>[
      if (region.isNotEmpty) region,
      if (postalCode.isNotEmpty) postalCode,
    ];
    if (line3Parts.isNotEmpty) {
      lines.add(
        Text(
          line3Parts.join(', '),
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.mutedForeground,
          ),
        ),
      );
    }

    return lines;
  }
}
