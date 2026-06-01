import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/location_search_field.dart';

class CreateBookingPage extends StatefulWidget {
  const CreateBookingPage({super.key});

  @override
  State<CreateBookingPage> createState() => _CreateBookingPageState();
}

class _CreateBookingPageState extends State<CreateBookingPage> {
  final _formKey = GlobalKey<FormState>();
  final _storage = const FlutterSecureStorage();
  final _descCtrl = TextEditingController();

  String _serviceType = 'repair';
  String _urgencyLevel = 'standard';
  String? _selectedEquipmentId;
  String _companyId = '';
  List<dynamic> _equipments = [];
  bool _loading = false;
  bool _loadingEquipment = true;
  DateTime? _scheduledAt;

  // Lokasi
  String   _address   = '';
  String   _city      = '';
  double?  _latitude;
  double?  _longitude;

  // Photo upload
  final _picker    = ImagePicker();
  final List<String> _photoUrls = [];
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _companyId = await _storage.read(key: AppConstants.companyIdKey) ?? '';
    try {
      final url = _companyId.isNotEmpty
          ? '/equipment?company_id=$_companyId'
          : '/equipment';
      final res = await ApiClient.instance.get(url);
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
    if (_address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih lokasi site terlebih dahulu'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await ApiClient.instance.post('/bookings', data: {
        'company_id':    _companyId,
        'equipment_id':  _selectedEquipmentId,
        'service_type':  _serviceType,
        'urgency_level': _urgencyLevel,
        'description':   _descCtrl.text.trim(),
        'site_address':  _address,
        'site_city':     _city,
        if (_latitude != null) 'latitude':  _latitude,
        if (_longitude != null) 'longitude': _longitude,
        'photo_urls':    _photoUrls,
        if (_scheduledAt != null)
          'scheduled_at': _scheduledAt!.toUtc().toIso8601String(),
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
      String errorMsg = 'Gagal membuat booking';
      if (e is DioException) {
        errorMsg = e.response?.data['message'] ?? errorMsg;
        debugPrint('ERROR DETAIL: ${e.response?.data}');
        debugPrint('COMPANY ID: $_companyId');
        debugPrint('EQUIPMENT ID: $_selectedEquipmentId');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatScheduled(DateTime dt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month]} ${dt.year} · $h:$m';
  }

  Future<void> _pickScheduledAt() async {
    final now  = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt ?? now),
    );
    if (time == null || !mounted) return;

    setState(() {
      _scheduledAt = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
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
                            fontSize: 13, color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _urgencyCard('standard', 'Standard',
                            'Terjadwal', Icons.schedule)),
                        const SizedBox(width: 10),
                        Expanded(child: _urgencyCard('emergency', 'Emergency',
                            'Respon < 4 jam', Icons.warning_amber_outlined)),
                      ],
                    ),
                    // Jadwal booking (hanya untuk standard)
                    if (_urgencyLevel == 'standard') ...[
                      const SizedBox(height: 16),
                      const Text('Jadwal servis (opsional)',
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.textSecondary)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickScheduledAt,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            border: Border.all(color: AppTheme.border),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_month_outlined,
                                size: 18,
                                color: _scheduledAt != null
                                    ? AppTheme.primary
                                    : AppTheme.textTertiary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _scheduledAt != null
                                      ? _formatScheduled(_scheduledAt!)
                                      : 'Pilih tanggal & jam',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _scheduledAt != null
                                        ? AppTheme.textPrimary
                                        : AppTheme.textTertiary,
                                  ),
                                ),
                              ),
                              if (_scheduledAt != null)
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _scheduledAt = null),
                                  child: const Icon(Icons.close,
                                      size: 16,
                                      color: AppTheme.textTertiary),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Service type
                    const Text('Jenis layanan',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['repair', 'inspeksi', 'maintenance']
                          .map((type) => _serviceChip(type))
                          .toList(),
                    ),
                    const SizedBox(height: 16),

                    // Equipment dropdown
                    const Text('Equipment',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    _equipments.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              border: Border.all(color: AppTheme.border),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline,
                                    size: 16, color: AppTheme.textTertiary),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Belum ada equipment. Tap "+ Tambah" untuk menambahkan.',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : DropdownButtonFormField<String>(
                            initialValue: _selectedEquipmentId,
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
                            items: _equipments
                                .map<DropdownMenuItem<String>>((e) {
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
                            fontSize: 13, color: AppTheme.textSecondary)),
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

                    // Lokasi site — search + GPS
                    const Text('Lokasi site',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    LocationSearchField(
                      onSelected: (result) {
                        setState(() {
                          _address   = result.address;
                          _city      = result.city;
                          _latitude  = result.latitude;
                          _longitude = result.longitude;
                        });
                      },
                    ),
                    if (_city.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_city_outlined,
                              size: 13, color: AppTheme.textTertiary),
                          const SizedBox(width: 4),
                          Text(_city,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textTertiary)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Foto kerusakan (opsional)
                    const Text('Foto kerusakan (opsional)',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ..._photoUrls.map((url) => _photoThumb(url)),
                          if (_uploadingPhoto)
                            _photoLoadingBox()
                          else if (_photoUrls.length < 5)
                            _addPhotoButton(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _urgencyLevel == 'emergency'
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

  Widget _urgencyCard(
      String value, String label, String sub, IconData icon) {
    final isSelected = _urgencyLevel == value;
    final isEmergency = value == 'emergency';
    final color = isEmergency ? AppTheme.danger : AppTheme.primary;
    final bgColor = isEmergency ? AppTheme.dangerLight : AppTheme.primaryLight;

    return GestureDetector(
      onTap: () => setState(() {
        _urgencyLevel = value;
        if (value == 'emergency') _scheduledAt = null;
      }),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? bgColor : AppTheme.surface,
          border: Border.all(
            color: isSelected ? color : AppTheme.border,
            width: isSelected ? 1.5 : 0.5,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : AppTheme.textTertiary),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? color : AppTheme.textSecondary)),
            Text(sub,
                style: TextStyle(
                    fontSize: 11,
                    color: isSelected ? color : AppTheme.textTertiary)),
          ],
        ),
      ),
    );
  }

  // ─── Photo helpers ───────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Ambil foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final xfile = await _picker.pickImage(
        source: source, imageQuality: 80, maxWidth: 1920);
    if (xfile == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(xfile.path,
            filename: xfile.name),
      });
      final res = await ApiClient.instance.post('/upload', data: formData);
      final url = res.data['data']['url'] as String;
      if (mounted) setState(() => _photoUrls.add(url));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal upload foto')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Widget _photoThumb(String url) => Stack(
        children: [
          Container(
            width: 80,
            height: 80,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                  image: NetworkImage(url), fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 2,
            right: 10,
            child: GestureDetector(
              onTap: () => setState(() => _photoUrls.remove(url)),
              child: Container(
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close,
                    size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      );

  Widget _photoLoadingBox() => Container(
        width: 80,
        height: 80,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2)),
      );

  Widget _addPhotoButton() => GestureDetector(
        onTap: _uploadingPhoto ? null : _pickPhoto,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border, width: 1.5),
          ),
          child: const Icon(Icons.add_photo_alternate_outlined,
              color: AppTheme.textTertiary, size: 28),
        ),
      );

  Widget _serviceChip(String type) {
    final isSelected = _serviceType == type;
    return GestureDetector(
      onTap: () => setState(() => _serviceType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surface,
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
          ),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          type,
          style: TextStyle(
              fontSize: 13,
              color: isSelected ? Colors.white : AppTheme.textSecondary),
        ),
      ),
    );
  }
}

// Bottom sheet untuk tambah equipment baru
class _AddEquipmentSheet extends StatefulWidget {
  final String companyId;
  const _AddEquipmentSheet({required this.companyId});

  @override
  State<_AddEquipmentSheet> createState() => _AddEquipmentSheetState();
}

class _AddEquipmentSheetState extends State<_AddEquipmentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();
  final _pressureCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  String _type = 'pump';
  bool _loading = false;

  static const _typeLabels = {
    'pump': 'Pompa',
    'hose': 'Selang',
    'accumulator': 'Akumulator',
    'cylinder': 'Silinder',
  };

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _serialCtrl.dispose();
    _pressureCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.post('/equipment', data: {
        'company_id':         widget.companyId,
        'name':               _nameCtrl.text.trim(),
        'type':               _type,
        'brand':              _brandCtrl.text.trim(),
        'model':              _modelCtrl.text.trim(),
        'serial_number':      _serialCtrl.text.trim(),
        'rated_pressure_bar': int.tryParse(_pressureCtrl.text) ?? 0,
        'location_detail':    _locationCtrl.text.trim(),
      });

      if (!mounted) return;
      Navigator.of(context).pop(res.data['data']);
    } catch (e) {
      String msg = 'Gagal menambah equipment';
      if (e is DioException) {
        msg = e.response?.data['message'] ?? msg;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppTheme.danger),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                const Text('Tambah Equipment',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nama equipment
                  _label('Nama Equipment *'),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                        hintText: 'Contoh: Pompa Hidrolik #1'),
                    validator: (v) => v == null || v.isEmpty
                        ? 'Nama wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 12),

                  // Tipe
                  _label('Tipe Equipment *'),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppTheme.border)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    items: _typeLabels.entries
                        .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                  const SizedBox(height: 12),

                  // Brand & Model berdampingan
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Brand'),
                            TextFormField(
                              controller: _brandCtrl,
                              decoration: const InputDecoration(
                                  hintText: 'Contoh: Bosch'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Model'),
                            TextFormField(
                              controller: _modelCtrl,
                              decoration: const InputDecoration(
                                  hintText: 'Contoh: A-200'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Serial number & tekanan berdampingan
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Serial Number'),
                            TextFormField(
                              controller: _serialCtrl,
                              decoration: const InputDecoration(
                                  hintText: 'SN-XXXX'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Tekanan (bar)'),
                            TextFormField(
                              controller: _pressureCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              decoration: const InputDecoration(
                                  hintText: '0'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Lokasi detail
                  _label('Lokasi Detail'),
                  TextFormField(
                    controller: _locationCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Contoh: Lantai 2, Ruang Mesin',
                      suffixIcon: Icon(Icons.location_on_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tombol submit
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                        : const Text('Simpan Equipment',
                            style: TextStyle(fontSize: 15)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary)),
      );
}
