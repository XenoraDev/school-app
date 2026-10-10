import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:school_app/core/errors/failures.dart';
import 'package:school_app/features/auth/domain/repositories/auth_repository.dart';

enum AccountSecurityStatus { idle, submitting, passwordChanged, signedOutEverywhere }

class AccountSecurityState extends Equatable {
  const AccountSecurityState({
    this.status = AccountSecurityStatus.idle,
    this.message,
    this.fieldErrors = const {},
  });

  final AccountSecurityStatus status;

  /// A general, non-field error from the last attempt.
  final String? message;

  /// Server validation messages keyed by request field (for example
  /// `current_password`, `password`).
  final Map<String, List<String>> fieldErrors;

  bool get submitting => status == AccountSecurityStatus.submitting;

  /// A request succeeded: the server revoked the session and the app is about
  /// to leave this screen, so no further action may start.
  bool get completed =>
      status == AccountSecurityStatus.passwordChanged ||
      status == AccountSecurityStatus.signedOutEverywhere;

  @override
  List<Object?> get props => [status, message, fieldErrors];
}

/// Own-account security actions. The server decides everything: this only
/// forwards input, reports the server's answer, and signals success so the app
/// can end the local session (the server revokes every token on both actions).
class AccountSecurityCubit extends Cubit<AccountSecurityState> {
  AccountSecurityCubit(this._repository) : super(const AccountSecurityState());

  final AuthRepository _repository;

  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    if (state.status != AccountSecurityStatus.idle) return;
    emit(const AccountSecurityState(status: AccountSecurityStatus.submitting));
    try {
      await _repository.changePassword(
        currentPassword: currentPassword,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );
      emit(const AccountSecurityState(status: AccountSecurityStatus.passwordChanged));
    } on ValidationFailure catch (f) {
      emit(AccountSecurityState(message: f.message, fieldErrors: f.errors));
    } on Failure catch (f) {
      emit(AccountSecurityState(message: f.message));
    } catch (_) {
      // Never leave the screen stuck in "submitting" on an unexpected error.
      emit(const AccountSecurityState(message: 'Something went wrong. Please try again.'));
    }
  }

  Future<void> signOutEverywhere() async {
    if (state.status != AccountSecurityStatus.idle) return;
    emit(const AccountSecurityState(status: AccountSecurityStatus.submitting));
    try {
      await _repository.logoutAll();
      emit(const AccountSecurityState(status: AccountSecurityStatus.signedOutEverywhere));
    } on Failure catch (f) {
      // The local session is kept: other devices may still be signed in.
      emit(AccountSecurityState(message: f.message));
    } catch (_) {
      // The response could not be read, so the sign-out is unconfirmed.
      emit(const AccountSecurityState(message: 'Could not confirm that all devices were signed out. Please try again.'));
    }
  }
}
