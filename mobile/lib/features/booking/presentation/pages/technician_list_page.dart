import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bottom_nav.dart';

class TechnicianListPage extends StatefulWidget {
  const TechnicianListPage({super.key});

  @override
  State<TechnicianListPage> createState() => _TechnicianListPageState();
}

class _TechnicianListPageState extends State<TechnicianListPage> {
  List<dynamic> _technicians = [];
  bool   _loading = true;
  String _query   = '';
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<dynamic> get _filtered {
    if (_query.isEmpty) return _technicians;
    final q = _query.toLowerCase();
    return _technicians.where((t) =>
        (t['full_name'] ?? '').toLowerCase().contains(q) ||
        (t['email']     ?? '').toLowerCase().contains(q) ||
        (t['phone']     ?? '').toLowerCase().contains(q)).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchCtrl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 400),
          () { if (mounted) setState(() => _query = _searchCtrl.text); });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.get('/users/teknisi');
      if (mounted) {
        setState(() {
          _technicians = res.data['data'] ?? [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showAddUserSheet() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _AddUserSheet(),
    );
    if (added == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Teknisi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Tambah anggota',
            onPressed: _showAddUserSheet,
          ),
        ],
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 2),
      body: Column(
        children: [
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Cari nama, email, atau no. HP...',
                hintStyle: const TextStyle(
                    fontSize: 13, color: AppTheme.textTertiary),
                prefixIcon: const Icon(Icons.search,
                    size: 20, color: AppTheme.textTertiary),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close,
                            size: 18, color: AppTheme.textTertiary),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.background,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              _query.isNotEmpty
                                  ? 'Tidak ada teknisi yang cocok'
                                  : 'Belum ada teknisi terdaftar',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) => _techCard(filtered[i]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _techCard(dynamic t) {
    final name    = t['full_name'] ?? '-';
    final email   = t['email'] ?? '';
    final phone   = t['phone'] ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.primaryLight,
            child: Text(initial,
                style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.email_outlined,
                          size: 12, color: AppTheme.textTertiary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(email,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined,
                          size: 12, color: AppTheme.textTertiary),
                      const SizedBox(width: 4),
                      Text(phone,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.secondaryLight,
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Text('Teknisi',
                style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.secondary,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ─── TAMBAH USER SHEET ────────────────────────────────────────────────────────

class _AddUserSheet extends StatefulWidget {
  const _AddUserSheet();

  @override
  State<_AddUserSheet> createState() => _AddUserSheetState();
}

class _AddUserSheetState extends State<_AddUserSheet> {
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _phoneCtrl  = TextEditingController();
  String _role      = 'teknisi';
  bool   _loading   = false;
  bool   _obscure   = true;

  static const _roleLabels = {
    'teknisi': 'Teknisi',
    'sales':   'Sales',
    'client':  'Client',
  };

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ApiClient.instance.post('/users', data: {
        'full_name': _nameCtrl.text.trim(),
        'email':     _emailCtrl.text.trim(),
        'password':  _passCtrl.text,
        'phone':     _phoneCtrl.text.trim(),
        'role':      _role,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Akun ${_roleLabels[_role]} berhasil dibuat'),
        backgroundColor: AppTheme.secondary,
      ));
      Navigator.of(context).pop(true);
    } catch (e) {
      String msg = 'Gagal membuat akun';
      if (e is DioException) msg = e.response?.data['message'] ?? msg;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppTheme.danger));
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
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Tambah Anggota',
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

              // Role selector
              const Text('Role *',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: _roleLabels.entries.map((e) {
                  final selected = _role == e.key;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _role = e.key),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? AppTheme.primaryLight : AppTheme.surface,
                          border: Border.all(
                            color: selected ? AppTheme.primary : AppTheme.border,
                            width: selected ? 1.5 : 0.5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(e.value,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: selected
                                    ? AppTheme.primary
                                    : AppTheme.textSecondary)),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Nama
              const Text('Nama Lengkap *',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(hintText: 'Nama lengkap'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),

              // Email
              const Text('Email *',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'email@domain.com'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                  if (!v.contains('@')) return 'Format email tidak valid';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Password
              const Text('Password *',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  hintText: 'Minimal 6 karakter',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Minimal 6 karakter' : null,
              ),
              const SizedBox(height: 12),

              // No HP
              const Text('No. HP (opsional)',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: '08xxxxxxxxxx'),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('Buat Akun ${_roleLabels[_role]}',
                        style: const TextStyle(fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
