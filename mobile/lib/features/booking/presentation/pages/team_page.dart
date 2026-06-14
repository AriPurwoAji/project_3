import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bottom_nav.dart';

class TeamPage extends StatefulWidget {
  const TeamPage({super.key});

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  List<dynamic> _teknisi = [];
  List<dynamic> _sales   = [];
  List<dynamic> _clients = [];
  bool _loading = true;

  String _queryTeknisi = '';
  String _querySales   = '';
  String _queryClient  = '';

  final _searchTeknisi = TextEditingController();
  final _searchSales   = TextEditingController();
  final _searchClient  = TextEditingController();

  Timer? _debounceTeknisi;
  Timer? _debounceSales;
  Timer? _debounceClient;

  List<dynamic> _filter(List<dynamic> list, String q) {
    if (q.isEmpty) return list;
    final lower = q.toLowerCase();
    return list.where((u) =>
        (u['full_name']    ?? '').toLowerCase().contains(lower) ||
        (u['email']        ?? '').toLowerCase().contains(lower) ||
        (u['phone']        ?? '').toLowerCase().contains(lower) ||
        (u['company_name'] ?? '').toLowerCase().contains(lower)).toList();
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadData();
    _searchTeknisi.addListener(() {
      _debounceTeknisi?.cancel();
      _debounceTeknisi = Timer(const Duration(milliseconds: 400),
          () { if (mounted) setState(() => _queryTeknisi = _searchTeknisi.text); });
    });
    _searchSales.addListener(() {
      _debounceSales?.cancel();
      _debounceSales = Timer(const Duration(milliseconds: 400),
          () { if (mounted) setState(() => _querySales = _searchSales.text); });
    });
    _searchClient.addListener(() {
      _debounceClient?.cancel();
      _debounceClient = Timer(const Duration(milliseconds: 400),
          () { if (mounted) setState(() => _queryClient = _searchClient.text); });
    });
  }

  @override
  void dispose() {
    _debounceTeknisi?.cancel();
    _debounceSales?.cancel();
    _debounceClient?.cancel();
    _tabCtrl.dispose();
    _searchTeknisi.dispose();
    _searchSales.dispose();
    _searchClient.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiClient.instance.get('/users/teknisi'),
        ApiClient.instance.get('/users/sales'),
        ApiClient.instance.get('/users/client'),
      ]);
      if (mounted) {
        setState(() {
          _teknisi = results[0].data['data'] ?? [];
          _sales   = results[1].data['data'] ?? [];
          _clients = results[2].data['data'] ?? [];
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Tim'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Tambah anggota',
            onPressed: _showAddUserSheet,
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: [
            Tab(text: 'Teknisi (${_teknisi.length})'),
            Tab(text: 'Sales (${_sales.length})'),
            Tab(text: 'Client (${_clients.length})'),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 2),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildTab(
                  list: _filter(_teknisi, _queryTeknisi),
                  ctrl: _searchTeknisi,
                  hint: 'Cari teknisi...',
                  role: 'teknisi',
                  badgeColor: AppTheme.secondary,
                  badgeBg: AppTheme.secondaryLight,
                  onRefresh: _loadData,
                ),
                _buildTab(
                  list: _filter(_sales, _querySales),
                  ctrl: _searchSales,
                  hint: 'Cari sales...',
                  role: 'sales',
                  badgeColor: AppTheme.primary,
                  badgeBg: AppTheme.primaryLight,
                  onRefresh: _loadData,
                ),
                _buildTab(
                  list: _filter(_clients, _queryClient),
                  ctrl: _searchClient,
                  hint: 'Cari client...',
                  role: 'client',
                  badgeColor: AppTheme.textSecondary,
                  badgeBg: AppTheme.surface,
                  onRefresh: _loadData,
                  showCompany: true,
                ),
              ],
            ),
    );
  }

  Widget _buildTab({
    required List<dynamic> list,
    required TextEditingController ctrl,
    required String hint,
    required String role,
    required Color badgeColor,
    required Color badgeBg,
    required Future<void> Function() onRefresh,
    bool showCompany = false,
  }) {
    return Column(
      children: [
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                  fontSize: 13, color: AppTheme.textTertiary),
              prefixIcon: const Icon(Icons.search,
                  size: 20, color: AppTheme.textTertiary),
              suffixIcon: ctrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close,
                          size: 18, color: AppTheme.textTertiary),
                      onPressed: () => ctrl.clear(),
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
        if (list.isEmpty)
          Expanded(
            child: RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView(
                children: [
                  SizedBox(
                    height: 200,
                    child: Center(
                      child: Text(
                        ctrl.text.isNotEmpty
                            ? 'Tidak ada yang cocok'
                            : 'Belum ada $role terdaftar',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _userCard(
                  list[i],
                  badgeColor: badgeColor,
                  badgeBg: badgeBg,
                  showCompany: showCompany || role == 'sales',
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _userCard(
    dynamic u, {
    required Color badgeColor,
    required Color badgeBg,
    bool showCompany = false,
  }) {
    final name        = u['full_name'] ?? '-';
    final email       = u['email']     ?? '';
    final phone       = u['phone']     ?? '';
    final companyName = u['company_name'] ?? '';
    final role        = u['role']      ?? '';
    final initial     = name.isNotEmpty ? name[0].toUpperCase() : '?';

    final roleLabel = {
      'teknisi': 'Teknisi',
      'sales':   'Sales',
      'client':  'Client',
    }[role] ?? role;

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
            backgroundColor: badgeBg,
            child: Text(initial,
                style: TextStyle(
                    color: badgeColor,
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
                  Row(children: [
                    const Icon(Icons.email_outlined,
                        size: 12, color: AppTheme.textTertiary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(email,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ],
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.phone_outlined,
                        size: 12, color: AppTheme.textTertiary),
                    const SizedBox(width: 4),
                    Text(phone,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary)),
                  ]),
                ],
                if (showCompany && companyName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.business_outlined,
                        size: 12, color: AppTheme.textTertiary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(companyName,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(roleLabel,
                style: TextStyle(
                    fontSize: 10,
                    color: badgeColor,
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
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _role     = 'teknisi';
  bool   _loading  = false;
  bool   _obscure  = true;

  static const _roleOptions = [
    {'key': 'teknisi', 'label': 'Teknisi',
     'desc': 'Ambil & kerjakan job'},
    {'key': 'sales',   'label': 'Sales',
     'desc': 'Buat booking untuk client'},
    {'key': 'client',  'label': 'Client',
     'desc': 'Pemohon servis'},
  ];

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
      final label = _roleOptions
          .firstWhere((r) => r['key'] == _role)['label'];
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Akun $label berhasil dibuat'),
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
    final selectedLabel = _roleOptions
        .firstWhere((r) => r['key'] == _role)['label'];

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

              // Role selector cards
              const Text('Role *',
                  style: TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: _roleOptions.map((opt) {
                  final key      = opt['key']!;
                  final label    = opt['label']!;
                  final desc     = opt['desc']!;
                  final selected = _role == key;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _role = key),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.primaryLight
                              : AppTheme.surface,
                          border: Border.all(
                            color: selected
                                ? AppTheme.primary
                                : AppTheme.border,
                            width: selected ? 1.5 : 0.5,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Text(label,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? AppTheme.primary
                                        : AppTheme.textPrimary)),
                            const SizedBox(height: 2),
                            Text(desc,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 9,
                                    color: selected
                                        ? AppTheme.primary
                                        : AppTheme.textTertiary)),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Nama
              _label('Nama Lengkap *'),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(hintText: 'Nama lengkap'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nama wajib diisi'
                    : null,
              ),
              const SizedBox(height: 12),

              // Email
              _label('Email *'),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    hintText: 'email@domain.com'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
                  if (!v.contains('@')) return 'Format email tidak valid';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Password
              _label('Password *'),
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
                    onPressed: () =>
                        setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => (v == null || v.length < 6)
                    ? 'Password minimal 6 karakter'
                    : null,
              ),
              const SizedBox(height: 12),

              // No HP
              _label('No. HP (opsional)'),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration:
                    const InputDecoration(hintText: '08xxxxxxxxxx'),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('Buat Akun $selectedLabel',
                        style: const TextStyle(fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, color: AppTheme.textSecondary)),
      );
}
