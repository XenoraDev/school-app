import 'package:equatable/equatable.dart';
import 'package:school_app/features/auth/domain/entities/account_profile.dart';
import 'package:school_app/features/auth/domain/entities/login_result.dart';
import 'package:school_app/features/auth/domain/entities/mfa_enrollment_info.dart';

/// Base class for all AuthBloc states.
sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// App just launched; storage has not been read yet.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Restoring a session from secure storage (reading token + calling /common/me).
class AuthSessionRestoring extends AuthState {
  const AuthSessionRestoring();
}

/// Generic loading state for any in-progress auth operation.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// No valid session. User must log in.
class AuthUnauthenticated extends AuthState {
  /// Optional message to display (e.g., "Session expired, please log in again").
  final String? message;

  const AuthUnauthenticated({this.message});

  @override
  List<Object?> get props => [message];
}

/// MFA verification required. User holds a pending token.
/// Directs to [MfaVerifyScreen].
class AuthAwaitingMfa extends AuthState {
  final LoginResult pendingResult;
  final String? message;

  const AuthAwaitingMfa({required this.pendingResult, this.message});

  @override
  List<Object?> get props => [pendingResult, message];
}

/// MFA enrollment required before a full session is granted.
/// User holds a pending token. Directs to [MfaEnrollScreen].
class AuthAwaitingMfaEnrollment extends AuthState {
  final LoginResult pendingResult;
  final String? message;

  const AuthAwaitingMfaEnrollment({required this.pendingResult, this.message});

  @override
  List<Object?> get props => [pendingResult, message];
}

class AuthMfaEnrollmentReady extends AuthState {
  final MfaEnrollmentInfo info;
  final String? message;
  const AuthMfaEnrollmentReady({required this.info, this.message});
  @override
  List<Object?> get props => [info, message];
}

class AuthMfaEnrollmentConfirmed extends AuthState {
  final List<String> recoveryCodes;
  final AccountProfile? profile;
  const AuthMfaEnrollmentConfirmed({required this.recoveryCodes, this.profile});
  @override
  List<Object?> get props => [recoveryCodes, profile];
}

/// Fully authenticated. Contains the parsed [AccountProfile].
class AuthAuthenticated extends AuthState {
  final AccountProfile profile;

  const AuthAuthenticated({required this.profile});

  @override
  List<Object?> get props => [profile];
}

/// An auth operation failed with a human-readable [message].
class AuthFailure extends AuthState {
  final String message;

  /// Field-level validation errors (for login form display).
  final Map<String, List<String>>? fieldErrors;

  const AuthFailure({required this.message, this.fieldErrors});

  @override
  List<Object?> get props => [message, fieldErrors];
}
