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
import '../../widgets/address_selector.dart';
import '../../widgets/email_verification_widget.dart';
import '../../widgets/file_uploader.dart';
import '../../widgets/hero_button.dart';

/// Rider Registration Page
/// Multi-step registration for rider accounts
class RiderRegisterPage extends ConsumerStatefulWidget {
  const RiderRegisterPage({super.key});

  @override
  ConsumerState<RiderRegisterPage> createState() => _RiderRegisterPageState();
}

class _RiderRegisterPageState extends ConsumerState<RiderRegisterPage> {
  int _currentStep = 1;

  // Step 1: Personal Info
  final _givenNameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _contactController = TextEditingController();
  bool _acceptTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Step 2: Vehicle Info
  final _vehicleTypeController = TextEditingController();
  final _licenseNumberController = TextEditingController();

  // Step 3: Address & Documents
  AddressData? _address;
  File? _license;
  File? _orCr;

  // Post-registration: email verification
  String? _registeredEmail;
  bool _emailVerified = false;

  @override
  void dispose() {
    _givenNameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _contactController.dispose();
    _vehicleTypeController.dispose();
    _licenseNumberController.dispose();
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
    if (_vehicleTypeController.text.trim().isEmpty) {
      return 'Vehicle type is required';
    }
    if (_licenseNumberController.text.trim().isEmpty) {
      return 'License number is required';
    }
    return null;
  }

  String? _validateStep3() {
    if (_address == null || !_address!.isComplete) {
      return 'Please select your address';
    }
    if (_license == null) {
      return 'Please upload Driver\'s License';
    }
    if (_orCr == null) {
      return 'Please upload OR/CR';
    }
    return null;
  }

  void _nextStep() {
    String? error;
    switch (_currentStep) {
      case 1:
        error = _validateStep1();
        break;
      case 2:
        error = _validateStep2();
        break;
    }

    if (error != null) {
      AlertService.showSnackBar(
        context: context,
        message: error,
        variant: AlertVariant.error,
      );
      return;
    }

    if (_currentStep < 3) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _handleSubmit() async {
    final error = _validateStep3();
    if (error != null) {
      AlertService.showSnackBar(
        context: context,
        message: error,
        variant: AlertVariant.error,
      );
      return;
    }

    final success = await ref.read(authProvider.notifier).registerRider(
      givenName: _givenNameController.text.trim(),
      surname: _surnameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      contactNumber: _contactController.text.trim(),
      vehicleType: _vehicleTypeController.text.trim(),
      licenseNumber: _licenseNumberController.text.trim(),
      address: _address!,
      license: _license,
      orCr: _orCr,
    );

    if (success && mounted) {
      setState(() {
        _registeredEmail = _emailController.text.trim();
      });
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

  void _handleEmailVerified() {
    setState(() => _emailVerified = true);
    AlertService.showSnackBar(
      context: context,
      message: 'Email verified successfully!',
      variant: AlertVariant.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authLoadingProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Apply as Rider'),
        centerTitle: true,
        leading: _registeredEmail != null
            ? null
            : IconButton(
                onPressed: _currentStep > 1 ? _prevStep : () => context.pushReplacement(AppRouter.landing),
                icon: const Icon(Icons.arrow_back),
              ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _registeredEmail != null
              ? _buildVerificationSection(theme)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStepIndicator(),
                    const SizedBox(height: 32),
                    Text(
                      _getStepTitle(),
                      style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getStepDescription(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _buildCurrentStep(),
                    ),
                    const SizedBox(height: 32),
                    _buildNavigationButtons(isLoading),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildVerificationSection(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.email_outlined, color: AppColors.primary, size: 32),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Verify Your Email',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Check your email for the verification code to activate your rider account',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        EmailVerificationWidget(
          email: _registeredEmail!,
          onVerified: _handleEmailVerified,
        ),
        if (_emailVerified) ...[
          const SizedBox(height: 24),
          HeroButton(
            onPressed: () {
              context.go('${AppRouter.login}?role=rider');
            },
            text: 'Go to Login',
          ),
        ],
      ],
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 1:
        return 'Personal Information';
      case 2:
        return 'Vehicle Details';
      case 3:
        return 'Address & Documents';
      default:
        return '';
    }
  }

  String _getStepDescription() {
    switch (_currentStep) {
      case 1:
        return 'Enter your personal details';
      case 2:
        return 'Tell us about your vehicle';
      case 3:
        return 'Add your address and required documents';
      default:
        return '';
    }
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 1:
        return _buildStep1Form();
      case 2:
        return _buildStep2Form();
      case 3:
        return _buildStep3Form();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _buildStepCircle(1, _currentStep >= 1),
        Expanded(child: _buildStepLine(_currentStep >= 2)),
        _buildStepCircle(2, _currentStep >= 2),
        Expanded(child: _buildStepLine(_currentStep >= 3)),
        _buildStepCircle(3, _currentStep >= 3),
      ],
    );
  }

  Widget _buildStepCircle(int step, bool isActive) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : Colors.grey.shade300,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: isActive && step < _currentStep
            ? const Icon(Icons.check, color: Colors.white, size: 20)
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

  Widget _buildStepLine(bool isActive) {
    return Container(
      height: 2,
      color: isActive ? AppColors.primary : Colors.grey.shade300,
    );
  }

  Widget _buildStep1Form() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _givenNameController,
                decoration: const InputDecoration(
                  labelText: 'Given Name',
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
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
            ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
            ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _contactController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Contact Number',
            prefixIcon: Icon(Icons.phone_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          value: _acceptTerms,
          onChanged: (value) => setState(() => _acceptTerms = value ?? false),
          title: const Text('I agree to the Terms of Service and Privacy Policy'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    ).animate(effects: AppAnimations.fadeIn(delay: 0.1));
  }

  Widget _buildStep2Form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _vehicleTypeController,
          decoration: const InputDecoration(
            labelText: 'Vehicle Type',
            hintText: 'e.g., Motorcycle, Car, Van',
            prefixIcon: Icon(Icons.two_wheeler),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _licenseNumberController,
          decoration: const InputDecoration(
            labelText: 'License Number',
            hintText: 'Your driver\'s license number',
            prefixIcon: Icon(Icons.badge_outlined),
            border: OutlineInputBorder(),
          ),
        ),
      ],
    ).animate(effects: AppAnimations.fadeIn(delay: 0.1));
  }

  Widget _buildStep3Form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Address',
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
        Text(
          'Required Documents',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        _buildDocumentUploader('Driver\'s License', _license, (f) => setState(() => _license = f)),
        const SizedBox(height: 12),
        _buildDocumentUploader('OR/CR (Official Receipt/Certificate of Registration)', _orCr, (f) => setState(() => _orCr = f)),
      ],
    ).animate(effects: AppAnimations.fadeIn(delay: 0.1));
  }

  Widget _buildDocumentUploader(String label, File? file, ValueChanged<File?> onUpload) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        FileUploader(
          label: 'Upload $label',
          value: file,
          onUpload: onUpload,
        ),
      ],
    );
  }

  Widget _buildNavigationButtons(bool isLoading) {
    return Column(
      children: [
        if (_currentStep == 1)
          HeroButton(
            onPressed: isLoading ? null : _nextStep,
            text: 'Continue',
            icon: Icons.arrow_forward,
            isLoading: isLoading,
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isLoading ? null : _prevStep,
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
                  onPressed: isLoading
                      ? null
                      : _currentStep == 3
                          ? _handleSubmit
                          : _nextStep,
                  text: _currentStep == 3
                      ? (isLoading ? 'Submitting...' : 'Submit Application')
                      : 'Continue',
                  icon: _currentStep == 3 ? null : Icons.arrow_forward,
                  isLoading: isLoading,
                  isSecondary: true,
                ),
              ),
            ],
          ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Already have an account?'),
            TextButton(
              onPressed: () => context.go('${AppRouter.login}?role=rider'),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ],
    );
  }
}
