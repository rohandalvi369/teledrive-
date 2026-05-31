import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/telegram_service.dart';

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
    if (code.length == 5 && !context.read<TelegramService>().loading) {
      context.read<TelegramService>().checkCode(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final telegram = context.watch<TelegramService>();
    final allFilled = _controllers.every((c) => c.text.isNotEmpty);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
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
                        color: Color(0xFF1A1A2E),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.message_outlined, size: 44, color: Color(0xFF2AABEE)),
                    ).animate().fadeIn(duration: 500.ms).scaleXY(begin: 0.7, end: 1, curve: Curves.easeOutCubic),
                    const SizedBox(height: 32),
                    Text('Enter verification code',
                        style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w600, color: Colors.white))
                      .animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 20, end: 0, curve: Curves.easeOutCubic),
                    const SizedBox(height: 8),
                    Text('Sent to +91 XXXXXXXXXX',
                        style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF8B8FA8)))
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
                            color: const Color(0xFF1A1A2E),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isFocused
                                  ? const Color(0xFF2AABEE)
                                  : const Color(0xFF2A2A3E),
                              width: isFocused ? 1.5 : 1.5,
                            ),
                            boxShadow: isFocused
                                ? [BoxShadow(color: const Color(0xFF2AABEE).withValues(alpha: 0.25), blurRadius: 12)]
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
                    const SizedBox(height: 32),

                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2AABEE), Color(0xFF7B61FF)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        boxShadow: allFilled && !telegram.loading
                            ? [BoxShadow(color: const Color(0xFF2AABEE).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))]
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
                                : Text('Verify →',
                                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                          ),
                        ),
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 400.ms).slideY(begin: 15, end: 0, curve: Curves.easeOutCubic),
                    const SizedBox(height: 24),

                    GestureDetector(
                      onTap: () {
                        final telegram = context.read<TelegramService>();
                        telegram.setPhoneNumber('');
                      },
                      child: Text('Resend code',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF8B8FA8))),
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
                icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF8B8FA8), size: 24),
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
