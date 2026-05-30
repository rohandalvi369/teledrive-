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
  final _phoneController = TextEditingController();
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
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phone_android, size: 36, color: AppColors.primary),
                ).animate().fadeIn(duration: 400.ms).scaleY(begin: 0.8, end: 1, curve: Curves.easeOutCubic),
                const SizedBox(height: 24),
                Text('Enter your phone number',
                    style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white))
                  .animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 20, end: 0, curve: Curves.easeOutCubic),
                const SizedBox(height: 8),
                Text("You'll receive a verification code in Telegram",
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary))
                  .animate().fadeIn(duration: 400.ms, delay: 200.ms),
                const SizedBox(height: 32),

                if (telegram.error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Text(telegram.error!,
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.error)),
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: -10, end: 0, curve: Curves.easeOutCubic),

                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: _phoneController.text.isNotEmpty
                        ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 20, spreadRadius: 2)]
                        : null,
                  ),
                  child: TextField(
                    controller: _phoneController,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.inter(fontSize: 16, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '+1 234 567 890',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 16, right: 8),
                        child: Text('📞', style: GoogleFonts.inter(fontSize: 20)),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 48),
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 15, end: 0, curve: Curves.easeOutCubic),
                const SizedBox(height: 24),

                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: _phoneController.text.isNotEmpty && !telegram.loading
                          ? [AppColors.gradientStart, AppColors.gradientEnd]
                          : [AppColors.surfaceElevated, AppColors.surfaceElevated],
                    ),
                    boxShadow: _phoneController.text.isNotEmpty && !telegram.loading
                        ? [BoxShadow(color: AppColors.primaryGlow, blurRadius: 24, spreadRadius: 1)]
                        : null,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: (_phoneController.text.isNotEmpty && !telegram.loading)
                          ? () => telegram.setPhoneNumber(_phoneController.text.trim())
                          : null,
                      child: Center(
                        child: telegram.loading
                            ? const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Continue', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
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
