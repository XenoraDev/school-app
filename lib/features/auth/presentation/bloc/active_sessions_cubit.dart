import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:school_app/core/errors/failures.dart';
import 'package:school_app/features/auth/domain/entities/active_token.dart';
import 'package:school_app/features/auth/domain/repositories/auth_repository.dart';

class ActiveSessionsState extends Equatable {
  const ActiveSessionsState({
    this.loading = true,
    this.sessions = const [],
    this.loadError,
    this.revokingId,
    this.message,
  });

  /// The list is being fetched (first load, retry or refresh).
  final bool loading;
  final List<ActiveToken> sessions;

  /// The list could not be loaded; the screen offers a retry.
  final String? loadError;

  /// The token whose revoke request is in flight.
  final int? revokingId;

  /// The outcome of the last revoke, shown once by the screen.
  final String? message;

  bool get saving => revokingId != null;

  @override
  List<Object?> get props => [loading, sessions, loadError, revokingId, message];
}

/// Lists the account's active API tokens and revokes the other ones. The
/// server decides what exists and what may be revoked; the current session is
/// never offered here (sign out and sign out everywhere already cover it).
class ActiveSessionsCubit extends Cubit<ActiveSessionsState> {
  ActiveSessionsCubit(this._repository) : super(const ActiveSessionsState());

  final AuthRepository _repository;

  /// Bumped per list request so a late answer cannot overwrite a newer one.
  int _request = 0;

  Future<void> load() async {
    if (state.saving) return;
    final request = ++_request;
    emit(ActiveSessionsState(loading: true, sessions: state.sessions));
    await _fetch(request);
  }

  Future<void> revoke(ActiveToken session) async {
    if (session.isCurrent || state.saving || state.loading) return;
    emit(
      ActiveSessionsState(
        loading: false,
        sessions: state.sessions,
        revokingId: session.id,
      ),
    );
    String message;
    try {
      await _repository.revokeToken(tokenId: session.id);
      message = 'Session signed out.';
    } on NotFoundFailure {
      message = 'That session no longer exists.';
    } on Failure catch (f) {
      if (isClosed) return;
      emit(
        ActiveSessionsState(
          loading: false,
          sessions: state.sessions,
          message: f.message,
        ),
      );
      return;
    } catch (_) {
      if (isClosed) return;
      emit(
        ActiveSessionsState(
          loading: false,
          sessions: state.sessions,
          message: 'Something went wrong. Please try again.',
        ),
      );
      return;
    }
    if (isClosed) return;
    // Revoked (or already gone): drop the row now, so it stays gone even if the
    // refresh fails, then reload what the server has.
    final request = ++_request;
    emit(
      ActiveSessionsState(
        loading: true,
        sessions: [
          for (final s in state.sessions)
            if (s.id != session.id) s,
        ],
        message: message,
      ),
    );
    await _fetch(request, message: message);
  }

  Future<void> _fetch(int request, {String? message}) async {
    try {
      final sessions = await _repository.listTokens();
      if (isClosed || request != _request) return;
      emit(ActiveSessionsState(loading: false, sessions: sessions, message: message));
    } on Failure catch (f) {
      if (isClosed || request != _request) return;
      emit(
        ActiveSessionsState(
          loading: false,
          sessions: state.sessions,
          loadError: f.message,
          message: message,
        ),
      );
    } catch (_) {
      if (isClosed || request != _request) return;
      emit(
        ActiveSessionsState(
          loading: false,
          sessions: state.sessions,
          loadError: 'Something went wrong. Please try again.',
          message: message,
        ),
      );
    }
  }
}
