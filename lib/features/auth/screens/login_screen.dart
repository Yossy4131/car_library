import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:car_library/features/auth/providers/auth_provider.dart';
import 'package:car_library/features/auth/screens/register_screen.dart';

class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userIdController = useTextEditingController();
    final passwordController = useTextEditingController();
    final loading = useState(false);
    final obscure = useState(true);

    Future<void> login() async {
      final userId = userIdController.text.trim();
      final password = passwordController.text;
      if (userId.isEmpty || password.isEmpty) return;
      loading.value = true;
      final ok = await ref.read(authProvider.notifier).login(userId, password);
      loading.value = false;
      if (ok && context.mounted) {
        Navigator.of(context).pop();
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ユーザーIDまたはパスワードが正しくありません')),
        );
      }
    }

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ロゴ + タイトル
                const Icon(
                  Icons.directions_car,
                  size: 56,
                  color: Color(0xFF162F4E),
                ),
                const SizedBox(height: 8),
                Text(
                  'Car Lovers',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF162F4E),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 32),

                // カード
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'ログイン',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: userIdController,
                          decoration: const InputDecoration(
                            labelText: 'ユーザーID',
                            hintText: 'your_user_id',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: passwordController,
                          obscureText: obscure.value,
                          decoration: InputDecoration(
                            labelText: 'パスワード',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscure.value
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () => obscure.value = !obscure.value,
                            ),
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => login(),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: loading.value ? null : login,
                          child: loading.value
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('ログイン'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                TextButton(
                  onPressed: loading.value
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          );
                        },
                  child: const Text('アカウントをお持ちでない方は新規登録'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
