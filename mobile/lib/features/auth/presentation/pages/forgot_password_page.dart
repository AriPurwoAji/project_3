import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailCtrl    = TextEditingController();
  final _otpCtrl      = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  bool _loading       = false;
  bool _otpSent       = false;  // true = masuk step 2
  bool _showPass      = false;
  bool _showConfirm   = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Step 1: kirim OTP ke email ──────────────────────────────────────────

  Future<void> _sendOTP() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _snack('Masukkan email yang valid', isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      await ApiClient.instance.post('/auth/forgot-password',
          data: {'email': email});
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _loading = false;
      });
      _snack('Kode OTP dikirim ke $email');
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      final msg = e.response?.data['message'] ?? 'Gagal mengirim OTP';
      _snack(msg, isError: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Terjadi kesalahan, coba lagi', isError: true);
    }
  }

  // ── Step 2: reset password dengan OTP ───────────────────────────────────

  Future<void> _resetPassword() async {
    final otp  = _otpCtrl.text.trim();
    final pass = _passCtrl.text;
    final conf = _confirmCtrl.text;

    if (otp.length != 6) {
      _snack('Kode OTP harus 6 digit', isError: true);
      return;
    }
    if (pass.length < 6) {
      _snack('Password minimal 6 karakter', isError: true);
      return;
    }
    if (pass != conf) {
      _snack('Konfirmasi password tidak cocok', isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      await ApiClient.instance.post('/auth/reset-password', data: {
        'email':        _emailCtrl.text.trim(),
        'token':        otp,
        'new_password': pass,
      });
      if (!mounted) return;
      _snack('Password berhasil direset! Silakan login.');
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      String msg = 'Gagal reset password';
      if (e is DioException) {
        msg = e.response?.data['message'] ?? msg;
      }
      _snack(msg, isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppTheme.danger : AppTheme.secondary,
    ));
  }

  // ── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.lock_reset_outlined,
                    size: 28, color: AppTheme.primary),
              ),
              const SizedBox(height: 20),

              // Judul & sub
              Text(
                _otpSent ? 'Masukkan Kode OTP' : 'Lupa Password',
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _otpSent
                    ? 'Kami sudah kirim kode 6 digit ke ${_emailCtrl.text.trim()}. Masukkan kode dan password baru kamu.'
                    : 'Masukkan email yang terdaftar. Kami akan kirim kode OTP untuk reset password.',
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 32),

              if (!_otpSent) _buildStep1() else _buildStep2(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Email',
            style: TextStyle(
                fontSize: 13, color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'\s')),
          ],
          decoration: const InputDecoration(
            hintText: 'nama@perusahaan.com',
            prefixIcon: Icon(Icons.email_outlined, size: 20),
          ),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: _loading ? null : _sendOTP,
          child: _loading
              ? const SizedBox(
                  height: 20, width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Kirim Kode OTP',
                  style: TextStyle(fontSize: 15)),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => context.go('/login'),
          child: const Text('Kembali ke Login'),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kode OTP
        const Text('Kode OTP (6 digit)',
            style: TextStyle(
                fontSize: 13, color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.w700,
              letterSpacing: 8),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            hintText: '000000',
            counterText: '',
            contentPadding:
                EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 16),

        // Password baru
        const Text('Password Baru',
            style: TextStyle(
                fontSize: 13, color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: _passCtrl,
          obscureText: !_showPass,
          decoration: InputDecoration(
            hintText: 'Minimal 6 karakter',
            prefixIcon: const Icon(Icons.lock_outline, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _showPass
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20, color: AppTheme.textTertiary,
              ),
              onPressed: () => setState(() => _showPass = !_showPass),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Konfirmasi password
        const Text('Konfirmasi Password',
            style: TextStyle(
                fontSize: 13, color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: _confirmCtrl,
          obscureText: !_showConfirm,
          decoration: InputDecoration(
            hintText: 'Ulangi password baru',
            prefixIcon: const Icon(Icons.lock_outline, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _showConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20, color: AppTheme.textTertiary,
              ),
              onPressed: () => setState(() => _showConfirm = !_showConfirm),
            ),
          ),
        ),
        const SizedBox(height: 28),

        ElevatedButton(
          onPressed: _loading ? null : _resetPassword,
          child: _loading
              ? const SizedBox(
                  height: 20, width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Reset Password',
                  style: TextStyle(fontSize: 15)),
        ),
        const SizedBox(height: 16),

        // Kirim ulang
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Tidak menerima kode?',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
            TextButton(
              onPressed: _loading ? null : () {
                setState(() => _otpSent = false);
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Kirim ulang',
                  style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ],
    );
  }
}
