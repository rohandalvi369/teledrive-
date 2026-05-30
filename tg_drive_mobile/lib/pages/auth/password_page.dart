import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/telegram_service.dart';

class PasswordPage extends StatefulWidget {
  const PasswordPage({super.key});

  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  final _passwordController = TextEditingController();
  bool _obscured = true;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final telegram = context.watch<TelegramService>();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline,
                    size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text('Two-factor authentication',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  'Enter your 2FA password',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),

                if (telegram.hint != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.help_outline,
                            size: 16,
                            color: theme.colorScheme.onTertiaryContainer),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text('Hint: ${telegram.hint}',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: theme
                                      .colorScheme.onTertiaryContainer)),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                if (telegram.error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(telegram.error!,
                        style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                            fontSize: 13)),
                  ),

                TextField(
                  controller: _passwordController,
                  obscureText: _obscured,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: '2FA Password',
                    prefixIcon: const Icon(Icons.password),
                    suffixIcon: IconButton(
                      icon: Icon(_obscured
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setState(() => _obscured = !_obscured),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onSubmitted: (_passwordController.text.isNotEmpty && !telegram.loading)
                        ? (v) => telegram.checkPassword(v.trim())
                        : null,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: (_passwordController.text.isNotEmpty &&
                          !telegram.loading)
                      ? () => telegram.checkPassword(
                          _passwordController.text.trim())
                      : null,
                  icon: telegram.loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.login),
                  label: Text(telegram.loading ? 'Signing in...' : 'Sign In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
