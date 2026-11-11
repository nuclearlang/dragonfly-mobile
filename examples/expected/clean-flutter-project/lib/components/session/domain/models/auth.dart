import 'package:flutter/foundation.dart' hide Page;
import 'package:json_annotation/json_annotation.dart';

part 'auth.g.dart';

/// What the backend returns on sign-in; it is stored as the session data (session.start).
@JsonSerializable(explicitToJson: true)
class Auth {
  const Auth({required this.userId, required this.name, required this.token, required this.roles, this.plan = Plan.free});

  factory Auth.fromJson(Map<String, dynamic> json) => _$AuthFromJson(json);

  final String userId;
  final String name;
  final String token;
  final List<String> roles;
  final Plan plan;

  Map<String, dynamic> toJson() => _$AuthToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Auth &&
          userId == other.userId &&
          name == other.name &&
          token == other.token &&
          listEquals(roles, other.roles) &&
          plan == other.plan;

  @override
  int get hashCode => Object.hashAll([userId, name, token, Object.hashAll(roles), plan]);
}

@JsonSerializable(explicitToJson: true)
class LoginParams {
  const LoginParams({required this.user, required this.pass});

  factory LoginParams.fromJson(Map<String, dynamic> json) => _$LoginParamsFromJson(json);

  final String user;
  final String pass;

  Map<String, dynamic> toJson() => _$LoginParamsToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoginParams &&
          user == other.user &&
          pass == other.pass;

  @override
  int get hashCode => Object.hashAll([user, pass]);
}

@JsonSerializable(explicitToJson: true)
class AuthError {
  const AuthError({required this.message});

  factory AuthError.fromJson(Map<String, dynamic> json) => _$AuthErrorFromJson(json);

  final String message;

  Map<String, dynamic> toJson() => _$AuthErrorToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthError &&
          message == other.message;

  @override
  int get hashCode => Object.hashAll([message]);
}

/// What the user pays for; the backend does not send it yet, so it starts free.
enum Plan {
  free,
  premium
}
