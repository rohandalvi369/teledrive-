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
                    color: AppColors.accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_outline, size: 36, color: AppColors.accent),
                ).animate().fadeIn(duration: 400.ms).scaleY(begin: 0.8, end: 1, curve: Curves.easeOutCubic),
                const SizedBox(height: 24),
                Text('Two-factor authentication',
                    style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white))
                  .animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 20, end: 0, curve: Curves.easeOutCubic),
                const SizedBox(height: 8),
                Text('Enter your 2FA password',
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary))
                  .animate().fadeIn(duration: 400.ms, delay: 200.ms),

                if (telegram.hint != null) ...[
                  const SizedBox(height: 12),
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
                ],

                const SizedBox(height: 24),

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

                TextField(
                  controller: _passwordController,
                  focusNode: _focusNode,
                  obscureText: _obscured,
                  textInputAction: TextInputAction.done,
                  style: GoogleFonts.inter(fontSize: 16, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter your 2FA password',
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 16, right: 8),
                      child: Icon(Icons.password, color: AppColors.textSecondary, size: 20),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(_obscured ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.textSecondary, size: 20),
                      onPressed: () => setState(() => _obscured = !_obscured),
                    ),
                  ),
                  onSubmitted: (_passwordController.text.isNotEmpty && !telegram.loading)
                      ? (v) => telegram.checkPassword(v.trim())
                      : null,
                ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 15, end: 0, curve: Curves.easeOutCubic),
                const SizedBox(height: 24),

                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: _passwordController.text.isNotEmpty && !telegram.loading
                          ? [AppColors.gradientStart, AppColors.gradientEnd]
                          : [AppColors.surfaceElevated, AppColors.surfaceElevated],
                    ),
                    boxShadow: _passwordController.text.isNotEmpty && !telegram.loading
                        ? [BoxShadow(color: AppColors.primaryGlow, blurRadius: 24, spreadRadius: 1)]
                        : null,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: (_passwordController.text.isNotEmpty && !telegram.loading)
                          ? () => telegram.checkPassword(_passwordController.text.trim())
                          : null,
                      child: Center(
                        child: telegram.loading
                            ? const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Sign In', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.login, color: Colors.white, size: 20),
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
