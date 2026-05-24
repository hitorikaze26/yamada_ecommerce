import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/category_model.dart';
import '../../../data/providers/seller_products_notifier.dart';
import '../../../data/services/auth_api.dart';

List<Map<String, String>> get _allCategories => Category.categories
    .map((c) => {'id': c.id, 'name': c.name})
    .toList();

const _clothingSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];

const _variationColors = [
  'Black','White','Off White','Cream','Beige','Nude','Taupe','Brown','Camel','Tan',
  'Light Gray','Gray','Charcoal','Silver','Gold','Rose Gold','Blush Pink','Baby Pink',
  'Dusty Pink','Mauve','Rose','Hot Pink','Red','Maroon','Wine','Burgundy','Coral',
  'Peach','Orange','Rust','Yellow','Mustard','Olive','Army Green','Sage Green',
  'Mint Green','Forest Green','Emerald Green','Teal','Turquoise','Blue','Baby Blue',
  'Sky Blue','Royal Blue','Navy Blue','Lavender','Lilac','Violet','Purple','Plum',
  'Multicolor','Floral Print','Animal Print','Other',
];

// ── Variation model ───────────────────────────────────────────────────────────

/// One size row within a color group
class _SizeRow {
  final String id;
  String size;
  int stock;
  String sku;

  _SizeRow({
    required this.id,
    required this.size,
    required this.stock,
    required this.sku,
  });
}

/// One color group — holds a color + list of size rows
class _ColorGroup {
  final String id;
  String color;
  String customColor;
  final List<_SizeRow> rows;

  _ColorGroup({
    required this.id,
    required this.color,
    required this.customColor,
    List<_SizeRow>? rows,
  }) : rows = rows ??
            [
              _SizeRow(
                id: '${DateTime.now().millisecondsSinceEpoch}_0',
                size: _clothingSizes[2],
                stock: 0,
                sku: '',
              )
            ];

  /// Flatten into the payload format the backend expects
  List<Map<String, dynamic>> toPayload() => rows
      .map((r) => {
            'size': r.size,
            'colors': [
              color == 'Other' && customColor.isNotEmpty ? customColor : color
            ],
            'stock': r.stock,
            'sku': r.sku,
          })
      .toList();
}

// ── Video preview widget ──────────────────────────────────────────────────────

class _VideoPreviewCard extends StatefulWidget {
  final File file;
  final VoidCallback onRemove;

  const _VideoPreviewCard({required this.file, required this.onRemove});

  @override
  State<_VideoPreviewCard> createState() => _VideoPreviewCardState();
}

class _VideoPreviewCardState extends State<_VideoPreviewCard> {
  late VideoPlayerController _ctrl;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _initialized
              ? AspectRatio(
                  aspectRatio: _ctrl.value.aspectRatio,
                  child: VideoPlayer(_ctrl),
                )
              : Container(
                  height: 160,
                  color: Colors.black,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
        ),
        // Play/pause toggle
        if (_initialized)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() {
                _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play();
              }),
              child: Container(
                color: Colors.transparent,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _ctrl.value.isPlaying ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow,
                          color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),
            ),
          ),
        // Remove button
        Positioned(
          top: 6,
          right: 6,
          child: GestureDetector(
            onTap: widget.onRemove,
            child: Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle),
              child:
                  const Icon(Icons.close, size: 15, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Main page ─────────────────────────────────────────────────────────────────

class SellerAddProductPage extends ConsumerStatefulWidget {
  const SellerAddProductPage({super.key});

  @override
  ConsumerState<SellerAddProductPage> createState() =>
      _SellerAddProductPageState();
}

class _SellerAddProductPageState
    extends ConsumerState<SellerAddProductPage> {
  int _step = 1;
  bool _isSubmitting = false;
  String? _submitError;

  // Allowed category IDs fetched from seller profile
  List<String>? _allowedCategories;
  bool _loadingCategories = true;
  int? _storeId;
  bool _checkingStore = true;

  // ── Step 1 ────────────────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  String _category = '';
  String _subcategory = '';

  // ── Step 2 ────────────────────────────────────────────────────────────────
  final List<File> _imageFiles = [];
  final List<File> _videoFiles = [];
  final _materialCtrl = TextEditingController();
  final _careCtrl = TextEditingController();

  // ── Step 3 ────────────────────────────────────────────────────────────────
  final _priceCtrl = TextEditingController();
  final _salePriceCtrl = TextEditingController();
  final _costPriceCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _lowStockCtrl = TextEditingController();
  String _condition = 'new';
  bool _termsAgreed = false;
  final List<_ColorGroup> _colorGroups = [];

  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initStore();
    _fetchAllowedCategories();
  }

  Future<void> _initStore() async {
    try {
      final profile = await AuthApi.getSellerProfile();
      final id = (profile['storeId'] as num?)?.toInt();
      if (mounted) {
        setState(() {
          _storeId = id;
          _checkingStore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checkingStore = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _descCtrl.dispose();
    _tagsCtrl.dispose();
    _materialCtrl.dispose();
    _careCtrl.dispose();
    _priceCtrl.dispose();
    _salePriceCtrl.dispose();
    _costPriceCtrl.dispose();
    _weightCtrl.dispose();
    _lowStockCtrl.dispose();
    super.dispose();
  }

  // ── Fetch allowed categories from seller profile ──────────────────────────

  Future<void> _fetchAllowedCategories() async {
    try {
      final profile = await AuthApi.getSellerProfile();
      // profile.categories is a List<dynamic> of category IDs
      final raw = profile['categories'];
      if (raw is List && raw.isNotEmpty) {
        setState(() {
          _allowedCategories =
              raw.map((e) => e.toString()).toList();
          _loadingCategories = false;
        });
      } else {
        setState(() {
          _allowedCategories = null; // show all
          _loadingCategories = false;
        });
      }
    } catch (_) {
      setState(() {
        _allowedCategories = null;
        _loadingCategories = false;
      });
    }
  }

  List<Map<String, String>> get _visibleCategories {
    if (_allowedCategories == null || _allowedCategories!.isEmpty) {
      return List<Map<String, String>>.from(_allCategories);
    }
    return _allCategories
        .where((c) => _allowedCategories!.contains(c['id']))
        .toList()
        .cast<Map<String, String>>();
  }

  // ── Validation ────────────────────────────────────────────────────────────

  String? _validateStep1() {
    if (_nameCtrl.text.trim().isEmpty) return 'Product name is required.';
    if (_brandCtrl.text.trim().isEmpty) return 'Brand is required.';
    if (_descCtrl.text.trim().isEmpty) return 'Description is required.';
    if (_category.isEmpty) return 'Please select a category.';
    return null;
  }

  String? _validateStep3() {
    final price = double.tryParse(_priceCtrl.text.trim());
    if (price == null || price <= 0) return 'Enter a valid price.';
    if (!_termsAgreed) return 'Please agree to the terms before submitting.';
    return null;
  }

  // ── Image / video pickers ─────────────────────────────────────────────────

  Future<void> _pickImages() async {
    if (_imageFiles.length >= 6) return;
    final remaining = 6 - _imageFiles.length;
    final picked = await _imagePicker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    setState(() {
      for (final xf in picked.take(remaining)) {
        _imageFiles.add(File(xf.path));
      }
    });
  }

  void _removeImage(int index) =>
      setState(() => _imageFiles.removeAt(index));

  Future<void> _pickVideo() async {
    final picked = await _imagePicker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 3),
    );
    if (picked == null) return;
    setState(() => _videoFiles.add(File(picked.path)));
  }

  void _removeVideo(int index) =>
      setState(() => _videoFiles.removeAt(index));

  // ── Variation helpers ─────────────────────────────────────────────────────

  void _addColorGroup() {
    setState(() {
      _colorGroups.add(_ColorGroup(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        color: '',
        customColor: '',
      ));
    });
  }

  void _removeColorGroup(String id) =>
      setState(() => _colorGroups.removeWhere((g) => g.id == id));

  void _addSizeRow(String groupId) {
    setState(() {
      final group = _colorGroups.firstWhere((g) => g.id == groupId);
      group.rows.add(_SizeRow(
        id: '${DateTime.now().millisecondsSinceEpoch}_${group.rows.length}',
        size: _clothingSizes[2],
        stock: 0,
        sku: '',
      ));
    });
  }

  void _removeSizeRow(String groupId, String rowId) {
    setState(() {
      final group = _colorGroups.firstWhere((g) => g.id == groupId);
      if (group.rows.length > 1) {
        group.rows.removeWhere((r) => r.id == rowId);
      }
    });
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final err = _validateStep3();
    if (err != null) {
      setState(() => _submitError = err);
      return;
    }
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    final price = double.parse(_priceCtrl.text.trim());
    final salePrice = double.tryParse(_salePriceCtrl.text.trim());
    final costPrice = double.tryParse(_costPriceCtrl.text.trim());
    final weightKg = double.tryParse(_weightCtrl.text.trim());

    final success =
        await ref.read(sellerProductsProvider.notifier).createProduct(
              name: _nameCtrl.text.trim(),
              brand: _brandCtrl.text.trim(),
              description: _descCtrl.text.trim(),
              category: _category,
              subcategory:
                  _subcategory.isNotEmpty ? _subcategory : null,
              price: price,
              salePrice: salePrice,
              costPrice: costPrice,
              condition: _condition,
              weightKg: weightKg,
              material: _materialCtrl.text.trim().isNotEmpty
                  ? _materialCtrl.text.trim()
                  : null,
              careInstructions: _careCtrl.text.trim().isNotEmpty
                  ? _careCtrl.text.trim()
                  : null,
              tags: _tagsCtrl.text.trim().isNotEmpty
                  ? _tagsCtrl.text.trim()
                  : null,
              lowStockThreshold: _lowStockCtrl.text.trim().isNotEmpty
                  ? _lowStockCtrl.text.trim()
                  : null,
              variations: _colorGroups
                  .expand((g) => g.toPayload())
                  .toList(),
              imageFiles: _imageFiles,
              videoFiles: _videoFiles,
            );

    setState(() => _isSubmitting = false);
    if (!mounted) return;

    if (success) {
      AlertService.showSnackBar(
        context: context,
        message: 'Product added successfully!',
        variant: AlertVariant.success,
      );
      Navigator.of(context).pop();
    } else {
      setState(() => _submitError =
          ref.read(sellerProductsProvider).error ??
              'Failed to create product.');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    if (_checkingStore) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add Product')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_storeId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add Product')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.store_outlined,
                    size: 56, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text(
                  'Store pending approval',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'You can add products after your store is approved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.mutedForeground),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      appBar: _buildAppBar(isDark),
      body: Column(
        children: [
          _buildStepIndicator(isDark),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _step == 1
                    ? _buildStep1(isDark, cardColor, borderColor)
                    : _step == 2
                        ? _buildStep2(isDark, cardColor, borderColor)
                        : _buildStep3(isDark, cardColor, borderColor),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(isDark),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new,
            size: 20,
            color: isDark ? Colors.white : AppColors.charcoal),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add New Product',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.charcoal,
            ),
          ),
          Text(
            'Step $_step of 3',
            style: const TextStyle(
                fontSize: 12, color: AppColors.mutedForeground),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(bool isDark) {
    const labels = ['Basic Info', 'Images & Details', 'Pricing'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border(
          bottom: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
      ),
      child: Row(
        children: List.generate(labels.length * 2 - 1, (i) {
          // Even indices = step circles, odd indices = connectors
          if (i.isOdd) {
            final stepNum = (i ~/ 2) + 1; // connector after stepNum
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 20),
                color: _step > stepNum
                    ? const Color(0xFF10B981)
                    : (isDark ? AppColors.darkBorder : AppColors.border),
              ),
            );
          }
          final idx = i ~/ 2;
          final num = idx + 1;
          final isActive = _step == num;
          final isDone = _step > num;
          return GestureDetector(
            onTap: () {
              if (num < _step) setState(() => _step = num);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? const Color(0xFF10B981)
                        : isActive
                            ? AppColors.rosewood
                            : (isDark ? AppColors.darkBorder : AppColors.border),
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : Text('$num',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isActive || isDone
                                  ? Colors.white
                                  : AppColors.mutedForeground,
                            )),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  labels[idx],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive
                        ? AppColors.rosewood
                        : AppColors.mutedForeground,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── Step 1: Basic Info ────────────────────────────────────────────────────

  Widget _buildStep1(bool isDark, Color cardColor, Color borderColor) {
    final subs = Category.subcategoriesById[_category] ?? [];
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionCard(
          isDark: isDark, cardColor: cardColor, borderColor: borderColor,
          title: 'Basic Information', icon: Icons.info_outline,
          children: [
            _fieldLabel('Product Name *'),
            _textField(controller: _nameCtrl, hint: 'e.g., Floral Maxi Dress', isDark: isDark, maxLines: 2),
            const SizedBox(height: 14),
            _fieldLabel('Brand *'),
            _textField(controller: _brandCtrl, hint: 'e.g., Yamada Studio', isDark: isDark),
            const SizedBox(height: 14),
            _fieldLabel('Description *'),
            _textField(controller: _descCtrl, hint: 'Describe your product in detail...', isDark: isDark, maxLines: 5),
            const SizedBox(height: 14),
            _fieldLabel('Tags (comma separated)'),
            _textField(controller: _tagsCtrl, hint: 'e.g., summer, casual, floral', isDark: isDark),
          ],
        ),
        const SizedBox(height: 14),
        _sectionCard(
          isDark: isDark, cardColor: cardColor, borderColor: borderColor,
          title: 'Category', icon: Icons.category_outlined,
          children: [
            if (_loadingCategories)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              _fieldLabel('Category *'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _visibleCategories.map((cat) {
                  final isSelected = _category == cat['id'];
                  return GestureDetector(
                    onTap: () => setState(() {
                      _category = cat['id']!;
                      _subcategory = '';
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.rosewood
                            : (isDark ? AppColors.darkBackground : AppColors.warmBeige),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.rosewood : borderColor,
                        ),
                      ),
                      child: Text(
                        cat['name']!,
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.mutedForeground,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (subs.isNotEmpty) ...[
                const SizedBox(height: 14),
                _fieldLabel('Subcategory'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: subs.map((sub) {
                    final isSelected = _subcategory == sub;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _subcategory = isSelected ? '' : sub;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.rosewood.withOpacity(0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppColors.rosewood : borderColor,
                          ),
                        ),
                        child: Text(
                          sub,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? AppColors.rosewood : AppColors.mutedForeground,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ],
        ),
      ],
    );
  }

  // ── Step 2: Images, Video & Details ──────────────────────────────────────

  Widget _buildStep2(bool isDark, Color cardColor, Color borderColor) {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Images ──────────────────────────────────────────────────────
        _sectionCard(
          isDark: isDark, cardColor: cardColor, borderColor: borderColor,
          title: 'Product Images', icon: Icons.photo_library_outlined,
          subtitle: 'Upload up to 6 images. First image is the cover.',
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, crossAxisSpacing: 10,
                mainAxisSpacing: 10, childAspectRatio: 1,
              ),
              itemCount: _imageFiles.length < 6
                  ? _imageFiles.length + 1
                  : _imageFiles.length,
              itemBuilder: (context, index) {
                if (index == _imageFiles.length && _imageFiles.length < 6) {
                  return GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBackground : AppColors.warmBeige,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 28, color: AppColors.mutedForeground),
                          const SizedBox(height: 4),
                          Text(
                            _imageFiles.isEmpty ? 'Add Photo' : 'Add More',
                            style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_imageFiles[index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity),
                    ),
                    if (index == 0)
                      Positioned(
                        bottom: 6, left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.rosewood,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Cover',
                              style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    Positioned(
                      top: 4, right: 4,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          width: 22, height: 22,
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Video (optional) ─────────────────────────────────────────────
        _sectionCard(
          isDark: isDark, cardColor: cardColor, borderColor: borderColor,
          title: 'Product Video', icon: Icons.videocam_outlined,
          subtitle: 'Optional — add a short video to showcase your product.',
          children: [
            GestureDetector(
              onTap: _pickVideo,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBackground : AppColors.warmBeige,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: borderColor,
                    style: BorderStyle.solid,
                  ),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.upload_file_outlined,
                        size: 28, color: AppColors.mutedForeground),
                    SizedBox(height: 6),
                    Text('Upload Video',
                        style: TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
                    SizedBox(height: 2),
                    Text('MP4, MOV — max 3 min',
                        style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
                  ],
                ),
              ),
            ),
            if (_videoFiles.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...List.generate(_videoFiles.length, (i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _VideoPreviewCard(
                  file: _videoFiles[i],
                  onRemove: () => _removeVideo(i),
                ),
              )),
            ],
          ],
        ),
        const SizedBox(height: 14),

        // ── Product details ───────────────────────────────────────────────
        _sectionCard(
          isDark: isDark, cardColor: cardColor, borderColor: borderColor,
          title: 'Product Details', icon: Icons.description_outlined,
          children: [
            _fieldLabel('Material'),
            _textField(controller: _materialCtrl, hint: 'e.g., 100% Cotton, Linen blend', isDark: isDark),
            const SizedBox(height: 14),
            _fieldLabel('Care Instructions'),
            _textField(controller: _careCtrl, hint: 'e.g., Machine wash cold, do not bleach', isDark: isDark, maxLines: 3),
          ],
        ),
      ],
    );
  }

  // ── Step 3: Pricing & Variations ─────────────────────────────────────────

  Widget _buildStep3(bool isDark, Color cardColor, Color borderColor) {
    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Pricing ──────────────────────────────────────────────────────
        _sectionCard(
          isDark: isDark, cardColor: cardColor, borderColor: borderColor,
          title: 'Pricing & Logistics', icon: Icons.payments_outlined,
          children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _fieldLabel('Price (₱) *'),
                _textField(controller: _priceCtrl, hint: '0.00', isDark: isDark,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _fieldLabel('Sale Price (₱)'),
                _textField(controller: _salePriceCtrl, hint: 'Optional', isDark: isDark,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]),
              ])),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _fieldLabel('Cost Price / COGS (₱)'),
                _textField(controller: _costPriceCtrl, hint: 'Optional', isDark: isDark,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _fieldLabel('Weight (kg)'),
                _textField(controller: _weightCtrl, hint: 'e.g., 0.5', isDark: isDark,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]),
              ])),
            ]),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Cost Price is used for gross profit in sales reports. Not visible to buyers.',
                style: TextStyle(fontSize: 11, color: AppColors.mutedForeground),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _fieldLabel('Low Stock Alert'),
                _textField(controller: _lowStockCtrl, hint: 'e.g., 3', isDark: isDark,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
              ])),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()), // spacer to keep layout balanced
            ]),
            const SizedBox(height: 14),
            _fieldLabel('Condition'),
            const SizedBox(height: 8),
            Row(children: [
              _conditionChip('new', 'New', isDark, borderColor),
              const SizedBox(width: 10),
              _conditionChip('used', 'Pre-loved / Used', isDark, borderColor),
            ]),
          ],
        ),
        const SizedBox(height: 14),

        // ── Variations ───────────────────────────────────────────────────
        _buildVariationsSection(isDark, cardColor, borderColor),
        const SizedBox(height: 14),

        // ── Terms ────────────────────────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _termsAgreed = !_termsAgreed),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _termsAgreed ? const Color(0xFF10B981) : borderColor,
                width: _termsAgreed ? 1.5 : 1,
              ),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 20, height: 20,
                decoration: BoxDecoration(
                  color: _termsAgreed ? const Color(0xFF10B981) : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: _termsAgreed ? const Color(0xFF10B981) : borderColor,
                    width: 2,
                  ),
                ),
                child: _termsAgreed
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'I confirm that this product complies with marketplace policies and all information provided is accurate.',
                  style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                ),
              ),
            ]),
          ),
        ),

        // ── Error banner ─────────────────────────────────────────────────
        if (_submitError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(children: [
              Icon(Icons.error_outline, color: Colors.red.shade600, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_submitError!,
                    style: TextStyle(fontSize: 13, color: Colors.red.shade700)),
              ),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _conditionChip(
      String value, String label, bool isDark, Color borderColor) {
    final isSelected = _condition == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _condition = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.rosewood
                : (isDark ? AppColors.darkBackground : AppColors.warmBeige),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isSelected ? AppColors.rosewood : borderColor),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.mutedForeground,
              )),
        ),
      ),
    );
  }

  // ── Variations section ────────────────────────────────────────────────────

  Widget _buildVariationsSection(
      bool isDark, Color cardColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.rosewood.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.palette_outlined,
                  size: 18, color: AppColors.rosewood),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Variations',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    Text('Add a color, then set sizes & stock below it',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.mutedForeground)),
                  ]),
            ),
            GestureDetector(
              onTap: _addColorGroup,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.rosewood,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add, size: 16, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Add Color',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),

          // Empty state
          if (_colorGroups.isEmpty) ...[
            const SizedBox(height: 20),
            Center(
              child: Column(children: [
                Icon(Icons.style_outlined,
                    size: 40, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                const Text('No variations yet',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.mutedForeground)),
                const SizedBox(height: 4),
                const Text('Tap "Add Color" to create a color group',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.mutedForeground)),
              ]),
            ),
            const SizedBox(height: 8),
          ] else ...[
            const SizedBox(height: 14),
            ..._colorGroups.map(
                (g) => _buildColorGroupCard(g, isDark, borderColor)),
          ],
        ],
      ),
    );
  }

  Widget _buildColorGroupCard(
      _ColorGroup group, bool isDark, Color borderColor) {
    final isOther = group.color == 'Other';
    final bgColor =
        isDark ? AppColors.darkBackground : const Color(0xFFFDF6F9);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Color header ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Color',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedForeground)),
                    const SizedBox(height: 6),
                    _dropdownField<String>(
                      value: group.color.isEmpty ? null : group.color,
                      hint: 'Select a color',
                      isDark: isDark,
                      items: _variationColors
                          .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c,
                                  style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => group.color = val ?? ''),
                    ),
                    // Custom color input
                    if (isOther) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: group.customColor,
                        onChanged: (val) =>
                            setState(() => group.customColor = val),
                        style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white
                                : AppColors.charcoal),
                        decoration: _inputDecoration(
                            hint: 'e.g., Rose Beige',
                            isDark: isDark,
                            borderColor: borderColor),
                      ),
                    ],
                  ]),
            ),
            const SizedBox(width: 10),
            // Delete color group
            GestureDetector(
              onTap: () => _removeColorGroup(group.id),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_outline,
                    size: 17, color: Colors.red),
              ),
            ),
          ]),
        ),

        // ── Divider ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Divider(height: 1, color: borderColor),
        ),

        // ── Size rows ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column headers
              Row(children: [
                const Expanded(
                    flex: 2,
                    child: Text('Size',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedForeground))),
                const SizedBox(width: 8),
                const Expanded(
                    flex: 2,
                    child: Text('Stock',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedForeground))),
                const SizedBox(width: 8),
                const Expanded(
                    flex: 3,
                    child: Text('SKU (optional)',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedForeground))),
                const SizedBox(width: 34), // space for delete btn
              ]),
              const SizedBox(height: 6),

              // Size rows
              ...group.rows.map((row) =>
                  _buildSizeRow(group.id, row, isDark, borderColor)),

              // Add size button
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _addSizeRow(group.id),
                child: Row(children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.rosewood),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.add,
                        size: 14, color: AppColors.rosewood),
                  ),
                  const SizedBox(width: 8),
                  const Text('Add size for this color',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.rosewood,
                          fontWeight: FontWeight.w500)),
                ]),
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildSizeRow(
      String groupId, _SizeRow row, bool isDark, Color borderColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        // Size dropdown
        Expanded(
          flex: 2,
          child: _dropdownField<String>(
            value: row.size,
            hint: 'Size',
            isDark: isDark,
            items: _clothingSizes
                .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s, style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: (val) => setState(() => row.size = val ?? 'M'),
          ),
        ),
        const SizedBox(width: 8),
        // Stock
        Expanded(
          flex: 2,
          child: TextFormField(
            initialValue: row.stock.toString(),
            onChanged: (val) =>
                setState(() => row.stock = int.tryParse(val) ?? 0),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : AppColors.charcoal),
            decoration: _inputDecoration(
                hint: '0', isDark: isDark, borderColor: borderColor),
          ),
        ),
        const SizedBox(width: 8),
        // SKU
        Expanded(
          flex: 3,
          child: TextFormField(
            initialValue: row.sku,
            onChanged: (val) => setState(() => row.sku = val),
            style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : AppColors.charcoal),
            decoration: _inputDecoration(
                hint: 'e.g., BLK-M',
                isDark: isDark,
                borderColor: borderColor),
          ),
        ),
        const SizedBox(width: 6),
        // Remove row (only if more than 1 row)
        GestureDetector(
          onTap: () => _removeSizeRow(groupId, row.id),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderColor),
            ),
            child: Icon(Icons.remove,
                size: 14,
                color: _colorGroups
                            .firstWhere((g) => g.id == groupId)
                            .rows
                            .length >
                        1
                    ? AppColors.mutedForeground
                    : borderColor),
          ),
        ),
      ]),
    );
  }

  // ── Bottom navigation bar ─────────────────────────────────────────────────

  Widget _buildBottomBar(bool isDark) {
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(children: [
        // Back / Cancel
        Expanded(
          child: OutlinedButton(
            onPressed: _step > 1
                ? () => setState(() => _step--)
                : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.mutedForeground,
              side: BorderSide(color: borderColor),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_step > 1 ? 'Back' : 'Cancel',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 12),
        // Next / Submit
        Expanded(
          flex: 2,
          child: _step < 3
              ? FilledButton(
                  onPressed: () {
                    String? err;
                    if (_step == 1) err = _validateStep1();
                    if (err != null) {
                      AlertService.showSnackBar(
                        context: context,
                        message: err,
                        variant: AlertVariant.error,
                      );
                      return;
                    }
                    setState(() => _step++);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.rosewood,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Next',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_ios, size: 14),
                    ],
                  ),
                )
              : FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline, size: 18),
                            SizedBox(width: 6),
                            Text('Create Product',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 15)),
                          ],
                        ),
                ),
        ),
      ]),
    );
  }

  // ── Shared UI helpers ─────────────────────────────────────────────────────

  Widget _sectionCard({
    required bool isDark,
    required Color cardColor,
    required Color borderColor,
    required String title,
    required IconData icon,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.rosewood.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppColors.rosewood),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              if (subtitle != null)
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.mutedForeground)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        ...children,
      ]),
    );
  }

  Widget _fieldLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedForeground)),
      );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white : AppColors.charcoal),
      decoration: _inputDecoration(
        hint: hint,
        isDark: isDark,
        borderColor: isDark ? AppColors.darkBorder : AppColors.border,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required bool isDark,
    required Color borderColor,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
          fontSize: 13, color: AppColors.mutedForeground),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.rosewood, width: 1.5)),
      filled: true,
      fillColor: isDark ? AppColors.darkBackground : Colors.white,
    );
  }

  Widget _dropdownField<T>({
    required T? value,
    required String hint,
    required bool isDark,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.mutedForeground)),
          isExpanded: true,
          dropdownColor: isDark ? AppColors.darkCard : Colors.white,
          style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white : AppColors.charcoal),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
