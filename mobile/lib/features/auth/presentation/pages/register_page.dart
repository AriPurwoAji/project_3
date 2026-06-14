import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey       = GlobalKey<FormState>();
  final _nameCtrl      = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _passCtrl      = TextEditingController();
  final _confirmCtrl   = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _companyCtrl   = TextEditingController();
  final _cityCtrl      = TextEditingController();

  String  _industry    = '';
  bool    _loading     = false;
  bool    _obscurePass = true;
  bool    _obscureConf = true;
  String? _error;

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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _phoneCtrl.dispose();
    _companyCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient.instance.post('/auth/register', data: {
        'full_name':         _nameCtrl.text.trim(),
        'email':             _emailCtrl.text.trim(),
        'password':          _passCtrl.text,
        'phone':             _phoneCtrl.text.trim(),
        'company_name':      _companyCtrl.text.trim(),
        'company_industry':  _industry,
        'company_city':      _cityCtrl.text.trim(),
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
      final msg = _extractError(e);
      setState(() { _error = msg; _loading = false; });
    }
  }

  String _extractError(dynamic e) {
    try {
      final data = (e as dynamic).response?.data;
      if (data != null && data['message'] != null) return data['message'];
    } catch (_) {}
    return 'Terjadi kesalahan, coba lagi';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Header ─────────────────────────────────────────────
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

              // ── Form ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.dangerLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    AppTheme.danger.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 16, color: AppTheme.danger),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_error!,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.danger)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Seksi: Data Pribadi ─────────────────────────
                      _sectionLabel('Data Pribadi'),
                      const SizedBox(height: 10),

                      _label('Nama Lengkap *'),
                      _field(
                        ctrl: _nameCtrl,
                        hint: 'Contoh: Budi Santoso',
                        icon: Icons.person_outline,
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
                          if (!v.contains('@')) {
                            return 'Format email tidak valid';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      _label('No. HP (opsional)'),
                      _field(
                        ctrl: _phoneCtrl,
                        hint: '08xxxxxxxxxx',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
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
                        validator: (v) => v != _passCtrl.text
                            ? 'Password tidak cocok'
                            : null,
                      ),
                      const SizedBox(height: 24),

                      // ── Seksi: Data Perusahaan ──────────────────────
                      _sectionLabel('Data Perusahaan'),
                      const SizedBox(height: 10),

                      _label('Nama Perusahaan *'),
                      _field(
                        ctrl: _companyCtrl,
                        hint: 'Contoh: PT Maju Jaya',
                        icon: Icons.business_outlined,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Nama perusahaan wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      _label('Industri'),
                      DropdownButtonFormField<String>(
                        initialValue: _industry.isEmpty ? null : _industry,
                        hint: const Text('Pilih industri'),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.category_outlined,
                              size: 18, color: AppTheme.textTertiary),
                          filled: true,
                          fillColor: AppTheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: AppTheme.border),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                        ),
                        items: _industries
                            .map((i) => DropdownMenuItem(
                                  value: i,
                                  child: Text(i,
                                      style: const TextStyle(fontSize: 14)),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _industry = v ?? ''),
                      ),
                      const SizedBox(height: 14),

                      _label('Kota / Kabupaten *'),
                      _field(
                        ctrl: _cityCtrl,
                        hint: 'Contoh: Surabaya',
                        icon: Icons.location_city_outlined,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Kota wajib diisi'
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
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
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
