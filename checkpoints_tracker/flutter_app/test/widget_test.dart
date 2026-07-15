import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:checkpoints_tracker/app.dart';
import 'package:checkpoints_tracker/providers/auth_provider.dart';
import 'package:checkpoints_tracker/providers/checkpoint_provider.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => CheckpointProvider()),
        ],
        child: const App(),
      ),
    );

    expect(find.text('Guard Tracker'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
