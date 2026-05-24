import 'package:flutter/material.dart';
import '../../core/services/alert_service.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/address_model.dart';
import '../../data/services/ph_geo_api.dart';

/// Address Selector Widget
/// Matches Next.js client AddressSelector component
/// Provides cascading selection for Philippine addresses
class AddressSelector extends StatefulWidget {
  final AddressData? value;
  final ValueChanged<AddressData> onChange;

  const AddressSelector({
    super.key,
    this.value,
    required this.onChange,
  });

  @override
  State<AddressSelector> createState() => _AddressSelectorState();
}

class _AddressSelectorState extends State<AddressSelector> {
  List<Region> _regions = [];
  List<Province> _provinces = [];
  List<Municipality> _municipalities = [];
  List<Barangay> _barangays = [];

  bool _isLoadingRegions = false;
  bool _isLoadingProvinces = false;
  bool _isLoadingMunicipalities = false;
  bool _isLoadingBarangays = false;
  bool _regionsLoadFailed = false;
  bool _manualMode = false;

  final _manualRegionCtrl = TextEditingController();
  final _manualProvinceCtrl = TextEditingController();
  final _manualMunicipalityCtrl = TextEditingController();
  final _manualBarangayCtrl = TextEditingController();

  String? _selectedRegionCode;
  String? _selectedProvinceCode;
  String? _selectedMunicipalityCode;
  String? _selectedBarangayCode;

  final _streetController = TextEditingController();
  final _postalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRegions();
    _initializeFromValue();
  }

  @override
  void dispose() {
    _streetController.dispose();
    _postalController.dispose();
    _manualRegionCtrl.dispose();
    _manualProvinceCtrl.dispose();
    _manualMunicipalityCtrl.dispose();
    _manualBarangayCtrl.dispose();
    super.dispose();
  }

  void _initializeFromValue() {
    if (widget.value != null) {
      _selectedRegionCode = widget.value!.regionCode.isNotEmpty
          ? widget.value!.regionCode
          : null;
      _selectedProvinceCode = widget.value!.provinceCode.isNotEmpty
          ? widget.value!.provinceCode
          : null;
      _selectedMunicipalityCode = widget.value!.municipalityCode.isNotEmpty
          ? widget.value!.municipalityCode
          : null;
      _selectedBarangayCode = widget.value!.barangayCode.isNotEmpty
          ? widget.value!.barangayCode
          : null;
      _streetController.text = widget.value!.streetAddress ?? '';
      _postalController.text = widget.value!.postalCode ?? '';

      // Load dependent data if region is set
      if (_selectedRegionCode != null) {
        if (isNCRRegion(_selectedRegionCode)) {
          _loadMunicipalitiesForRegion(_selectedRegionCode!, setState: false);
        } else {
          _loadProvinces(_selectedRegionCode!, setState: false);
          if (_selectedProvinceCode != null) {
            _loadMunicipalities(_selectedProvinceCode!, setState: false);
          }
        }
      }
      if (_selectedMunicipalityCode != null) {
        _loadBarangays(_selectedMunicipalityCode!, setState: false);
      }
    }
  }

  bool get _isNCR => isNCRRegion(_selectedRegionCode);

  Future<void> _loadRegions() async {
    setState(() => _isLoadingRegions = true);
    try {
      final data = await PhGeoApi.getRegions();
      setState(() {
        _regions = data.map((r) => Region.fromJson(r)).toList();
        _isLoadingRegions = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingRegions = false;
        _regionsLoadFailed = true;
        _manualMode = true;
      });
    }
  }

  void _notifyManualChange() {
    final region = _manualRegionCtrl.text.trim();
    final municipality = _manualMunicipalityCtrl.text.trim();
    final barangay = _manualBarangayCtrl.text.trim();
    if (region.isEmpty || municipality.isEmpty) return;
    widget.onChange(AddressData(
      regionCode: '',
      regionName: region,
      provinceCode: '',
      provinceName: _manualProvinceCtrl.text.trim().isNotEmpty
          ? _manualProvinceCtrl.text.trim()
          : 'N/A',
      municipalityCode: '',
      municipalityName: municipality,
      barangayCode: '',
      barangayName: barangay.isNotEmpty ? barangay : municipality,
      streetAddress:
          _streetController.text.isNotEmpty ? _streetController.text : null,
      postalCode:
          _postalController.text.isNotEmpty ? _postalController.text : null,
    ));
  }

  Future<void> _loadProvinces(String regionCode, {bool setState = true}) async {
    if (isNCRRegion(regionCode)) {
      if (setState) {
        this.setState(() {
          _provinces = [];
          _isLoadingProvinces = false;
        });
      }
      return;
    }
    if (setState) {
      this.setState(() => _isLoadingProvinces = true);
    }
    try {
      final data = await PhGeoApi.getProvinces(regionCode);
      if (setState) {
        this.setState(() {
          _provinces = data.map((p) => Province.fromJson(p)).toList();
          _isLoadingProvinces = false;
          // Reset dependent selections
          _municipalities = [];
          _barangays = [];
          _selectedProvinceCode = null;
          _selectedMunicipalityCode = null;
          _selectedBarangayCode = null;
        });
      } else {
        _provinces = data.map((p) => Province.fromJson(p)).toList();
        _isLoadingProvinces = false;
      }
    } catch (e) {
      if (setState) {
        this.setState(() => _isLoadingProvinces = false);
      }
      if (mounted && setState) {
        AlertService.showSnackBar(
          context: context,
          message: 'Failed to load provinces.',
          variant: AlertVariant.error,
        );
      }
    }
  }

  Future<void> _loadMunicipalitiesForRegion(
    String regionCode, {
    bool setState = true,
  }) async {
    if (setState) {
      this.setState(() => _isLoadingMunicipalities = true);
    }
    try {
      final data = await PhGeoApi.getMunicipalitiesByRegion(regionCode);
      if (setState) {
        this.setState(() {
          _municipalities = data.map((m) => Municipality.fromJson(m)).toList();
          _isLoadingMunicipalities = false;
          _barangays = [];
          _selectedMunicipalityCode = null;
          _selectedBarangayCode = null;
        });
      } else {
        _municipalities = data.map((m) => Municipality.fromJson(m)).toList();
        _isLoadingMunicipalities = false;
      }
    } catch (e) {
      if (setState) {
        this.setState(() => _isLoadingMunicipalities = false);
      }
    }
  }

  Future<void> _loadMunicipalities(String provinceCode, {bool setState = true}) async {
    if (setState) {
      this.setState(() => _isLoadingMunicipalities = true);
    }
    try {
      final data = await PhGeoApi.getMunicipalities(provinceCode);
      if (setState) {
        this.setState(() {
          _municipalities = data.map((m) => Municipality.fromJson(m)).toList();
          _isLoadingMunicipalities = false;
          // Reset dependent selections
          _barangays = [];
          _selectedMunicipalityCode = null;
          _selectedBarangayCode = null;
        });
      }
    } catch (e) {
      if (setState) {
        this.setState(() => _isLoadingMunicipalities = false);
      }
      if (mounted && setState) {
        AlertService.showSnackBar(
          context: context,
          message: 'Failed to load cities/municipalities.',
          variant: AlertVariant.error,
        );
      }
    }
  }

  Future<void> _loadBarangays(String municipalityCode, {bool setState = true}) async {
    if (setState) {
      this.setState(() => _isLoadingBarangays = true);
    }
    try {
      final data = await PhGeoApi.getBarangays(municipalityCode);
      if (setState) {
        this.setState(() {
          _barangays = data.map((b) => Barangay.fromJson(b)).toList();
          _isLoadingBarangays = false;
          _selectedBarangayCode = null;
        });
      }
    } catch (e) {
      if (setState) {
        this.setState(() => _isLoadingBarangays = false);
      }
      if (mounted && setState) {
        AlertService.showSnackBar(
          context: context,
          message: 'Failed to load barangays.',
          variant: AlertVariant.error,
        );
      }
    }
  }

  void _notifyChange() {
    if (_selectedRegionCode == null ||
        _selectedMunicipalityCode == null ||
        _selectedBarangayCode == null) {
      return;
    }
    if (!_isNCR && _selectedProvinceCode == null) {
      return;
    }

    final region = _regions.firstWhere((r) => r.code == _selectedRegionCode);
    final municipality =
        _municipalities.firstWhere((m) => m.code == _selectedMunicipalityCode);
    final barangay = _barangays.firstWhere((b) => b.code == _selectedBarangayCode);

    Province? province;
    if (!_isNCR && _selectedProvinceCode != null) {
      province = _provinces.firstWhere((p) => p.code == _selectedProvinceCode);
    }

    widget.onChange(AddressData(
      regionCode: region.code,
      regionName: region.displayName,
      provinceCode: _isNCR ? '' : (province?.code ?? ''),
      provinceName: _isNCR ? 'N/A (NCR)' : (province?.name ?? ''),
      municipalityCode: municipality.code,
      municipalityName: municipality.name,
      barangayCode: barangay.code,
      barangayName: barangay.name,
      streetAddress: _streetController.text.isNotEmpty ? _streetController.text : null,
      postalCode: _postalController.text.isNotEmpty ? _postalController.text : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_manualMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_regionsLoadFailed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Location list unavailable. Enter your address manually or retry.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _manualMode = false;
                        _regionsLoadFailed = false;
                      });
                      _loadRegions();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          TextField(
            controller: _manualRegionCtrl,
            decoration: const InputDecoration(labelText: 'Region'),
            onChanged: (_) => _notifyManualChange(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _manualProvinceCtrl,
            decoration: const InputDecoration(labelText: 'Province (optional)'),
            onChanged: (_) => _notifyManualChange(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _manualMunicipalityCtrl,
            decoration: const InputDecoration(labelText: 'City / Municipality'),
            onChanged: (_) => _notifyManualChange(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _manualBarangayCtrl,
            decoration: const InputDecoration(labelText: 'Barangay'),
            onChanged: (_) => _notifyManualChange(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _streetController,
            decoration: const InputDecoration(labelText: 'Street address'),
            onChanged: (_) => _notifyManualChange(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _postalController,
            decoration: const InputDecoration(labelText: 'Postal code'),
            onChanged: (_) => _notifyManualChange(),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_regionsLoadFailed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextButton.icon(
              onPressed: _loadRegions,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry loading regions'),
            ),
          ),
        // Region Dropdown
        _buildDropdown<Region>(
          label: 'Region',
          value: _selectedRegionCode,
          items: _regions,
          isLoading: _isLoadingRegions,
          displayName: (r) => r.displayName,
          onChanged: (code) {
            setState(() {
              _selectedRegionCode = code;
              _provinces = [];
              _municipalities = [];
              _barangays = [];
              _selectedProvinceCode = null;
              _selectedMunicipalityCode = null;
              _selectedBarangayCode = null;
            });
            if (code != null) {
              if (isNCRRegion(code)) {
                _loadMunicipalitiesForRegion(code);
              } else {
                _loadProvinces(code);
              }
            }
            _notifyChange();
          },
        ),
        const SizedBox(height: 16),

        // Province Dropdown
        _buildDropdown<Province>(
          label: _isNCR ? 'Province (N/A for NCR)' : 'Province',
          value: _selectedProvinceCode,
          items: _provinces,
          isLoading: _isLoadingProvinces,
          enabled: !_isNCR &&
              _selectedRegionCode != null &&
              _provinces.isNotEmpty,
          displayName: (p) => p.name,
          onChanged: (code) {
            setState(() => _selectedProvinceCode = code);
            if (code != null) {
              _loadMunicipalities(code);
            }
            _notifyChange();
          },
        ),
        const SizedBox(height: 16),

        // Municipality Dropdown
        _buildDropdown<Municipality>(
          label: 'City / Municipality',
          value: _selectedMunicipalityCode,
          items: _municipalities,
          isLoading: _isLoadingMunicipalities,
          enabled: _selectedRegionCode != null &&
              (_isNCR || _selectedProvinceCode != null) &&
              _municipalities.isNotEmpty,
          displayName: (m) => m.name,
          onChanged: (code) {
            setState(() => _selectedMunicipalityCode = code);
            if (code != null) {
              _loadBarangays(code);
            }
            _notifyChange();
          },
        ),
        const SizedBox(height: 16),

        // Barangay Dropdown
        _buildDropdown<Barangay>(
          label: 'Barangay',
          value: _selectedBarangayCode,
          items: _barangays,
          isLoading: _isLoadingBarangays,
          enabled: _selectedMunicipalityCode != null && _barangays.isNotEmpty,
          displayName: (b) => b.name,
          onChanged: (code) {
            setState(() => _selectedBarangayCode = code);
            _notifyChange();
          },
        ),
        const SizedBox(height: 16),

        // Street Address
        TextField(
          controller: _streetController,
          decoration: const InputDecoration(
            labelText: 'Street Address (Optional)',
            hintText: 'House number, street name',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _notifyChange(),
        ),
        const SizedBox(height: 16),

        // Postal Code
        TextField(
          controller: _postalController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Postal Code (Optional)',
            hintText: 'e.g., 1000',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _notifyChange(),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required String? value,
    required List<T> items,
    required bool isLoading,
    required String Function(T) displayName,
    required ValueChanged<String?> onChanged,
    bool enabled = true,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                hint: Text('Select $label'),
                onChanged: enabled ? onChanged : null,
                items: items.map((item) {
                  final code = (item as dynamic).code as String;
                  return DropdownMenuItem<String>(
                    value: code,
                    child: Text(
                      displayName(item),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }
}
