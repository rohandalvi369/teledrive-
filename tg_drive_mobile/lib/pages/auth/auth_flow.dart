import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/telegram_service.dart';
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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_outlined, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 24),
            Text('TeleDrive',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Initializing...',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            if (telegram.error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  telegram.error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReconnect(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 24),
            Text('Disconnected', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () {
                context.read<TelegramService>().initialize();
              },
              child: const Text('Reconnect'),
            ),
          ],
        ),
      ),
    );
  }
}
