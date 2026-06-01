import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bottom_nav.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _storage = const FlutterSecureStorage();

  String _name             = '';
  String _email            = '';
  String _phone            = '';
  String _role             = '';
  String _companyName      = '';
  String _companyIndustry  = '';
  String _companyCity      = '';
  String _companyId        = '';
  String _avatarUrl        = '';
  bool   _uploadingAvatar  = false;

  // Client/sales
  List<dynamic> _equipment = [];

  // Teknisi
  int    _totalJobs  = 0;
  int    _monthJobs  = 0;
  List<dynamic> _recentJobs = [];

  bool _loading = true;

  bool get _isClient  => _role == AppConstants.roleClient || _role == AppConstants.roleSales;
  bool get _isTeknisi => _role == AppConstants.roleTeknisi;

  int get _navIndex {
    switch (_role) {
      case AppConstants.roleSales:   return 2; // Booking=0, Riwayat=1, Profil=2
      case AppConstants.roleTeknisi: return 2; // JobBoard=0, Laporan=1, Profil=2
      default:                       return 3; // manager/client index 3
    }
  }

  @override
  void initState() {
    super.initState();
    // Pre-load role agar navIndex benar sebelum BottomNav selesai build
    _storage.read(key: AppConstants.userRoleKey).then((r) {
      if (mounted && _role.isEmpty) setState(() => _role = r ?? '');
    });
    _loadData();
  }

  Future<void> _loadData() async {
    _name        = await _storage.read(key: AppConstants.userNameKey)    ?? '';
    _email       = await _storage.read(key: AppConstants.userIDKey)      ?? '';
    _role        = await _storage.read(key: AppConstants.userRoleKey)    ?? '';
    _companyName = await _storage.read(key: AppConstants.companyNameKey) ?? '';
    _companyId = await _storage.read(key: AppConstants.companyIdKey) ?? '';
    final companyId = _companyId;

    // Fetch data lengkap dari /auth/me
    try {
      final me   = await ApiClient.instance.get('/auth/me');
      final data = me.data['data'] as Map<String, dynamic>? ?? {};
      _email           = data['email']            ?? '';
      _phone           = data['phone']            ?? '';
      _avatarUrl       = data['avatar_url']       ?? '';
      _companyIndustry = data['company_industry'] ?? '';
      _companyCity     = data['company_city']     ?? '';
    } catch (_) {}

    if (_isClient && companyId.isNotEmpty) {
      try {
        final res = await ApiClient.instance
            .get('/equipment?company_id=$companyId');
        _equipment = res.data['data'] ?? [];
      } catch (_) {}
    }

    if (_isTeknisi) {
      try {
        final res = await ApiClient.instance.get('/my-jobs');
        final jobs = List<dynamic>.from(res.data['data'] ?? []);
        _totalJobs = jobs.length;
        final now   = DateTime.now();
        _monthJobs  = jobs.where((j) {
          try {
            final d = DateTime.parse(j['updated_at'] ?? '');
            return d.year == now.year && d.month == now.month &&
                j['status'] == 'done';
          } catch (_) {
            return false;
          }
        }).length;
        _recentJobs = jobs
            .where((j) => j['status'] == 'done')
            .take(3)
            .toList();
      } catch (_) {}
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _logout() async {
    await ApiClient.clearToken();
    if (mounted) context.go('/login');
  }

  // ─── FOTO PROFIL ──────────────────────────────────────────────────────────

  Future<void> _pickAndUploadAvatar() async {
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

    final picker = ImagePicker();
    final xfile  = await picker.pickImage(
        source: source, imageQuality: 80, maxWidth: 512);
    if (xfile == null || !mounted) return;

    setState(() => _uploadingAvatar = true);
    try {
      // Upload foto ke Supabase Storage
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(xfile.path, filename: xfile.name),
      });
      final uploadRes = await ApiClient.instance.post('/upload', data: formData);
      final url = uploadRes.data['data']['url'] as String;

      // Simpan URL ke profil
      await ApiClient.instance.patch('/auth/profile', data: {
        'full_name': _name,
        'phone':     _phone,
        'avatar_url': url,
      });

      if (mounted) setState(() => _avatarUrl = url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengupload foto')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  // ─── EDIT PROFILE ─────────────────────────────────────────────────────────

  void _showEditProfileSheet() {
    final nameCtrl  = TextEditingController(text: _name);
    final phoneCtrl = TextEditingController(text: _phone);
    bool saving     = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Edit Profil',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    _sheetField('Nama Lengkap', nameCtrl),
                    const SizedBox(height: 12),
                    _sheetField('No. HP', phoneCtrl,
                        keyboardType: TextInputType.phone),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              setSt(() => saving = true);
                              try {
                                await ApiClient.instance.patch(
                                    '/auth/profile',
                                    data: {
                                      'full_name': nameCtrl.text.trim(),
                                      'phone':
                                          phoneCtrl.text.trim(),
                                    });
                                await _storage.write(
                                    key: AppConstants.userNameKey,
                                    value: nameCtrl.text.trim());
                                if (ctx.mounted) Navigator.pop(ctx);
                                _loadData();
                              } catch (_) {
                                setSt(() => saving = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Simpan'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── CHANGE PASSWORD ──────────────────────────────────────────────────────

  void _showChangePasswordSheet() {
    final oldCtrl  = TextEditingController();
    final newCtrl  = TextEditingController();
    final confCtrl = TextEditingController();
    bool saving    = false;
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Ganti Password',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    if (error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.dangerLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(error!,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.danger)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _sheetField('Password Lama', oldCtrl,
                        obscure: true),
                    const SizedBox(height: 10),
                    _sheetField('Password Baru', newCtrl,
                        obscure: true),
                    const SizedBox(height: 10),
                    _sheetField('Konfirmasi Password Baru', confCtrl,
                        obscure: true),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              if (newCtrl.text != confCtrl.text) {
                                setSt(() =>
                                    error = 'Password baru tidak cocok');
                                return;
                              }
                              if (newCtrl.text.length < 6) {
                                setSt(() => error =
                                    'Password minimal 6 karakter');
                                return;
                              }
                              setSt(() {
                                saving = true;
                                error  = null;
                              });
                              try {
                                await ApiClient.instance.post(
                                    '/auth/change-password',
                                    data: {
                                      'old_password': oldCtrl.text,
                                      'new_password': newCtrl.text,
                                    });
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(ctx)
                                      .showSnackBar(const SnackBar(
                                    content: Text('Password berhasil diubah'),
                                    backgroundColor: AppTheme.secondary,
                                  ));
                                }
                              } catch (e) {
                                final msg = _extractMsg(e);
                                setSt(() {
                                  error  = msg;
                                  saving = false;
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Ubah Password'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── EQUIPMENT CRUD ───────────────────────────────────────────────────────

  void _showAddEquipmentSheet() {
    final nameCtrl     = TextEditingController();
    final brandCtrl    = TextEditingController();
    final modelCtrl    = TextEditingController();
    final serialCtrl   = TextEditingController();
    final pressureCtrl = TextEditingController();
    final locCtrl      = TextEditingController();
    String type        = 'pump';
    bool saving        = false;

    const typeLabels = {
      'pump': 'Pompa', 'hose': 'Selang',
      'accumulator': 'Akumulator', 'cylinder': 'Silinder',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetHandle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Tambah Equipment',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      _sheetField('Nama Equipment *', nameCtrl),
                      const SizedBox(height: 10),
                      // Tipe
                      DropdownButtonFormField<String>(
                        initialValue: type,
                        decoration: InputDecoration(
                          labelText: 'Tipe Equipment',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                        ),
                        items: typeLabels.entries
                            .map((e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                ))
                            .toList(),
                        onChanged: (v) => setSt(() => type = v!),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _sheetField('Brand', brandCtrl)),
                          const SizedBox(width: 10),
                          Expanded(child: _sheetField('Model', modelCtrl)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                              child: _sheetField('Serial Number', serialCtrl)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _sheetField('Tekanan (bar)', pressureCtrl,
                                  keyboardType: TextInputType.number)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _sheetField('Lokasi Detail', locCtrl),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                if (nameCtrl.text.trim().isEmpty) return;
                                setSt(() => saving = true);
                                try {
                                  await ApiClient.instance.post(
                                      '/equipment',
                                      data: {
                                        'company_id':   _companyId,
                                        'name':         nameCtrl.text.trim(),
                                        'type':         type,
                                        'brand':        brandCtrl.text.trim(),
                                        'model':        modelCtrl.text.trim(),
                                        'serial_number': serialCtrl.text.trim(),
                                        'rated_pressure_bar':
                                            int.tryParse(pressureCtrl.text) ?? 0,
                                        'location_detail':
                                            locCtrl.text.trim(),
                                      });
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  _loadData();
                                } catch (_) {
                                  setSt(() => saving = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: saving
                            ? const SizedBox(
                                height: 18, width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Simpan Equipment'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditEquipmentSheet(dynamic e) {
    final nameCtrl  = TextEditingController(text: e['name'] ?? '');
    final brandCtrl = TextEditingController(text: e['brand'] ?? '');
    final modelCtrl = TextEditingController(text: e['model'] ?? '');
    final locCtrl   = TextEditingController(
        text: e['location_detail'] ?? '');
    bool saving     = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetHandle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Edit Equipment',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      _sheetField('Nama Equipment', nameCtrl),
                      const SizedBox(height: 10),
                      _sheetField('Brand', brandCtrl),
                      const SizedBox(height: 10),
                      _sheetField('Model', modelCtrl),
                      const SizedBox(height: 10),
                      _sheetField('Lokasi', locCtrl),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                setSt(() => saving = true);
                                try {
                                  await ApiClient.instance.patch(
                                      '/equipment/${e['id']}',
                                      data: {
                                        'name':  nameCtrl.text.trim(),
                                        'brand': brandCtrl.text.trim(),
                                        'model': modelCtrl.text.trim(),
                                        'location_detail':
                                            locCtrl.text.trim(),
                                        'type':
                                            e['type'] ?? 'hydraulic',
                                      });
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  _loadData();
                                } catch (_) {
                                  setSt(() => saving = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const Text('Simpan'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteEquipment(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Equipment?'),
        content:
            const Text('Equipment yang dihapus tidak bisa dikembalikan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger,
                foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiClient.instance.delete('/equipment/$id');
      _loadData();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menghapus equipment')),
        );
      }
    }
  }

  // ─── SHEET HELPERS ────────────────────────────────────────────────────────

  Widget _sheetHandle() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppTheme.border,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      );

  Widget _sheetField(
    String hint,
    TextEditingController ctrl, {
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        obscureText: obscure,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: AppTheme.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.border),
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
        ),
      );

  String _extractMsg(dynamic e) {
    try {
      return (e as dynamic).response?.data?['message'] ?? 'Terjadi kesalahan';
    } catch (_) {
      return 'Terjadi kesalahan';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isTeknisi ? 'Profil Teknisi' : 'Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _showEditProfileSheet,
            tooltip: 'Edit profil',
          ),
        ],
      ),
      bottomNavigationBar: BottomNav(currentIndex: _navIndex),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildAvatarSection(),
                  const SizedBox(height: 20),
                  if (_isTeknisi) ...[
                    _buildTeknisiStats(),
                    const SizedBox(height: 16),
                    _buildRecentJobs(),
                  ] else if (_isClient) ...[
                    _buildCompanyInfo(),
                    const SizedBox(height: 16),
                    _buildEquipmentSection(),
                  ],
                  const SizedBox(height: 16),
                  _buildLogoutButton(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  // ─── AVATAR ───────────────────────────────────────────────────────────────

  Widget _buildAvatarSection() {
    final initial   = _name.isNotEmpty ? _name[0].toUpperCase() : '?';
    final roleBadge = _isTeknisi ? 'Teknisi' : _isClient ? 'Client PIC' : _role;

    return Column(
      children: [
        // ── Avatar dengan tombol ganti foto ──────────────────────────
        GestureDetector(
          onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
          child: Stack(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: AppTheme.primaryLight,
                backgroundImage: _avatarUrl.isNotEmpty
                    ? NetworkImage(_avatarUrl)
                    : null,
                child: _uploadingAvatar
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : _avatarUrl.isEmpty
                        ? Text(initial,
                            style: const TextStyle(
                                fontSize: 32,
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600))
                        : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt,
                      size: 15, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(_name,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w600)),
        if (_email.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(_email,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary)),
        ],
        if (_phone.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(_phone,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary)),
        ],
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(roleBadge,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.primary)),
        ),
      ],
    );
  }

  // ─── TEKNISI: STATS ───────────────────────────────────────────────────────

  Widget _buildTeknisiStats() {
    return Row(
      children: [
        _statCard('$_monthJobs', 'Job bulan ini'),
        const SizedBox(width: 10),
        _statCard('$_totalJobs', 'Total job'),
        const SizedBox(width: 10),
        _statCard('-', 'Rating'),
      ],
    );
  }

  Widget _statCard(String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  // ─── TEKNISI: RECENT JOBS ─────────────────────────────────────────────────

  Widget _buildRecentJobs() {
    if (_recentJobs.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Riwayat job terbaru',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ..._recentJobs.map((j) => _recentJobRow(j)),
        ],
      ),
    );
  }

  Widget _recentJobRow(dynamic j) {
    final desc = j['description'] ?? '-';
    final company = j['company_name'] ?? '';
    final type = j['service_type'] ?? '';
    final date = _formatDate(j['updated_at'] ?? '');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$desc — $company',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('$date · ${_capitalize(type)}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Text('Selesai',
                style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.secondary,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // ─── CLIENT: COMPANY INFO ─────────────────────────────────────────────────

  Widget _buildCompanyInfo() {
    if (_companyName.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Info perusahaan',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          _infoRow('Perusahaan', _companyName),
          if (_companyIndustry.isNotEmpty)
            _infoRow('Industri', _companyIndustry),
          if (_companyCity.isNotEmpty)
            _infoRow('Kota', _companyCity),
        ],
      ),
    );
  }

  // ─── CLIENT: EQUIPMENT ────────────────────────────────────────────────────

  Widget _buildEquipmentSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Equipment perusahaan',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              GestureDetector(
                onTap: _showAddEquipmentSheet,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Icon(Icons.add,
                      color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_equipment.isEmpty)
            const Text('Belum ada equipment',
                style: TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary))
          else
            ..._equipment.map(_equipmentRow),
        ],
      ),
    );
  }

  Widget _equipmentRow(dynamic e) {
    final name   = e['name'] ?? '-';
    final brand  = e['brand'] ?? '';
    final serial = e['serial_number'] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                if (brand.isNotEmpty || serial.isNotEmpty)
                  Text(
                    [
                      if (brand.isNotEmpty) brand,
                      if (serial.isNotEmpty) serial,
                    ].join(' · '),
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                size: 16, color: AppTheme.textSecondary),
            onPressed: () => _showEditEquipmentSheet(e),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 16, color: AppTheme.danger),
            onPressed: () => _deleteEquipment(e['id'] as String),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  // ─── LOGOUT & SETTINGS ───────────────────────────────────────────────────

  Widget _buildLogoutButton() {
    return Column(
      children: [
        _settingsRow(
          icon: Icons.lock_outline,
          label: 'Ganti Password',
          color: AppTheme.textSecondary,
          onTap: _showChangePasswordSheet,
        ),
        const SizedBox(height: 12),
        _settingsRow(
          icon: Icons.logout,
          label: 'Logout',
          color: AppTheme.danger,
          onTap: _logout,
        ),
      ],
    );
  }

  Widget _settingsRow({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );

  // ─── HELPERS ──────────────────────────────────────────────────────────────

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      return '${dt.day} ${months[dt.month]}';
    } catch (_) {
      return '-';
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
