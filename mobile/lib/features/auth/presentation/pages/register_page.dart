import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

class _WilayahItem {
  final String id;
  final String name;
  const _WilayahItem({required this.id, required this.name});
  factory _WilayahItem.fromJson(Map<String, dynamic> j) =>
      _WilayahItem(id: j['id'] as String, name: j['name'] as String);
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey           = GlobalKey<FormState>();
  final _nameCtrl          = TextEditingController();
  final _emailCtrl         = TextEditingController();
  final _passCtrl          = TextEditingController();
  final _confirmCtrl       = TextEditingController();
  final _phoneCtrl         = TextEditingController();
  final _companyCtrl       = TextEditingController();
  final _industryOtherCtrl = TextEditingController();
  final _alamatCtrl        = TextEditingController();

  String  _industry    = '';
  bool    _loading     = false;
  bool    _obscurePass = true;
  bool    _obscureConf = true;
  String? _error;

  // ── Location cascade ──────────────────────────────────────────────────────
  String? _provinceId;
  String? _provinceName;
  String? _kotaId;
  String? _kotaName;
  String? _kecamatanId;
  String? _kecamatanName;
  String? _desaId;
  String? _desaName;

  List<_WilayahItem> _kotaList      = [];
  List<_WilayahItem> _kecamatanList = [];
  List<_WilayahItem> _desaList      = [];
  bool    _loadingKota      = false;
  bool    _loadingKecamatan = false;
  bool    _loadingDesa      = false;
  String? _kotaError;
  String? _kecamatanError;
  String? _desaError;

  final _wilayahDio = Dio(BaseOptions(
    baseUrl: 'https://emsifa.github.io/api-wilayah-indonesia/api/',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  // ── Static province list (38 provinsi) ───────────────────────────────────
  static const _provinces = <Map<String, String>>[
    {'id': '11', 'name': 'ACEH'},
    {'id': '12', 'name': 'SUMATERA UTARA'},
    {'id': '13', 'name': 'SUMATERA BARAT'},
    {'id': '14', 'name': 'RIAU'},
    {'id': '15', 'name': 'JAMBI'},
    {'id': '16', 'name': 'SUMATERA SELATAN'},
    {'id': '17', 'name': 'BENGKULU'},
    {'id': '18', 'name': 'LAMPUNG'},
    {'id': '19', 'name': 'KEPULAUAN BANGKA BELITUNG'},
    {'id': '21', 'name': 'KEPULAUAN RIAU'},
    {'id': '31', 'name': 'DKI JAKARTA'},
    {'id': '32', 'name': 'JAWA BARAT'},
    {'id': '33', 'name': 'JAWA TENGAH'},
    {'id': '34', 'name': 'DI YOGYAKARTA'},
    {'id': '35', 'name': 'JAWA TIMUR'},
    {'id': '36', 'name': 'BANTEN'},
    {'id': '51', 'name': 'BALI'},
    {'id': '52', 'name': 'NUSA TENGGARA BARAT'},
    {'id': '53', 'name': 'NUSA TENGGARA TIMUR'},
    {'id': '61', 'name': 'KALIMANTAN BARAT'},
    {'id': '62', 'name': 'KALIMANTAN TENGAH'},
    {'id': '63', 'name': 'KALIMANTAN SELATAN'},
    {'id': '64', 'name': 'KALIMANTAN TIMUR'},
    {'id': '65', 'name': 'KALIMANTAN UTARA'},
    {'id': '71', 'name': 'SULAWESI UTARA'},
    {'id': '72', 'name': 'SULAWESI TENGAH'},
    {'id': '73', 'name': 'SULAWESI SELATAN'},
    {'id': '74', 'name': 'SULAWESI TENGGARA'},
    {'id': '75', 'name': 'GORONTALO'},
    {'id': '76', 'name': 'SULAWESI BARAT'},
    {'id': '81', 'name': 'MALUKU'},
    {'id': '82', 'name': 'MALUKU UTARA'},
    {'id': '91', 'name': 'PAPUA BARAT'},
    {'id': '92', 'name': 'PAPUA'},
    {'id': '94', 'name': 'PAPUA SELATAN'},
    {'id': '95', 'name': 'PAPUA TENGAH'},
    {'id': '96', 'name': 'PAPUA PEGUNUNGAN'},
    {'id': '97', 'name': 'PAPUA BARAT DAYA'},
  ];

  static const _industries = [
    'Minyak & Gas',
    'Pembangkit Listrik',
    'Manufaktur',
    'Transportasi',
    'Konstruksi',
    'Pertambangan',
    'Kimia & Petrokimia',
    'Perkebunan & Agribisnis',
    'Energi Terbarukan',
    'Lainnya',
  ];

  bool   get _isOther      => _industry == 'Lainnya';
  String get _industryValue =>
      _isOther ? _industryOtherCtrl.text.trim() : _industry;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _phoneCtrl.dispose();
    _companyCtrl.dispose();
    _industryOtherCtrl.dispose();
    _alamatCtrl.dispose();
    super.dispose();
  }

  // ── Wilayah loaders ──────────────────────────────────────────────────────

  Future<void> _loadKota(String provinceId) async {
    setState(() {
      _loadingKota   = true;
      _kotaError     = null;
      _kotaList      = [];
      _kotaId        = null;
      _kotaName      = null;
      _kecamatanList = [];
      _kecamatanId   = null;
      _kecamatanName = null;
      _desaList      = [];
      _desaId        = null;
      _desaName      = null;
    });
    try {
      final res  = await _wilayahDio.get('regencies/$provinceId.json');
      final list = (res.data as List)
          .map((e) => _WilayahItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      setState(() { _kotaList = list; _loadingKota = false; });
    } catch (_) {
      setState(() { _kotaError = 'Gagal memuat data.'; _loadingKota = false; });
    }
  }

  Future<void> _loadKecamatan(String kotaId) async {
    setState(() {
      _loadingKecamatan = true;
      _kecamatanError   = null;
      _kecamatanList    = [];
      _kecamatanId      = null;
      _kecamatanName    = null;
      _desaList         = [];
      _desaId           = null;
      _desaName         = null;
    });
    try {
      final res  = await _wilayahDio.get('districts/$kotaId.json');
      final list = (res.data as List)
          .map((e) => _WilayahItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      setState(() { _kecamatanList = list; _loadingKecamatan = false; });
    } catch (_) {
      setState(() { _kecamatanError = 'Gagal memuat data.'; _loadingKecamatan = false; });
    }
  }

  Future<void> _loadDesa(String kecamatanId) async {
    setState(() {
      _loadingDesa = true;
      _desaError   = null;
      _desaList    = [];
      _desaId      = null;
      _desaName    = null;
    });
    try {
      final res  = await _wilayahDio.get('villages/$kecamatanId.json');
      final list = (res.data as List)
          .map((e) => _WilayahItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      setState(() { _desaList = list; _loadingDesa = false; });
    } catch (_) {
      setState(() { _desaError = 'Gagal memuat data.'; _loadingDesa = false; });
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient.instance.post('/auth/register', data: {
        'full_name':          _nameCtrl.text.trim(),
        'email':              _emailCtrl.text.trim(),
        'password':           _passCtrl.text,
        'phone':              _phoneCtrl.text.trim(),
        'company_name':       _companyCtrl.text.trim(),
        'company_industry':   _industryValue,
        'company_province':   _provinceName ?? '',
        'company_city':       _kotaName    ?? '',
        'company_kecamatan':  _kecamatanName ?? '',
        'company_kelurahan':  _desaName    ?? '',
        'company_address':    _alamatCtrl.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Registrasi berhasil! Cek email kamu untuk verifikasi akun.'),
          backgroundColor: AppTheme.secondary,
          duration: Duration(seconds: 4),
        ),
      );
      context.go('/login');
    } catch (e) {
      setState(() { _error = _extractError(e); _loading = false; });
    }
  }

  String _extractError(dynamic e) {
    try {
      final data = (e as dynamic).response?.data;
      if (data != null && data['message'] != null) return data['message'];
    } catch (_) {}
    return 'Terjadi kesalahan, coba lagi';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                color: AppTheme.primary,
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white70),
                      onPressed: () => context.go('/login'),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    const Text('Daftar Akun',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    const SizedBox(height: 4),
                    const Text('Buat akun client untuk mulai booking',
                        style: TextStyle(fontSize: 13, color: Colors.white70)),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Error banner
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.dangerLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppTheme.danger.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 16, color: AppTheme.danger),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_error!,
                                    style: const TextStyle(
                                        fontSize: 13, color: AppTheme.danger)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Data Pribadi ──────────────────────────────────────
                      _sectionLabel('Data Pribadi'),
                      const SizedBox(height: 10),

                      _label('Nama Lengkap *'),
                      _field(
                        ctrl: _nameCtrl,
                        hint: 'Contoh: BUDI SANTOSO',
                        icon: Icons.person_outline,
                        forceUpperCase: true,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Nama wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      _label('Email *'),
                      _field(
                        ctrl: _emailCtrl,
                        hint: 'nama@perusahaan.com',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email wajib diisi';
                          }
                          if (!v.contains('@')) return 'Format email tidak valid';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      _label('No. HP *'),
                      _field(
                        ctrl: _phoneCtrl,
                        hint: '08xxxxxxxxxx',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'No. HP wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      _label('Password *'),
                      _passField(
                        ctrl: _passCtrl,
                        hint: 'Minimal 6 karakter',
                        obscure: _obscurePass,
                        onToggle: () =>
                            setState(() => _obscurePass = !_obscurePass),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Password minimal 6 karakter'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      _label('Konfirmasi Password *'),
                      _passField(
                        ctrl: _confirmCtrl,
                        hint: 'Ulangi password',
                        obscure: _obscureConf,
                        onToggle: () =>
                            setState(() => _obscureConf = !_obscureConf),
                        validator: (v) =>
                            v != _passCtrl.text ? 'Password tidak cocok' : null,
                      ),
                      const SizedBox(height: 24),

                      // ── Data Perusahaan ───────────────────────────────────
                      _sectionLabel('Data Perusahaan'),
                      const SizedBox(height: 10),

                      _label('Nama Perusahaan *'),
                      _field(
                        ctrl: _companyCtrl,
                        hint: 'Contoh: PT MAJU JAYA',
                        icon: Icons.business_outlined,
                        forceUpperCase: true,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Nama perusahaan wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      _label('Industri *'),
                      DropdownButtonFormField<String>(
                        initialValue: _industry.isEmpty ? null : _industry,
                        hint: const Text('Pilih industri'),
                        isExpanded: true,
                        decoration: _dropdownDecor(Icons.category_outlined),
                        items: _industries
                            .map((i) => DropdownMenuItem(
                                  value: i,
                                  child: Text(i,
                                      style: const TextStyle(fontSize: 14)),
                                ))
                            .toList(),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Industri wajib dipilih'
                            : null,
                        onChanged: (v) =>
                            setState(() => _industry = v ?? ''),
                      ),

                      if (_isOther) ...[
                        const SizedBox(height: 10),
                        _field(
                          ctrl: _industryOtherCtrl,
                          hint: 'Tuliskan jenis industri',
                          icon: Icons.edit_outlined,
                          forceUpperCase: true,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Jenis industri wajib diisi'
                              : null,
                        ),
                      ],
                      const SizedBox(height: 24),

                      // ── Lokasi Perusahaan ─────────────────────────────────
                      _sectionLabel('Lokasi Perusahaan'),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 14, color: AppTheme.primary),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Lokasi ini digunakan untuk menentukan kelayakan booking Emergency (hanya Jabodetabek).',
                                style: TextStyle(
                                    fontSize: 11, color: AppTheme.primary),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Provinsi (static)
                      _label('Provinsi *'),
                      DropdownButtonFormField<String>(
                        initialValue: _provinceId,
                        hint: const Text('Pilih provinsi'),
                        isExpanded: true,
                        decoration: _dropdownDecor(Icons.map_outlined),
                        items: _provinces
                            .map((p) => DropdownMenuItem<String>(
                                  value: p['id'],
                                  child: Text(p['name']!,
                                      style:
                                          const TextStyle(fontSize: 14)),
                                ))
                            .toList(),
                        onChanged: (id) {
                          if (id == null) return;
                          final name = _provinces
                              .firstWhere((p) => p['id'] == id)['name']!;
                          setState(() {
                            _provinceId   = id;
                            _provinceName = name;
                          });
                          _loadKota(id);
                        },
                        validator: (v) =>
                            v == null ? 'Provinsi wajib dipilih' : null,
                      ),
                      const SizedBox(height: 14),

                      // Kota / Kabupaten (API)
                      _label('Kota / Kabupaten *'),
                      if (_loadingKota)
                        _loadingBox()
                      else if (_kotaError != null)
                        _errorBox(_kotaError!, () => _loadKota(_provinceId!))
                      else
                        DropdownButtonFormField<String>(
                          initialValue: _kotaId,
                          hint: Text(_provinceId == null
                              ? 'Pilih provinsi dulu'
                              : 'Pilih kota/kabupaten'),
                          isExpanded: true,
                          decoration: _dropdownDecor(Icons.location_city_outlined),
                          items: _kotaList
                              .map((k) => DropdownMenuItem<String>(
                                    value: k.id,
                                    child: Text(k.name,
                                        style:
                                            const TextStyle(fontSize: 14)),
                                  ))
                              .toList(),
                          onChanged: _provinceId == null
                              ? null
                              : (id) {
                                  if (id == null) return;
                                  final name = _kotaList
                                      .firstWhere((k) => k.id == id)
                                      .name;
                                  setState(() {
                                    _kotaId   = id;
                                    _kotaName = name;
                                  });
                                  _loadKecamatan(id);
                                },
                          validator: (v) =>
                              v == null ? 'Kota/Kabupaten wajib dipilih' : null,
                        ),
                      const SizedBox(height: 14),

                      // Kecamatan (API)
                      _label('Kecamatan *'),
                      if (_loadingKecamatan)
                        _loadingBox()
                      else if (_kecamatanError != null)
                        _errorBox(_kecamatanError!,
                            () => _loadKecamatan(_kotaId!))
                      else
                        DropdownButtonFormField<String>(
                          initialValue: _kecamatanId,
                          hint: Text(_kotaId == null
                              ? 'Pilih kota/kabupaten dulu'
                              : 'Pilih kecamatan'),
                          isExpanded: true,
                          decoration: _dropdownDecor(Icons.place_outlined),
                          items: _kecamatanList
                              .map((k) => DropdownMenuItem<String>(
                                    value: k.id,
                                    child: Text(k.name,
                                        style:
                                            const TextStyle(fontSize: 14)),
                                  ))
                              .toList(),
                          onChanged: _kotaId == null
                              ? null
                              : (id) {
                                  if (id == null) return;
                                  final name = _kecamatanList
                                      .firstWhere((k) => k.id == id)
                                      .name;
                                  setState(() {
                                    _kecamatanId   = id;
                                    _kecamatanName = name;
                                  });
                                  _loadDesa(id);
                                },
                          validator: (v) =>
                              v == null ? 'Kecamatan wajib dipilih' : null,
                        ),
                      const SizedBox(height: 14),

                      // Desa / Kelurahan (API)
                      _label('Desa / Kelurahan *'),
                      if (_loadingDesa)
                        _loadingBox()
                      else if (_desaError != null)
                        _errorBox(
                            _desaError!, () => _loadDesa(_kecamatanId!))
                      else
                        DropdownButtonFormField<String>(
                          initialValue: _desaId,
                          hint: Text(_kecamatanId == null
                              ? 'Pilih kecamatan dulu'
                              : 'Pilih desa/kelurahan'),
                          isExpanded: true,
                          decoration: _dropdownDecor(Icons.home_outlined),
                          items: _desaList
                              .map((d) => DropdownMenuItem<String>(
                                    value: d.id,
                                    child: Text(d.name,
                                        style:
                                            const TextStyle(fontSize: 14)),
                                  ))
                              .toList(),
                          onChanged: _kecamatanId == null
                              ? null
                              : (id) {
                                  if (id == null) return;
                                  final name = _desaList
                                      .firstWhere((d) => d.id == id)
                                      .name;
                                  setState(() {
                                    _desaId   = id;
                                    _desaName = name;
                                  });
                                },
                          validator: (v) =>
                              v == null ? 'Desa/Kelurahan wajib dipilih' : null,
                        ),
                      const SizedBox(height: 14),

                      // Alamat Detail
                      _label('Alamat Detail *'),
                      _field(
                        ctrl: _alamatCtrl,
                        hint: 'Nama jalan, nomor, RT/RW, dll',
                        icon: Icons.signpost_outlined,
                        forceUpperCase: true,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Alamat detail wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 28),

                      ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Daftar Sekarang',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Sudah punya akun? ',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary)),
                          GestureDetector(
                            onTap: () => context.go('/login'),
                            child: const Text('Login',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Decoration helpers ────────────────────────────────────────────────────

  InputDecoration _dropdownDecor(IconData icon) => InputDecoration(
        prefixIcon: Icon(icon, size: 18, color: AppTheme.textTertiary),
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  Widget _loadingBox() => Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Center(
          child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );

  Widget _errorBox(String msg, VoidCallback onRetry) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.dangerLight,
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(msg,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.danger)),
            ),
            TextButton(
              onPressed: onRetry,
              child: const Text('Coba lagi',
                  style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );

  Widget _sectionLabel(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryLight,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary)),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary)),
      );

  Widget _field({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool forceUpperCase = false,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        textCapitalization: forceUpperCase
            ? TextCapitalization.characters
            : TextCapitalization.none,
        inputFormatters: forceUpperCase
            ? [
                TextInputFormatter.withFunction(
                    (_, n) => n.copyWith(text: n.text.toUpperCase()))
              ]
            : null,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, size: 18, color: AppTheme.textTertiary),
          filled: true,
          fillColor: AppTheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.border),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        validator: validator,
      );

  Widget _passField({
    required TextEditingController ctrl,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: ctrl,
        obscureText: obscure,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.lock_outline,
              size: 18, color: AppTheme.textTertiary),
          suffixIcon: IconButton(
            icon: Icon(
              obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 18,
              color: AppTheme.textTertiary,
            ),
            onPressed: onToggle,
          ),
          filled: true,
          fillColor: AppTheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.border),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        validator: validator,
      );
}
