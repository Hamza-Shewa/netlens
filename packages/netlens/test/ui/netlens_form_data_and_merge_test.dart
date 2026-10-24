import 'dart:convert';

import 'package:netlens/core/netlens_adapter.dart';
import 'package:netlens/core/netlens_call_replayer.dart';
import 'package:netlens/core/netlens_core.dart';
import 'package:netlens/helper/netlens_conversion_helper.dart';
import 'package:netlens/helper/netlens_watcher.dart';
import 'package:netlens/model/netlens_configuration.dart';
import 'package:netlens/model/netlens_form_data_file.dart';
import 'package:netlens/model/netlens_from_data_field.dart';
import 'package:netlens/model/netlens_http_call.dart';
import 'package:netlens/model/netlens_replay_request.dart';
import 'package:netlens/ui/common/netlens_navigation.dart';
import 'package:netlens/ui/common/netlens_settings.dart';
import 'package:netlens/ui/mocks/netlens_mock_merge_page.dart';
import 'package:netlens/ui/mocks/netlens_mocks_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../mocks/mock_test_data.dart';

/// Adapter which records replayed requests instead of sending them.
class _FakeReplayer with NetLensAdapter implements NetLensCallReplayer {
  final List<NetLensReplayRequest> requests = [];

  @override
  bool canReplay(NetLensHttpCall call) => true;

  @override
  Future<void> replay(NetLensReplayRequest request) async {
    requests.add(request);
  }
}

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

  NetLensHttpCall uploadCall({bool keepsFile = true}) =>
      finishedCall(method: 'POST', uri: 'https://api.example.com/upload')
        ..request!.body = 'Form data'
        ..request!.headers = {'content-type': 'multipart/form-data; b=1'}
        ..request!.formDataFields = [
          const NetLensFormDataField('title', 'Holiday'),
        ]
        ..request!.formDataFiles = [
          NetLensFormDataFile(
            'photo.png',
            'image/png',
            2048,
            name: 'photo',
            read: keepsFile ? () => Stream.value([1, 2]) : null,
          ),
        ];

  group('replay page with form data', () {
    testWidgets('edits fields and keeps files', (tester) async {
      final _FakeReplayer replayer = _FakeReplayer();
      core.addAdapter(replayer);
      await pumpApp(tester);
      NetLensNavigation.navigateToReplay(call: uploadCall(), core: core);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('netlens_replay_body')), findsNothing);
      expect(find.text('Form fields'), findsOneWidget);
      expect(find.text('photo.png'), findsOneWidget);
      expect(
        find.text('photo · ${NetLensConversionHelper.formatBytes(2048)}'),
        findsOneWidget,
      );
      expect(find.textContaining("didn't keep the content"), findsNothing);

      await tester.enterText(
        find.byKey(const Key('netlens_replay_form_field_value_0')),
        'Trip',
      );
      await tester.tap(find.byKey(const Key('netlens_replay_form_add_field')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('netlens_replay_form_field_name_1')),
        'tag',
      );
      await tester.enterText(
        find.byKey(const Key('netlens_replay_form_field_value_1')),
        'sea',
      );
      await tester.tap(find.byKey(const Key('netlens_replay_send')));
      await tester.pumpAndSettle();

      final NetLensReplayRequest request = replayer.requests.single;
      expect(request.body, isNull);
      expect(request.headers, isEmpty);
      expect(
        request.formDataFields.map((field) => '${field.name}=${field.value}'),
        ['title=Trip', 'tag=sea'],
      );
      expect(request.formDataFiles.single.fileName, 'photo.png');
    });

    testWidgets('warns about and removes files without content', (
      tester,
    ) async {
      final _FakeReplayer replayer = _FakeReplayer();
      core.addAdapter(replayer);
      await pumpApp(tester);
      NetLensNavigation.navigateToReplay(
        call: uploadCall(keepsFile: false),
        core: core,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining("didn't keep the content"), findsOneWidget);
      expect(find.textContaining('Content not kept'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove').last);
      await tester.pumpAndSettle();
      expect(find.textContaining("didn't keep the content"), findsNothing);

      await tester.tap(find.byKey(const Key('netlens_replay_send')));
      await tester.pumpAndSettle();
      expect(replayer.requests.single.formDataFiles, isEmpty);
    });
  });

  group('settings', () {
    testWidgets('turn saving of all requests on', (tester) async {
      await pumpApp(tester);
      showNetLensSettings(navigatorKey.currentContext!, core: core);
      await tester.pumpAndSettle();
      expect(find.text('Save all requests'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('netlens_settings_save_all_calls')),
      );
      await tester.pumpAndSettle();
      expect(core.mocks.saveAllCalls, isTrue);

      core.addCall(finishedCall());
      await tester.pump();
      expect(core.mocks.mocks.single.url.path, '/users');
    });
  });

  group('import', () {
    String collection(String requestBody) => core.mocks.exportCollection(
      mocks: [
        mock(
          method: 'POST',
          url: 'https://api.example.com/orders',
          requestBody: requestBody,
        ),
      ],
    );

    Future<void> openMocks(
      WidgetTester tester,
      List<NetLensImportFile> files,
    ) async {
      await pumpApp(tester);
      navigatorKey.currentState!.push(
        NetLensRoute<void>(
          builder: (_) =>
              NetLensMocksPage(core: core, pickFiles: () async => files),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('netlens_mocks_import')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('From files'));
      await tester.pumpAndSettle();
    }

    testWidgets('merges collections without conflicts at once', (tester) async {
      await core.mocks.replaceAll([mock()]);
      await openMocks(tester, [
        (name: 'a.json', content: collection('{"id":1}')),
        (name: 'broken.json', content: '{}'),
      ]);

      expect(find.byType(NetLensMockMergePage), findsNothing);
      expect(find.textContaining('Mocks after merging: 2'), findsOneWidget);
      expect(
        find.textContaining("broken.json couldn't be read"),
        findsOneWidget,
      );
      expect(core.mocks.mocks, hasLength(2));
    });

    testWidgets('lays out inputs of different types to choose from', (
      tester,
    ) async {
      await openMocks(tester, [
        (name: 'orders-int.json', content: collection('{"id":1}')),
        (name: 'orders-text.json', content: collection('{"id":"1"}')),
      ]);

      expect(find.byType(NetLensMockMergePage), findsOneWidget);
      expect(find.text('Fields are sent as different types'), findsOneWidget);
      expect(find.text('orders-int.json'), findsOneWidget);
      expect(find.text('id: number'), findsOneWidget);
      expect(find.text('id: string'), findsOneWidget);

      await tester.tap(find.byKey(const Key('netlens_mock_merge_option_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('netlens_mock_merge_apply')));
      await tester.pumpAndSettle();

      expect(find.byType(NetLensMockMergePage), findsNothing);
      expect(find.text('Mocks after merging: 1'), findsOneWidget);
      expect(jsonDecode(core.mocks.mocks.single.requestBody!), {'id': '1'});
    });
  });
}
