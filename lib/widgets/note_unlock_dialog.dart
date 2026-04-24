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
  final _pinController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _tryBiometricFirst();
  }

  Future<void> _tryBiometricFirst() async {
    final enabled = await SecurityService.isBiometricEnabled();
    if (!enabled || !mounted) return;

    final ok = await SecurityService.authenticateWithBiometric(
      reason: 'Buka catatan terkunci',
    );
    if (!mounted) return;
    if (ok) Navigator.of(context).pop(true);
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final ok = await SecurityService.verifyPin(_pinController.text.trim());

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isLoading = false;
      _errorText = 'PIN tidak sesuai';
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = AppColors.text(context);
    final sub = AppColors.textSecondary(context);

    return AlertDialog(
      title: Text(
        'Buka folder terkunci',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 72,
            width: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_open_rounded,
              color: AppColors.primaryDark,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Masukkan PIN untuk mengakses catatan terkunci.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: sub),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            obscureText: _obscure,
            maxLength: 6,
            decoration: InputDecoration(
              counterText: '',
              hintText: 'PIN',
              errorText: _errorText,
              prefixIcon: const Icon(Icons.pin_outlined),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: Text(
            'Batal',
            style: GoogleFonts.poppins(color: sub),
          ),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Buka'),
        ),
      ],
    );
  }
}
