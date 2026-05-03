import 'package:driver_app/shared/models/driver_profile.dart';

class AuthState {
  const AuthState({
    required this.isLoading,
    required this.hasBootstrapped,
    required this.token,
    required this.driver,
    required this.errorMessage,
  });

  const AuthState.initial()
    : isLoading = false,
      hasBootstrapped = false,
      token = null,
      driver = null,
      errorMessage = null;

  final bool isLoading;
  final bool hasBootstrapped;
  final String? token;
  final DriverProfile? driver;
  final String? errorMessage;

  bool get isAuthenticated => token != null && driver != null;

  AuthState copyWith({
    bool? isLoading,
    bool? hasBootstrapped,
    String? token,
    DriverProfile? driver,
    String? errorMessage,
    bool clearError = false,
    bool clearDriver = false,
    bool clearToken = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      hasBootstrapped: hasBootstrapped ?? this.hasBootstrapped,
      token: clearToken ? null : (token ?? this.token),
      driver: clearDriver ? null : (driver ?? this.driver),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
