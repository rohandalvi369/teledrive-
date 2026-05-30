import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/telegram_service.dart';
import '../../theme/app_theme.dart';

class CodePage extends StatefulWidget {
  const CodePage({super.key});

  @override
  State<CodePage> createState() => _CodePageState();
}

class _CodePageState extends State<CodePage> {
  final List<TextEditingController> _controllers = List.generate(5, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(5, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 5; i++) {
      _controllers[i].addListener(() => setState(() {}));
    }
    _focusNodes[0].requestFocus();
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _onDigitChange(int index, String value) {
    if (value.length > 1) {
      final pasted = value.substring(0, 5).split('');
      for (int i = 0; i < pasted.length && i < 5; i++) {
        _controllers[i].text = pasted[i];
      }
      _focusNodes[pasted.length.clamp(0, 4)].requestFocus();
      _trySubmit();
      return;
    }
    if (value.isNotEmpty && index < 4) {
      _focusNodes[index + 1].requestFocus();
    }
    if (index == 4 && value.isNotEmpty) {
      _trySubmit();
    }
  }

  void _onDigitBack(int index) {
    if (index > 0 && _controllers[index].text.isEmpty) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _trySubmit() {
    final code = _controllers.map((c) => c.text).join();
    if (code.length == 5 && !context.read<TelegramService>().loading) {
      context.read<TelegramService>().checkCode(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final telegram = context.watch<TelegramService>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.message_outlined, size: 36, color: AppColors.primary),
                ).animate().fadeIn(duration: 400.ms).scaleY(begin: 0.8, end: 1, curve: Curves.easeOutCubic),
                const SizedBox(height: 24),
                Text('Verification code',
                    style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white))
                  .animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 20, end: 0, curve: Curves.easeOutCubic),
                const SizedBox(height: 8),
                Text('Enter the code sent to your Telegram app',
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary))
                  .animate().fadeIn(duration: 400.ms, delay: 200.ms),
                const SizedBox(height: 32),

                if (telegram.error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withOpacity(0.3)),
                    ),
                    child: Text(telegram.error!,
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.error)),
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: -10, end: 0, curve: Curves.easeOutCubic),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final isFilled = _controllers[index].text.isNotEmpty;
                    final isFocused = _focusNodes[index].hasFocus;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        width: 44, height: 48,
                        decoration: BoxDecoration(
                          color: isFocused
                              ? AppColors.primary.withOpacity(0.15)
                              : isFilled
                                  ? AppColors.primary.withOpacity(0.1)
                                  : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isFocused
                                ? AppColors.primary
                                : isFilled
                                    ? AppColors.primary.withOpacity(0.5)
                                    : AppColors.border,
                            width: isFocused ? 2 : 1,
                          ),
                        ),
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                          decoration: const InputDecoration(
                            counterText: '',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (v) => _onDigitChange(index, v),
                          onEditingComplete: () => _onDigitChange(index, _controllers[index].text),
                        ),
                      ),
                    );
                  }),
                ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 15, end: 0, curve: Curves.easeOutCubic),
                const SizedBox(height: 32),

                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: _controllers.every((c) => c.text.isNotEmpty) && !telegram.loading
                          ? [AppColors.gradientStart, AppColors.gradientEnd]
                          : [AppColors.surfaceElevated, AppColors.surfaceElevated],
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: telegram.loading ? null : _trySubmit,
                      child: Center(
                        child: telegram.loading
                            ? const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Verify', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.verified, color: Colors.white, size: 20),
                                ],
                              ),
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 400.ms).slideY(begin: 15, end: 0, curve: Curves.easeOutCubic),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
