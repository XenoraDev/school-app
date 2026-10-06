import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:school_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:school_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:school_app/features/auth/presentation/bloc/auth_state.dart';

/// Splash screen displayed on app launch.
///
/// Reads the stored Bearer token from [SecureStorageService] and calls
/// `GET /common/me` to validate the session.
///
/// State routing:
/// - [AuthAuthenticated]  → NavigationShell (handled by GoRouter redirect)
/// - [AuthUnauthenticated] → SchoolSlugScreen / LoginScreen
/// - [AuthAwaitingMfa]   → MfaVerifyScreen (unlikely from splash but safe)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>().add(const AuthAppStarted());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: _onStateChange,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.school_rounded,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator.adaptive(),
              const SizedBox(height: 16),
              Text(
                'Loading…',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onStateChange(BuildContext context, AuthState state) {
    // GoRouter's redirect function listens to AuthBloc and handles routing.
    // Nothing to do here — this listener is a safety net for any
    // state-specific UI side-effects on the splash screen itself.
  }
}

