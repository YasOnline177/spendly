import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_provider.dart';
import '../application/app_lock_provider.dart';

/// Sits above the whole app (above every screen) and covers it with a lock
/// screen whenever the app is locked.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool _wasActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get _signedIn {
    final user = ref.read(authStateProvider).value;
    return user != null && user.emailVerified;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(appLockProvider.notifier);
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        controller.onBackgrounded(DateTime.now());
      case AppLifecycleState.resumed:
        controller.onResumed(DateTime.now(), signedIn: _signedIn);
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Nothing to protect when nobody verified is signed in.
    ref.listen(authStateProvider, (_, next) {
      final user = next.value;
      if (next.hasValue && (user == null || !user.emailVerified)) {
        ref.read(appLockProvider.notifier).clearLock();
      }
    });

    final lock = ref.watch(appLockProvider);
    final auth = ref.watch(authStateProvider);
    final signedIn = auth.value != null && auth.value!.emailVerified;

    return lock.when(
      // Hide the app until we know whether it is locked.
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      // Never trap the user if the setting cannot be read.
      error: (e, st) => widget.child,
      data: (state) {
        final active = state.locked && signedIn;

        // Ask for the fingerprint as soon as the lock engages.
        if (active && !_wasActive) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) ref.read(appLockProvider.notifier).unlock();
          });
        }
        _wasActive = active;

        return Stack(
          fit: StackFit.expand,
          children: [
            Offstage(offstage: active, child: widget.child),
            if (active) const LockScreen(),
          ],
        );
      },
    );
  }
}

class LockScreen extends ConsumerWidget {
  const LockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final controller = ref.read(appLockProvider.notifier);
    final unavailable = ref.watch(appLockProvider).value?.unavailable ?? false;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 72, color: scheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Spendly is locked',
                  style: textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  unavailable
                      ? 'This phone has no screen lock set up, so Spendly cannot verify you.'
                      : "Verify it's you to continue.",
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(color: scheme.outline),
                ),
                const SizedBox(height: 24),
                if (unavailable)
                  FilledButton(
                    onPressed: () => controller.disable(),
                    child: const Text('Turn off app lock'),
                  )
                else
                  FilledButton.icon(
                    onPressed: () => controller.unlock(),
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Unlock'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 