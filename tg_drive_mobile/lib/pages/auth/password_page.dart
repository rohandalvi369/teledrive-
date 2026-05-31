import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/telegram_service.dart';
import '../../theme/app_theme.dart';

class PasswordPage extends StatefulWidget {
  const PasswordPage({super.key});

  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  final _passwordController = TextEditingController();
  final _focusNode = FocusNode();
  bool _obscured = true;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final telegram = context.watch<TelegramService>();
    final hasPassword = _passwordController.text.isNotEmpty;

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
                      child: const Icon(Icons.shield_outlined, size: 44, color: AppColors.accent),
                    ).animate().fadeIn(duration: 500.ms).scaleXY(begin: 0.7, end: 1, curve: Curves.easeOutCubic),
                    const SizedBox(height: 32),
                    Text('Two-step verification',
                        style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w600, color: Colors.white))
                      .animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 20, end: 0, curve: Curves.easeOutCubic),
                    const SizedBox(height: 8),
                    Text('Enter your 2FA password',
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary))
                      .animate().fadeIn(duration: 400.ms, delay: 200.ms),
                    const SizedBox(height: 16),

                    if (telegram.hint != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.help_outline, size: 16, color: AppColors.accent),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text('Hint: ${telegram.hint}',
                                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.accent)),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 300.ms).slideY(begin: -10, end: 0),

                    const SizedBox(height: 24),

                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: TextField(
                        controller: _passwordController,
                        focusNode: _focusNode,
                        obscureText: _obscured,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (hasPassword && !telegram.loading)
                            ? (v) => telegram.checkPassword(v.trim())
                            : null,
                        style: GoogleFonts.inter(fontSize: 15, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Enter your 2FA password',
                          hintStyle: GoogleFonts.inter(fontSize: 15, color: AppColors.textSecondary),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(left: 16),
                            child: Icon(Icons.lock_outline, color: AppColors.textSecondary, size: 20),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscured ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: AppColors.textSecondary, size: 20,
                            ),
                            onPressed: () => setState(() => _obscured = !_obscured),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
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
                        boxShadow: hasPassword && !telegram.loading
                            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))]
                            : null,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: (hasPassword && !telegram.loading)
                              ? () => telegram.checkPassword(_passwordController.text.trim())
                              : null,
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
