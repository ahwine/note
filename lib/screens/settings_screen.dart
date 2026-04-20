import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../constants/app_colors.dart';
import '../services/security_service.dart';
import 'auth/login_screen.dart';
import 'home_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _hasPin = false;
  bool _biometricEnabled = false;
  bool _canUseBiometric = false;
  bool _securityLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSecurityState();
  }

  Future<void> _loadSecurityState() async {
    final hasPin = await SecurityService.hasPin();
    final biometricEnabled = await SecurityService.isBiometricEnabled();
    final canUseBiometric = await SecurityService.canUseBiometric();

    if (!mounted) return;
    setState(() {
      _hasPin = hasPin;
      _biometricEnabled = biometricEnabled;
      _canUseBiometric = canUseBiometric;
      _securityLoading = false;
    });
  }

  Future<void> _openSetPinDialog({required bool isChanging}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _PinSetupDialog(isChanging: isChanging),
    );

    if (result == true) {
      await _loadSecurityState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isChanging ? 'PIN berhasil diubah' : 'PIN berhasil disimpan',
            style: GoogleFonts.poppins(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openRemovePinDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const _RemovePinDialog(),
    );

    if (result == true) {
      await _loadSecurityState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'PIN berhasil dihapus',
            style: GoogleFonts.poppins(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (!_hasPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Atur PIN terlebih dahulu sebelum mengaktifkan biometrik',
            style: GoogleFonts.poppins(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_canUseBiometric) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Biometrik tidak tersedia di perangkat ini',
            style: GoogleFonts.poppins(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (value) {
      final ok = await SecurityService.authenticateWithBiometric(
        reason: 'Verifikasi untuk mengaktifkan biometrik',
      );

      if (!mounted) return;

      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Verifikasi biometrik gagal',
              style: GoogleFonts.poppins(),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    await SecurityService.setBiometricEnabled(value);
    await _loadSecurityState();
  }

  Future<void> _showChangePasswordDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Password berhasil diubah',
            style: GoogleFonts.poppins(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );

    if (result == true && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Akun berhasil dihapus',
            style: GoogleFonts.poppins(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildAccountInfoCard(AuthProvider auth) {
    final textColor = AppColors.text(context);
    final subColor = AppColors.textSecondary(context);
    final bg2 = AppColors.bg2(context);

    if (!auth.isLoggedIn || auth.user == null) {
      return const SizedBox.shrink();
    }

    final user = auth.user!;
    final name = (user.displayName ?? '').trim();
    final email = (user.email ?? '').trim();
    final photoUrl = (user.photoURL ?? '').trim();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary.withValues(alpha: 0.18),
            backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            child: photoUrl.isEmpty
                ? Text(
                    (name.isNotEmpty ? name[0] : email.isNotEmpty ? email[0] : 'U')
                        .toUpperCase(),
                    style: GoogleFonts.poppins(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 20,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : 'Akun Terdaftar',
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email.isNotEmpty ? email : '-',
                  style: GoogleFonts.poppins(
                    color: subColor,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Akun yang terhubung ke aplikasi ini',
                  style: GoogleFonts.poppins(
                    color: subColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final auth = context.watch<AuthProvider>();
    final textColor = AppColors.text(context);
    final subColor = AppColors.textSecondary(context);
    final bg2 = AppColors.bg2(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pengaturan',
          style: GoogleFonts.poppins(color: textColor),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          if (!auth.isLoggedIn)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    color: AppColors.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Belum login',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'Login untuk menyinkronkan catatan ke cloud',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: subColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      textStyle: GoogleFonts.poppins(fontSize: 13),
                    ),
                    child: const Text('Login'),
                  ),
                ],
              ),
            ),
          if (auth.isLoggedIn) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Akun Terdaftar',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: subColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            _buildAccountInfoCard(auth),
            const SizedBox(height: 16),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Tampilan',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: subColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: bg2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              title: Text(
                'Dark Mode',
                style: GoogleFonts.poppins(color: textColor),
              ),
              subtitle: Text(
                themeProvider.isDark ? 'Mode gelap aktif' : 'Mode terang aktif',
                style: GoogleFonts.poppins(color: subColor, fontSize: 12),
              ),
              value: themeProvider.isDark,
              activeThumbColor: AppColors.primary,
              onChanged: (_) => themeProvider.toggleTheme(),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Keamanan',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: subColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: bg2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _securityLoading
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.pin_outlined, color: textColor),
                        title: Text(
                          _hasPin ? 'Ubah PIN' : 'Atur PIN',
                          style: GoogleFonts.poppins(color: textColor),
                        ),
                        subtitle: Text(
                          _hasPin
                              ? 'PIN sudah aktif'
                              : 'Buat PIN untuk catatan terkunci',
                          style: GoogleFonts.poppins(
                            color: subColor,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Icon(Icons.chevron_right, color: subColor),
                        onTap: () => _openSetPinDialog(isChanging: _hasPin),
                      ),
                      if (_hasPin)
                        Divider(
                          height: 1,
                          color: Theme.of(context).dividerColor,
                        ),
                      if (_hasPin)
                        SwitchListTile(
                          title: Text(
                            'Biometrik',
                            style: GoogleFonts.poppins(color: textColor),
                          ),
                          subtitle: Text(
                            _canUseBiometric
                                ? 'Gunakan sidik jari / biometrik untuk membuka catatan'
                                : 'Biometrik tidak tersedia di perangkat ini',
                            style: GoogleFonts.poppins(
                              color: subColor,
                              fontSize: 12,
                            ),
                          ),
                          value: _biometricEnabled,
                          activeThumbColor: AppColors.primary,
                          onChanged: _canUseBiometric ? _toggleBiometric : null,
                        ),
                      if (_hasPin)
                        Divider(
                          height: 1,
                          color: Theme.of(context).dividerColor,
                        ),
                      if (_hasPin)
                        ListTile(
                          leading: const Icon(Icons.lock_reset, color: Colors.red),
                          title: Text(
                            'Hapus PIN',
                            style: GoogleFonts.poppins(color: Colors.red),
                          ),
                          onTap: _openRemovePinDialog,
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          if (auth.isLoggedIn) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                'Akun',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: subColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: bg2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.lock_outline,
                      color: auth.canChangePassword ? textColor : subColor,
                    ),
                    title: Text(
                      'Ganti Password',
                      style: GoogleFonts.poppins(
                        color: auth.canChangePassword ? textColor : subColor,
                      ),
                    ),
                    subtitle: !auth.canChangePassword
                        ? Text(
                            'Untuk akun Google, ubah password dari akun Google Anda',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: subColor,
                            ),
                          )
                        : null,
                    trailing: Icon(Icons.chevron_right, color: subColor),
                    onTap: auth.canChangePassword
                        ? _showChangePasswordDialog
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Akun Google tidak bisa mengganti password dari aplikasi ini.',
                                  style: GoogleFonts.poppins(),
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                  ),
                  Divider(
                    height: 1,
                    color: Theme.of(context).dividerColor,
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: Text(
                      'Logout',
                      style: GoogleFonts.poppins(color: Colors.red),
                    ),
                    onTap: () async {
                      await context.read<AuthProvider>().signOut();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HomeScreen(),
                          ),
                          (route) => false,
                        );
                      }
                    },
                  ),
                  Divider(
                    height: 1,
                    color: Theme.of(context).dividerColor,
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_forever, color: Colors.red),
                    title: Text(
                      'Hapus Akun',
                      style: GoogleFonts.poppins(color: Colors.red),
                    ),
                    subtitle: auth.isGoogleAccount
                        ? Text(
                            'Pilih ulang akun Google yang terdaftar untuk verifikasi',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondary(context),
                            ),
                          )
                        : null,
                    onTap: _showDeleteAccountDialog,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Notes v1.0.0',
              style: GoogleFonts.poppins(fontSize: 12, color: subColor),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _PinSetupDialog extends StatefulWidget {
  final bool isChanging;

  const _PinSetupDialog({required this.isChanging});

  @override
  State<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<_PinSetupDialog> {
  late final TextEditingController _pinController;
  late final TextEditingController _confirmController;

  String? _errorText;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController();
    _confirmController = TextEditingController();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;

    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();

    if (pin.length < 4 || pin.length > 6) {
      setState(() {
        _errorText = 'PIN harus 4 sampai 6 digit';
      });
      return;
    }

    if (!RegExp(r'^\d+$').hasMatch(pin)) {
      setState(() {
        _errorText = 'PIN hanya boleh angka';
      });
      return;
    }

    if (pin != confirm) {
      setState(() {
        _errorText = 'Konfirmasi PIN tidak cocok';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(const Duration(milliseconds: 120));
    await SecurityService.savePin(pin);

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bg2(context),
      title: Text(
        widget.isChanging ? 'Ubah PIN' : 'Atur PIN',
        style: GoogleFonts.poppins(
          color: AppColors.text(context),
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            decoration: InputDecoration(
              hintText: 'Masukkan PIN (4-6 digit)',
              errorText: _errorText,
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            decoration: const InputDecoration(
              hintText: 'Konfirmasi PIN',
              counterText: '',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: Text(
            'Batal',
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary(context),
            ),
          ),
        ),
        TextButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : Text(
                  'Simpan',
                  style: GoogleFonts.poppins(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }
}

class _RemovePinDialog extends StatefulWidget {
  const _RemovePinDialog();

  @override
  State<_RemovePinDialog> createState() => _RemovePinDialogState();
}

class _RemovePinDialogState extends State<_RemovePinDialog> {
  late final TextEditingController _pinController;

  String? _errorText;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    final ok = await SecurityService.verifyPin(_pinController.text.trim());

    if (!mounted) return;

    if (!ok) {
      setState(() {
        _isSaving = false;
        _errorText = 'PIN salah';
      });
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(const Duration(milliseconds: 120));
    await SecurityService.removePin();

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bg2(context),
      title: Text(
        'Hapus PIN',
        style: GoogleFonts.poppins(
          color: AppColors.text(context),
          fontWeight: FontWeight.w600,
        ),
      ),
      content: TextField(
        controller: _pinController,
        keyboardType: TextInputType.number,
        obscureText: true,
        maxLength: 6,
        decoration: InputDecoration(
          hintText: 'Masukkan PIN saat ini',
          errorText: _errorText,
          counterText: '',
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: Text(
            'Batal',
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary(context),
            ),
          ),
        ),
        TextButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.red,
                  ),
                )
              : Text(
                  'Hapus',
                  style: GoogleFonts.poppins(color: Colors.red),
                ),
        ),
      ],
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;

  String? _errorText;
  bool _isSaving = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;

    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (currentPassword.isEmpty) {
      setState(() {
        _errorText = 'Password lama wajib diisi';
      });
      return;
    }

    if (newPassword.length < 6) {
      setState(() {
        _errorText = 'Password baru minimal 6 karakter';
      });
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() {
        _errorText = 'Konfirmasi password tidak cocok';
      });
      return;
    }

    if (newPassword == currentPassword) {
      setState(() {
        _errorText = 'Password baru harus berbeda dari password lama';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(const Duration(milliseconds: 120));

    if (!mounted) return;

    final ok = await context.read<AuthProvider>().changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );

    if (!mounted) return;

    if (ok) {
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _isSaving = false;
      _errorText =
          context.read<AuthProvider>().errorMessage ?? 'Gagal mengubah password';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bg2(context),
      title: Text(
        'Ganti Password',
        style: GoogleFonts.poppins(
          color: AppColors.text(context),
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _currentPasswordController,
            obscureText: _obscureCurrent,
            decoration: InputDecoration(
              hintText: 'Password lama',
              errorText: _errorText,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureCurrent ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscureCurrent = !_obscureCurrent;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newPasswordController,
            obscureText: _obscureNew,
            decoration: InputDecoration(
              hintText: 'Password baru',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNew ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscureNew = !_obscureNew;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              hintText: 'Konfirmasi password baru',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirm = !_obscureConfirm;
                  });
                },
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: Text(
            'Batal',
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary(context),
            ),
          ),
        ),
        TextButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : Text(
                  'Simpan',
                  style: GoogleFonts.poppins(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  late final TextEditingController _passwordController;

  bool _isDeleting = false;
  bool _obscurePassword = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isDeleting) return;

    final auth = context.read<AuthProvider>();

    if (!auth.isGoogleAccount && _passwordController.text.trim().isEmpty) {
      setState(() {
        _errorText = 'Password wajib diisi';
      });
      return;
    }

    setState(() {
      _isDeleting = true;
      _errorText = null;
    });

    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(const Duration(milliseconds: 120));

    if (!mounted) return;

    final ok = await auth.deleteAccount(
      currentPassword:
          auth.isGoogleAccount ? null : _passwordController.text.trim(),
    );

    if (!mounted) return;

    if (ok) {
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _isDeleting = false;
      _errorText = auth.errorMessage ?? 'Gagal menghapus akun';
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AlertDialog(
      backgroundColor: AppColors.bg2(context),
      title: Text(
        'Hapus Akun',
        style: GoogleFonts.poppins(
          color: AppColors.text(context),
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            auth.isGoogleAccount
                ? 'Akun dan semua data Anda akan dihapus permanen. Setelah menekan hapus, pilih akun Google yang sama dengan akun yang terdaftar di aplikasi ini.'
                : 'Akun dan semua data Anda akan dihapus permanen. Masukkan password untuk konfirmasi.',
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary(context),
              fontSize: 13,
            ),
          ),
          if (!auth.isGoogleAccount) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: 'Password akun',
                errorText: _errorText,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
            ),
          ] else if (_errorText != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _errorText!,
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.pop(context, false),
          child: Text(
            'Batal',
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary(context),
            ),
          ),
        ),
        TextButton(
          onPressed: _isDeleting ? null : _submit,
          child: _isDeleting
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.red,
                  ),
                )
              : Text(
                  'Hapus',
                  style: GoogleFonts.poppins(color: Colors.red),
                ),
        ),
      ],
    );
  }
}