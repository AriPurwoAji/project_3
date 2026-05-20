import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

class CreateBookingPage extends StatefulWidget {
  const CreateBookingPage({super.key});

  @override
  State<CreateBookingPage> createState() => _CreateBookingPageState();
}

class _CreateBookingPageState extends State<CreateBookingPage> {
  final _formKey = GlobalKey<FormState>();
  final _storage = const FlutterSecureStorage();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  String _serviceType = 'repair';
  String _urgencyLevel = 'standard';
  String? _selectedEquipmentId;
  String _companyId = '';
  List<dynamic> _equipments = [];
  bool _loading = false;
  bool _loadingEquipment = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _companyId = await _storage.read(key: 'company_id') ?? '';
    try {
      final res = await ApiClient.instance.get('/equipment');
      setState(() {
        _equipments = res.data['data'] ?? [];
        _loadingEquipment = false;
      });
    } catch (e) {
      setState(() => _loadingEquipment = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEquipmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih equipment terlebih dahulu'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await ApiClient.instance.post('/bookings', data: {
        'equipment_id': _selectedEquipmentId,
        'service_type': _serviceType,
        'urgency_level': _urgencyLevel,
        'description': _descCtrl.text.trim(),
        'site_address': _addressCtrl.text.trim(),
        'site_city': _cityCtrl.text.trim(),
        'photo_urls': [],
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking berhasil dibuat!'),
          backgroundColor: AppTheme.secondary,
        ),
      );
      context.go('/bookings');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal membuat booking'),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Booking'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/bookings'),
        ),
      ),
      body: _loadingEquipment
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Urgency selector
                    const Text('Tingkat urgensi',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(
                                () => _urgencyLevel = 'standard'),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _urgencyLevel == 'standard'
                                    ? AppTheme.primaryLight
                                    : AppTheme.surface,
                                border: Border.all(
                                  color: _urgencyLevel == 'standard'
                                      ? AppTheme.primary
                                      : AppTheme.border,
                                  width: _urgencyLevel == 'standard'
                                      ? 1.5
                                      : 0.5,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.schedule,
                                      color: _urgencyLevel == 'standard'
                                          ? AppTheme.primary
                                          : AppTheme.textTertiary),
                                  const SizedBox(height: 4),
                                  Text('Standard',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: _urgencyLevel == 'standard'
                                              ? AppTheme.primary
                                              : AppTheme.textSecondary)),
                                  Text('Terjadwal',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: _urgencyLevel == 'standard'
                                              ? AppTheme.primary
                                              : AppTheme.textTertiary)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(
                                () => _urgencyLevel = 'emergency'),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _urgencyLevel == 'emergency'
                                    ? AppTheme.dangerLight
                                    : AppTheme.surface,
                                border: Border.all(
                                  color: _urgencyLevel == 'emergency'
                                      ? AppTheme.danger
                                      : AppTheme.border,
                                  width: _urgencyLevel == 'emergency'
                                      ? 1.5
                                      : 0.5,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.warning_amber_outlined,
                                      color: _urgencyLevel == 'emergency'
                                          ? AppTheme.danger
                                          : AppTheme.textTertiary),
                                  const SizedBox(height: 4),
                                  Text('Emergency',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: _urgencyLevel == 'emergency'
                                              ? AppTheme.danger
                                              : AppTheme.textSecondary)),
                                  Text('Respon < 4 jam',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: _urgencyLevel == 'emergency'
                                              ? AppTheme.danger
                                              : AppTheme.textTertiary)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Service type
                    const Text('Jenis layanan',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        'repair',
                        'inspeksi',
                        'maintenance'
                      ].map((type) {
                        final isSelected = _serviceType == type;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _serviceType = type),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.surface,
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.border,
                              ),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              type,
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Equipment
                    const Text('Equipment',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedEquipmentId,
                      hint: const Text('Pilih equipment'),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppTheme.border),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                      items: _equipments.map<DropdownMenuItem<String>>((e) {
                        return DropdownMenuItem<String>(
                          value: e['id'],
                          child: Text(
                            '${e['name']} - ${e['brand'] ?? ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => _selectedEquipmentId = val),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    const Text('Deskripsi masalah',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Jelaskan masalah yang terjadi...',
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Deskripsi wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Site address
                    const Text('Lokasi site',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Alamat lokasi pekerjaan',
                        suffixIcon: Icon(Icons.location_on_outlined),
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Lokasi wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // City
                    const Text('Kota',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _cityCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Nama kota',
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Kota wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 28),

                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _urgencyLevel == 'emergency'
                                ? AppTheme.danger
                                : AppTheme.primary,
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ))
                          : Text(
                              _urgencyLevel == 'emergency'
                                  ? 'Submit Emergency Request'
                                  : 'Buat Booking',
                              style: const TextStyle(fontSize: 15)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}