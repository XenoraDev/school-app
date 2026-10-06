import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/shared/feedback/error_state_view.dart';

void main() {
  group('ErrorStateView', () {
    testWidgets('renders error message and title correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorStateView(
              title: 'Connection Lost',
              message: 'Unable to reach the server. Please check your network.',
            ),
          ),
        ),
      );

      expect(find.text('Connection Lost'), findsOneWidget);
      expect(
        find.text('Unable to reach the server. Please check your network.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('calls onRetry callback when Retry button is tapped', (tester) async {
      var retryClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorStateView(
              message: 'Failed to load app config.',
              onRetry: () {
                retryClicked = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(retryClicked, isTrue);
    });
  });
}

