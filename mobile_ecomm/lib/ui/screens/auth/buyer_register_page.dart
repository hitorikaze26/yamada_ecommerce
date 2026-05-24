import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/routes/app_router.dart';
import '../../../data/models/address_model.dart';
import '../../../data/providers/auth_notifier.dart';
import '../../../data/services/auth_api.dart';
import '../../widgets/address_selector.dart';
import '../../widgets/file_uploader.dart';
import '../../widgets/hero_button.dart';

/// Buyer Registration Page
/// Two-step registration matching Next.js client
/// Step 1: Basic info, Step 2: Address & ID
class BuyerRegisterPage extends ConsumerStatefulWidget {
  const BuyerRegisterPage({super.key});

  @override
  ConsumerState<BuyerRegisterPage> createState() => _BuyerRegisterPageState();
}

class _BuyerRegisterPageState extends ConsumerState<BuyerRegisterPage> {
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();

  int _currentStep = 1;

  // Step 1 Controllers
  final _givenNameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _contactController = TextEditingController();
  bool _acceptTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Step 2 Data
  AddressData? _address;
  File? _validId;

  @override
  void dispose() {
    _givenNameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  String? _validateStep1() {
    if (_givenNameController.text.trim().isEmpty) {
      return 'Given name is required';
    }
    if (_surnameController.text.trim().isEmpty) {
      return 'Surname is required';
    }
    if (_emailController.text.trim().isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+').hasMatch(_emailController.text)) {
      return 'Invalid email format';
    }
    if (_passwordController.text.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      return 'Passwords do not match';
    }
    if (_contactController.text.trim().isEmpty) {
      return 'Contact number is required';
    }
    if (!_acceptTerms) {
      return 'You must accept the terms and conditions';
    }
    return null;
  }

  String? _validateStep2() {
    if (_address == null || !_address!.isComplete) {
      return 'Please select your address';
    }
    if (_validId == null) {
      return 'Please upload a valid ID';
    }
    return null;
  }

  Future<void> _handleStep1Submit() async {
    final error = _validateStep1();
    if (error != null) {
      AlertService.showSnackBar(
        context: context,
        message: error,
        variant: AlertVariant.error,
      );
      return;
    }

    setState(() => _currentStep = 2);
  }

  Future<void> _handleSubmit() async {
    final error = _validateStep2();
    if (error != null) {
      AlertService.showSnackBar(
        context: context,
        message: error,
        variant: AlertVariant.error,
      );
      return;
    }

    final success = await ref.read(authProvider.notifier).registerBuyer(
      givenName: _givenNameController.text.trim(),
      surname: _surnameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      contactNumber: _contactController.text.trim(),
      address: _address!,
      validId: _validId,
    );

    if (success && mounted) {
      // Show success alert matching Next.js client SweetAlert
      await AlertService.showSuccess(
        context: context,
        title: 'Registration Successful',
        message: 'Your account has been created. You can now log in.',
        confirmButtonText: 'Go to Login',
        onConfirm: () {
          // Navigate to login with pending approval flag
          context.go('${AppRouter.login}?role=buyer&registered=pending_approval');
        },
      );
    } else if (mounted) {
      final authError = ref.read(authProvider).error;
      if (authError != null) {
        AlertService.showSnackBar(
          context: context,
          message: authError,
          variant: AlertVariant.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authLoadingProvider);
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_currentStep > 1) {
            setState(() => _currentStep = 1);
          } else {
            context.pushReplacement(AppRouter.landing);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Join YAMADA'),
          centerTitle: true,
          leading: IconButton(
            onPressed: () {
              if (_currentStep > 1) {
                setState(() => _currentStep = 1);
              } else {
                context.pushReplacement(AppRouter.landing);
              }
            },
            icon: const Icon(Icons.arrow_back),
          ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step indicator
              _buildStepIndicator(),
              const SizedBox(height: 32),

              // Step title
              Text(
                _currentStep == 1 ? 'Create Account' : 'Complete Your Profile',
                style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _currentStep == 1
                    ? 'Enter your details to get started'
                    : 'Add your address and verification documents',
                style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),

              // Form content
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _currentStep == 1
                    ? _buildStep1Form()
                    : _buildStep2Form(),
              ),

              const SizedBox(height: 32),

              // Navigation buttons
              _buildNavigationButtons(isLoading),
            ],
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _buildStepCircle(1, _currentStep >= 1),
        Expanded(
          child: Container(
            height: 2,
            color: _currentStep >= 2 ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        _buildStepCircle(2, _currentStep >= 2),
      ],
    );
  }

  Widget _buildStepCircle(int step, bool isActive) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : Colors.grey.shade300,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: isActive && step < _currentStep
            ? const Icon(Icons.check, color: Colors.white)
            : Text(
                '$step',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildStep1Form() {
    return Form(
      key: _formKey1,
      child: Column(
        children: [
          // Given Name & Surname
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _givenNameController,
                  decoration: const InputDecoration(
                    labelText: 'Given Name',
                    hintText: 'Jane',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _surnameController,
                  decoration: const InputDecoration(
                    labelText: 'Surname',
                    hintText: 'Doe',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Email
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'you@example.com',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Password
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Create a strong password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Confirm Password
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              hintText: 'Confirm your password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Contact Number
          TextFormField(
            controller: _contactController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Contact Number',
              hintText: '+63 912 345 6789',
              prefixIcon: Icon(Icons.phone_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Terms Checkbox
          CheckboxListTile(
            value: _acceptTerms,
            onChanged: (value) => setState(() => _acceptTerms = value ?? false),
            title: Wrap(
              children: [
                const Text('I agree to the '),
                GestureDetector(
                  onTap: () {
                    // Navigate to terms
                  },
                  child: Text(
                    'Terms of Service',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const Text(' and '),
                GestureDetector(
                  onTap: () {
                    // Navigate to privacy
                  },
                  child: Text(
                    'Privacy Policy',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
    ).animate(effects: AppAnimations.fadeIn(delay: 0.1));
  }

  Widget _buildStep2Form() {
    return Form(
      key: _formKey2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Address Selector
          Text(
            'Shipping Address',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          AddressSelector(
            value: _address,
            onChange: (address) => setState(() => _address = address),
          ),
          const SizedBox(height: 24),

          // Valid ID Upload
          Text(
            'Valid ID',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Upload a clear photo of your government-issued ID for verification',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          FileUploader(
            label: 'Upload Valid ID',
            value: _validId,
            onUpload: (file) => setState(() => _validId = file),
          ),
        ],
      ),
    ).animate(effects: AppAnimations.fadeIn(delay: 0.1));
  }

  Widget _buildNavigationButtons(bool isLoading) {
    return Column(
      children: [
        if (_currentStep == 1)
          HeroButton(
            onPressed: isLoading ? null : _handleStep1Submit,
            text: 'Continue',
            icon: Icons.arrow_forward,
            isLoading: isLoading,
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isLoading ? null : () => setState(() => _currentStep = 1),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: HeroButton(
                  onPressed: isLoading ? null : _handleSubmit,
                  text: isLoading ? 'Creating...' : 'Create Account',
                ),
              ),
            ],
          ),
        const SizedBox(height: 24),

        // Login link
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Already have an account?'),
            TextButton(
              onPressed: () => context.go('${AppRouter.login}?role=buyer'),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ],
    );
  }
}
