import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:car_library/features/auth/providers/auth_provider.dart';
import 'package:car_library/shared/services/api_service.dart';

class RegisterScreen extends HookConsumerWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userIdController = useTextEditingController();
    final passwordController = useTextEditingController();
    final confirmController = useTextEditingController();
    final loading = useState(false);
    final obscurePassword = useState(true);
    final obscureConfirm = useState(true);

    Future<void> register() async {
      final userId = userIdController.text.trim();
      final password = passwordController.text;
      final confirm = confirmController.text;

      if (userId.isEmpty || password.isEmpty || confirm.isEmpty) return;

      if (password != confirm) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('パスワードが一致しません')));
        return;
      }

      loading.value = true;
      try {
        final ok = await ref
            .read(authProvider.notifier)
            .register(userId, password);
        if (ok && context.mounted) {
          // ログイン画面も含めてポップして一覧に戻る
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } on ApiException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('登録に失敗しました。もう一度お試しください。')),
          );
        }
      } finally {
        loading.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('新規登録')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: userIdController,
              decoration: const InputDecoration(
                labelText: 'ユーザーID',
                hintText: 'yossy_123',
                helperText: '3〜30文字、英数字・ハイフン・アンダースコア',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: obscurePassword.value,
              decoration: InputDecoration(
                labelText: 'パスワード',
                helperText: '8文字以上',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword.value
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () =>
                      obscurePassword.value = !obscurePassword.value,
                ),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmController,
              obscureText: obscureConfirm.value,
              decoration: InputDecoration(
                labelText: 'パスワード（確認）',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureConfirm.value
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () => obscureConfirm.value = !obscureConfirm.value,
                ),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => register(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: loading.value ? null : register,
              child: loading.value
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('登録してログイン'),
            ),
          ],
        ),
      ),
    );
  }
}
