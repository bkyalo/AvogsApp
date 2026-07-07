class AuthUser {
  const AuthUser({
    required this.id,
    required this.login,
    required this.name,
    required this.roleId,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as int,
      login: json['login'] as String,
      name: json['name'] as String,
      roleId: json['role_id'] as int,
    );
  }

  final int id;
  final String login;
  final String name;
  final int roleId;
}

class LoginResponse {
  const LoginResponse({
    required this.token,
    required this.user,
    required this.allowedStores,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'] as String,
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      allowedStores: (json['allowed_stores'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );
  }

  final String token;
  final AuthUser user;
  final List<String> allowedStores;
}

enum AuthStatus {
  unknown,
  unauthenticated,
  needsPinSetup,
  locked,
  authenticated,
}

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.allowedStores = const [],
    this.biometricEnabled = false,
    this.errorMessage,
  });

  final AuthStatus status;
  final AuthUser? user;
  final List<String> allowedStores;
  final bool biometricEnabled;
  final String? errorMessage;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    List<String>? allowedStores,
    bool? biometricEnabled,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      allowedStores: allowedStores ?? this.allowedStores,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
