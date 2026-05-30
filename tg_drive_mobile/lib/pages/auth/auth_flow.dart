import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/telegram_service.dart';
import '../../theme/app_theme.dart';
import 'phone_page.dart';
import 'code_page.dart';
import 'password_page.dart';

class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key});

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final telegram = context.read<TelegramService>();
      if (telegram.currentStep == AuthStep.initializing) {
        telegram.initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final telegram = context.watch<TelegramService>();

    if (telegram.currentStep == AuthStep.initializing) {
      return _buildLoading(context, telegram);
    }

    switch (telegram.currentStep) {
      case AuthStep.phone:
        return const PhonePage();
      case AuthStep.code:
        return const CodePage();
      case AuthStep.password:
        return const PasswordPage();
      case AuthStep.ready:
        return const SizedBox.shrink();
      case AuthStep.closed:
        return _buildReconnect(context);
      default:
        return _buildLoading(context, telegram);
    }
  }

  Widget _buildLoading(BuildContext context, TelegramService telegram) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: AppColors.primaryGlow, blurRadius: 40, spreadRadius: 5),
                ],
              ),
              child: const Icon(Icons.cloud, size: 48, color: AppColors.primary),
            ).animate().shake(duration: 2000.ms).then().shimmer(duration: 2000.ms, color: AppColors.primary.withOpacity(0.1)),
            const SizedBox(height: 24),
            Text('TeleDrive',
                style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 8),
            Text('Your Telegram Cloud',
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 40),
            const SizedBox(width: 28, height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary)),
            const SizedBox(height: 16),
            Text('Initializing...',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
            if (telegram.error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Text(
                  telegram.error!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.error),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReconnect(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off, size: 48, color: AppColors.error),
            ),
            const SizedBox(height: 24),
            Text('Disconnected',
                style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 16),
            Container(
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.read<TelegramService>().initialize(),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text('Reconnect', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.primary)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
