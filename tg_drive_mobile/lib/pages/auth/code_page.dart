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
  final List<TextEditingController> _controllers =
      List.generate(5, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(5, (_) => FocusNode());

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
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
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

  void _trySubmit() {
    final code = _controllers.map((c) => c.text).join();
    if (code.length == 5) {
      context.read<TelegramService>().checkCode(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final telegram = context.watch<TelegramService>();
    final allFilled = _controllers.every((c) => c.text.isNotEmpty);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 100, height: 100,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceElevated,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.message_outlined, size: 44, color: AppColors.primary),
                    ).animate().fadeIn(duration: 500.ms).scaleXY(begin: 0.7, end: 1, curve: Curves.easeOutCubic),
                    const SizedBox(height: 32),
                    Text('Enter verification code',
                        style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w600, color: Colors.white))
                      .animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 20, end: 0, curve: Curves.easeOutCubic),
                    const SizedBox(height: 8),
                    Text('Enter the 5-digit code from Telegram',
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary))
                      .animate().fadeIn(duration: 400.ms, delay: 200.ms),
                    const SizedBox(height: 48),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(5, (index) {
                        final isFocused = _focusNodes[index].hasFocus;
                        return Container(
                          width: 52,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isFocused ? AppColors.primary : AppColors.border,
                              width: 1.5,
                            ),
                            boxShadow: isFocused
                                ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 12)]
                                : null,
                          ),
                          child: TextField(
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white),
                            decoration: const InputDecoration(
                              counterText: '',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (v) => _onDigitChange(index, v),
                          ),
                        );
                      }),
                    ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 15, end: 0, curve: Curves.easeOutCubic),

                    if (telegram.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                          ),
                          child: Text(telegram.error!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 13, color: AppColors.error)),
                        ),
                      ),

                    const SizedBox(height: 32),

                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [AppColors.gradientStart, AppColors.gradientEnd],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        boxShadow: allFilled && !telegram.loading
                            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))]
                            : null,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: allFilled && !telegram.loading ? _trySubmit : null,
                          child: Center(
                            child: telegram.loading
                                ? const SizedBox(width: 22, height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                : const Text('Verify →',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                          ),
                        ),
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 400.ms).slideY(begin: 15, end: 0, curve: Curves.easeOutCubic),
                    const SizedBox(height: 24),

                    GestureDetector(
                      onTap: () {
                        context.read<TelegramService>().resendCode();
                      },
                      child: Text('Resend code',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                    ).animate().fadeIn(duration: 400.ms, delay: 500.ms),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textSecondary, size: 24),
                onPressed: () => context.read<TelegramService>().goBack(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
