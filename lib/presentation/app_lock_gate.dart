import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../core/storage/app_lock_store.dart';
import '../features/settings/settings_controller.dart';

class AppLockGate extends ConsumerStatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  final _passwordController = TextEditingController();
  final _localAuth = LocalAuthentication();
  bool _locked = false;
  bool _authenticating = false;
  bool _hasBiometrics = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locked = ref.read(settingsProvider).appLockEnabled;
    if (_locked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
    _loadBiometricSupport();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!ref.read(settingsProvider).appLockEnabled) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (!_locked) setState(() => _locked = true);
      _error = null;
    } else if (state == AppLifecycleState.resumed && _locked) {
      _tryBiometric();
    }
  }

  Future<void> _loadBiometricSupport() async {
    try {
      final available = await _localAuth.getAvailableBiometrics();
      if (mounted) {
        setState(() => _hasBiometrics = available.isNotEmpty);
        if (available.isNotEmpty && _locked) _tryBiometric();
      }
    } catch (_) {
      if (mounted) setState(() => _hasBiometrics = false);
    }
  }

  Future<void> _tryBiometric() async {
    if (!mounted || _authenticating || !_locked || !_hasBiometrics) return;
    setState(() {
      _authenticating = true;
      _error = null;
    });
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock STEGSHARE',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (authenticated) {
        _unlock();
      } else if (mounted) {
        setState(() => _error =
            'Biometric authentication was not successful. Enter your password.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Biometric authentication is unavailable. Enter your password.');
      }
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  Future<void> _submitPassword() async {
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _error = null;
    });
    try {
      final correct = await ref
          .read(appLockStoreProvider)
          .verifyPassword(_passwordController.text);
      if (correct) {
        _passwordController.clear();
        _unlock();
      } else if (mounted) {
        _passwordController.clear();
        setState(() => _error = 'Incorrect password.');
      }
    } catch (_) {
      if (mounted) {
        _passwordController.clear();
        setState(() => _error = 'Could not verify the app-lock password.');
      }
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  void _unlock() {
    if (!mounted) return;
    _passwordController.clear();
    setState(() {
      _locked = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SettingsState>(settingsProvider, (previous, next) {
      if (previous?.appLockEnabled == next.appLockEnabled) return;
      if (!next.appLockEnabled) {
        setState(() {
          _locked = false;
          _error = null;
        });
      } else {
        setState(() => _locked = true);
        _tryBiometric();
      }
    });

    if (!_locked) return widget.child;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.lock_outline,
                      size: 48, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('Unlock STEGSHARE',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    enabled: !_authenticating,
                    onSubmitted: (_) => _submitPassword(),
                    decoration:
                        const InputDecoration(labelText: 'App password'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _authenticating ? null : _submitPassword,
                    child: const Text('Unlock with password'),
                  ),
                  if (_hasBiometrics) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _authenticating ? null : _tryBiometric,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Use biometrics'),
                    ),
                  ],
                  if (_authenticating)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.error)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
