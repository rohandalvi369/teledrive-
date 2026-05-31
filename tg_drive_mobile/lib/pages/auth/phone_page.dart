import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/telegram_service.dart';
import '../../theme/app_theme.dart';

class PhonePage extends StatefulWidget {
  const PhonePage({super.key});

  @override
  State<PhonePage> createState() => _PhonePageState();
}

class _PhonePageState extends State<PhonePage> {
  final _phoneController = TextEditingController(text: '+91');
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() => setState(() {}));
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit(TelegramService telegram) {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;
    telegram.setPhoneNumber(phone);
  }

  @override
  Widget build(BuildContext context) {
    final telegram = context.watch<TelegramService>();
    final hasNumber = _phoneController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 40),
                Container(
                  width: 100, height: 100,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceElevated,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cloud, size: 48, color: AppColors.primary),
                ).animate().fadeIn(duration: 500.ms).scaleXY(begin: 0.7, end: 1, curve: Curves.easeOutCubic),
                const SizedBox(height: 32),
                Text('TeleDrive',
                    style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w600, color: Colors.white))
                  .animate().fadeIn(duration: 400.ms, delay: 150.ms).slideY(begin: 20, end: 0, curve: Curves.easeOutCubic),
                const SizedBox(height: 8),
                Text('Your Telegram Cloud',
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary))
                  .animate().fadeIn(duration: 400.ms, delay: 250.ms),
                const SizedBox(height: 48),

                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: TextField(
                    controller: _phoneController,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.go,
                    onSubmitted: hasNumber ? (v) => _submit(telegram) : null,
                    style: GoogleFonts.inter(fontSize: 15, color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: '+1 234 567 890',
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(left: 16),
                        child: Icon(Icons.phone_rounded, color: AppColors.textSecondary, size: 20),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 350.ms).slideY(begin: 15, end: 0, curve: Curves.easeOutCubic),

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

                const SizedBox(height: 24),

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
                    boxShadow: hasNumber && !telegram.loading
                        ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))]
                        : null,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: (hasNumber && !telegram.loading) ? () => _submit(telegram) : null,
                      child: Center(
                        child: telegram.loading
                            ? const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : const Text('Continue →',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 450.ms).slideY(begin: 15, end: 0, curve: Curves.easeOutCubic),
                const SizedBox(height: 24),
                Text('By continuing you agree to our Privacy Policy',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary))
                  .animate().fadeIn(duration: 400.ms, delay: 550.ms),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
