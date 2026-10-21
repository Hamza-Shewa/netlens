import 'package:netlens/core/netlens_core.dart';
import 'package:netlens/helper/netlens_watcher.dart';
import 'package:netlens/model/netlens_configuration.dart';
import 'package:netlens/model/netlens_http_call.dart';
import 'package:netlens/netlens_mocks.dart';
import 'package:netlens/ui/calls_list/widget/netlens_call_list_item_widget.dart';
import 'package:netlens/ui/common/netlens_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../mocks/mock_test_data.dart';

void main() {
  late NetLensCore core;
  late GlobalKey<NavigatorState> navigatorKey;

  setUp(() {
    NetLensWatcher.instance.reset();
    navigatorKey = GlobalKey<NavigatorState>();
    core = NetLensCore(
      configuration: NetLensConfiguration(
        showNotification: false,
        showInspectorOnShake: false,
        navigatorKey: navigatorKey,
      ),
    );
  });

  tearDown(() => core.dispose());

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox()),
      ),
    );
  }

  group('core', () {
    testWidgets('mocks are off by default', (tester) async {
      expect(core.mocks.mode, NetLensMockMode.off);
      core.addCall(finishedCall());
      await tester.pump();
      expect(core.mocks.mocks, isEmpty);
    });

    testWidgets('records caught calls in record mode', (tester) async {
      core.mocks.mode = NetLensMockMode.record;
      core.addCall(finishedCall());
      await tester.pump();
      expect(core.mocks.mocks.single.url.path, '/users');
    });
  });

  group('mocks page', () {
    testWidgets('opens from the calls list menu', (tester) async {
      await pumpApp(tester);
      NetLensNavigation.navigateToCallsList(core: core);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mocks'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No mocks yet. Switch to Record, or save a call from its '
          'details.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('switches the mode', (tester) async {
      await pumpApp(tester);
      NetLensNavigation.navigateToMocks(core: core);
      await tester.pumpAndSettle();
      expect(
        find.text("Calls go to the network and aren't recorded."),
        findsOneWidget,
      );

      await tester.tap(find.text('Replay'));
      await tester.pumpAndSettle();
      expect(core.mocks.mode, NetLensMockMode.replay);
      expect(
        find.text(
          'Matching calls are answered by mocks instead of the network.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('saves caught calls and lists, turns off and deletes mocks', (
      tester,
    ) async {
      core.addCall(finishedCall());
      core.addCall(
        finishedCall(id: 2, uri: 'https://api.example.com/teams', status: 404),
      );
      await pumpApp(tester);
      NetLensNavigation.navigateToMocks(core: core);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save caught calls'));
      await tester.pumpAndSettle();
      expect(find.text('2 mocks saved'), findsOneWidget);
      expect(find.text('/users?page=1'), findsOneWidget);
      expect(find.text('/teams'), findsOneWidget);
      expect(find.text('404'), findsOneWidget);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(core.mocks.mocks.first.enabled, isFalse);

      await tester.tap(find.byTooltip('Delete mock').first);
      await tester.pumpAndSettle();
      expect(find.text('/users?page=1'), findsNothing);
      expect(core.mocks.mocks.single.url.path, '/teams');
    });
  });

  group('call details', () {
    testWidgets('save the call as a mock', (tester) async {
      core.addCall(finishedCall());
      await pumpApp(tester);
      NetLensNavigation.navigateToCallDetails(
        call: core.getCalls().first,
        core: core,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Save as mock'));
      await tester.pumpAndSettle();
      expect(
        find.text('Saved as mock. Switch mocks to Replay to use it.'),
        findsOneWidget,
      );
      expect(core.mocks.mocks.single.url.path, '/users');
    });

    testWidgets('do not offer to save a call without a response', (
      tester,
    ) async {
      core.addCall(finishedCall(status: -1));
      await pumpApp(tester);
      NetLensNavigation.navigateToCallDetails(
        call: core.getCalls().first,
        core: core,
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Save as mock'), findsNothing);
    });
  });

  group('calls list', () {
    Future<void> pumpItem(WidgetTester tester, NetLensHttpCall call) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: NetLensCallListItemWidget(call, (_) {})),
          ),
        );

    testWidgets('mark calls answered by a mock', (tester) async {
      await pumpItem(
        tester,
        finishedCall(responseHeaders: {'x-netlens-mock': '[abc]'}),
      );
      expect(find.text('Mock'), findsOneWidget);
    });

    testWidgets('mark calls which no mock answered', (tester) async {
      await pumpItem(
        tester,
        finishedCall(
          status: 404,
          responseHeaders: {'X-NetLens-Mock': 'missing'},
        ),
      );
      expect(find.text('No mock'), findsOneWidget);
    });

    testWidgets('do not mark other calls', (tester) async {
      await pumpItem(tester, finishedCall());
      expect(find.text('Mock'), findsNothing);
    });
  });
}
