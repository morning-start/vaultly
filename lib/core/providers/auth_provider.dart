import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../crypto/services/auth_service.dart';
import '../crypto/services/crypto_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final cryptoServiceProvider = Provider<CryptoService>((ref) {
  return CryptoService();
});

final isVaultUnlockedProvider = StateProvider<bool>((ref) => false);

class AuthState {
  final bool isUnlocked;
  final bool isPasswordSet;
  final bool isLoading;
  final String? error;

  AuthState({
    this.isUnlocked = false,
    this.isPasswordSet = false,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isUnlocked,
    bool? isPasswordSet,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isUnlocked: isUnlocked ?? this.isUnlocked,
      isPasswordSet: isPasswordSet ?? this.isPasswordSet,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(AuthState()) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    final isPasswordSet = await _authService.isPasswordSet();
    state = state.copyWith(
      isPasswordSet: isPasswordSet,
      isLoading: false,
    );
  }

  Future<bool> setupPassword(String password) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      await _authService.setupMasterPassword(password);
      state = state.copyWith(
        isPasswordSet: true,
        isUnlocked: true,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> unlock(String password) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final success = await _authService.verifyMasterPassword(password);
      state = state.copyWith(
        isUnlocked: success,
        isLoading: false,
        error: success ? null : '密码错误',
      );
      return success;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void lock() {
    _authService.lock();
    state = state.copyWith(isUnlocked: false);
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});
