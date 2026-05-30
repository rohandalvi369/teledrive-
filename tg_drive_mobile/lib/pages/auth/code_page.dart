import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/telegram_service.dart';

class CodePage extends StatefulWidget {
  const CodePage({super.key});

  @override
  State<CodePage> createState() => _CodePageState();
}

class _CodePageState extends State<CodePage> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _codeController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _codeController.dispose();
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
                Icon(Icons.message_outlined,
                    size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text('Verification code',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  'Enter the code sent to your Telegram app',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 32),

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

                Form(
                  key: _formKey,
                  child: TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'Code',
                      hintText: '12345',
                      prefixIcon: const Icon(Icons.pin),
                      counterText: '',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onSubmitted: (_codeController.text.isNotEmpty && !telegram.loading)
                        ? (v) => telegram.checkCode(v.trim())
                        : null,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: (_codeController.text.isNotEmpty &&
                          !telegram.loading)
                      ? () => telegram.checkCode(_codeController.text.trim())
                      : null,
                  icon: telegram.loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.verified),
                  label: Text(telegram.loading ? 'Verifying...' : 'Verify'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
