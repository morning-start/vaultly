import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_service.dart';
import '../data/crypto_service.dart';
import '../data/biometric_service.dart';
import '../domain/auth_notifier.dart';
import '../domain/auth_state.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  final biometricService = ref.watch(biometricServiceProvider);
  return AuthService(biometricService: biometricService);
});

final cryptoServiceProvider = Provider<CryptoService>((ref) {
  return CryptoService();
});

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

final isVaultUnlockedProvider = StateProvider<bool>((ref) => false);

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  final biometricService = ref.watch(biometricServiceProvider);
  return AuthNotifier(authService, biometricService);
});
