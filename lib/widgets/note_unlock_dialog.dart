import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../services/security_service.dart';

class NoteUnlockDialog extends StatefulWidget {
  const NoteUnlockDialog({super.key});

  @override
  State<NoteUnlockDialog> createState() => _NoteUnlockDialogState();
}

class _NoteUnlockDialogState extends State<NoteUnlockDialog> {
  final TextEditingController _pinController = TextEditingController();

  bool _isLoading = false;
  bool _triedBiometric = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _tryBiometricFirst();
  }

  Future<void> _tryBiometricFirst() async {
    final biometricEnabled = await SecurityService.isBiometricEnabled();
    if (!biometricEnabled || _triedBiometric) return;

    _triedBiometric = true;

    final ok = await SecurityService.authenticateWithBiometric();
    if (!mounted) return;

    if (ok) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _submitPin() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final ok = await SecurityService.verifyPin(_pinController.text.trim());

    if (!mounted) return;

    if (ok) {
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _isLoading = false;
      _errorText = 'PIN salah';
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(context);
    final subColor = AppColors.textSecondary(context);

    return AlertDialog(
      backgroundColor: AppColors.bg2(context),
      title: Text(
        'Catatan Terkunci',
        style: GoogleFonts.poppins(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Masukkan PIN atau gunakan biometrik untuk membuka catatan.',
            style: GoogleFonts.poppins(
              color: subColor,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            style: GoogleFonts.poppins(color: textColor),
            decoration: InputDecoration(
              hintText: 'Masukkan PIN',
              errorText: _errorText,
              counterText: '',
            ),
            onSubmitted: (_) => _submitPin(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Batal',
            style: GoogleFonts.poppins(color: subColor),
          ),
        ),
        TextButton(
          onPressed: _isLoading ? null : _tryBiometricFirst,
          child: Text(
            'Biometrik',
            style: GoogleFonts.poppins(color: AppColors.primary),
          ),
        ),
        TextButton(
          onPressed: _isLoading ? null : _submitPin,
          child: _isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : Text(
                  'Buka',
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