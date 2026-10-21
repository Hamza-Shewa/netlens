// ignore_for_file: use_build_context_synchronously

import 'package:netlens/core/netlens_core.dart';
import 'package:netlens/helper/netlens_export_helper.dart';
import 'package:netlens/mock/application/netlens_mocks.dart';
import 'package:netlens/mock/domain/netlens_mock.dart';
import 'package:netlens/mock/domain/netlens_mock_mode.dart';
import 'package:netlens/model/netlens_export_result.dart';
import 'package:netlens/model/netlens_translation.dart';
import 'package:netlens/ui/common/netlens_app_bar.dart';
import 'package:netlens/ui/common/netlens_call_badges.dart';
import 'package:netlens/ui/common/netlens_context_ext.dart';
import 'package:netlens/ui/common/netlens_detail_widgets.dart';
import 'package:netlens/ui/common/netlens_dialog.dart';
import 'package:netlens/ui/common/netlens_page.dart';
import 'package:netlens/ui/common/netlens_scroll_behavior.dart';
import 'package:netlens/ui/common/netlens_settings.dart';
import 'package:netlens/ui/common/netlens_theme.dart';
import 'package:flutter/material.dart';

/// Page where calls are recorded as mock endpoints and replayed, so the app can
/// run offline.
class NetLensMocksPage extends StatefulWidget {
  const NetLensMocksPage({super.key, required this.core});

  final NetLensCore core;

  @override
  State<NetLensMocksPage> createState() => _NetLensMocksPageState();
}

class _NetLensMocksPageState extends State<NetLensMocksPage>
    with NetLensSettingsListenerMixin {
  NetLensMocks get _mocks => widget.core.mocks;

  @override
  Widget build(BuildContext context) {
    return NetLensPage(
      core: widget.core,
      child: StreamBuilder<NetLensMockMode>(
        stream: _mocks.modeStream,
        initialData: _mocks.mode,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<NetLensMockMode> modeSnapshot,
            ) => StreamBuilder<List<NetLensMock>>(
              stream: _mocks.mocksStream,
              initialData: _mocks.mocks,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<NetLensMock>> mocksSnapshot,
                  ) => _buildPage(
                    context,
                    mode: modeSnapshot.data ?? _mocks.mode,
                    mocks: mocksSnapshot.data ?? const [],
                  ),
            ),
      ),
    );
  }

  Widget _buildPage(
    BuildContext context, {
    required NetLensMockMode mode,
    required List<NetLensMock> mocks,
  }) {
    return Scaffold(
      appBar: NetLensAppBar(
        title: Text(context.i18n(NetLensTranslationKey.mocks)),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: context.i18n(NetLensTranslationKey.mocksExport),
            onPressed: mocks.isEmpty ? null : () => _export(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: context.i18n(NetLensTranslationKey.mocksDeleteAll),
            onPressed: mocks.isEmpty ? null : () => _confirmClear(context),
          ),
        ],
      ),
      body: ScrollConfiguration(
        behavior: NetLensScrollBehavior(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _ModeCard(
              mode: mode,
              onChanged: (NetLensMockMode mode) => _mocks.mode = mode,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.playlist_add),
                label: Text(
                  context.i18n(NetLensTranslationKey.mocksRecordCalls),
                ),
                onPressed: () => _recordCalls(context),
              ),
            ),
            const SizedBox(height: 12),
            if (mocks.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    context.i18n(NetLensTranslationKey.mocksEmpty),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            for (final NetLensMock mock in mocks)
              _MockTile(
                key: ValueKey<String>(mock.id),
                mock: mock,
                onEnabledChanged: (bool enabled) =>
                    _mocks.setEnabled(mock.id, enabled: enabled),
                onDelete: () => _mocks.remove(mock.id),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _recordCalls(BuildContext context) async {
    final List<NetLensMock> saved = await _mocks.recordAll(
      widget.core.getCalls(),
    );
    if (!mounted) {
      return;
    }
    _showMessage(
      context,
      context
          .i18n(NetLensTranslationKey.mocksRecorded)
          .replaceAll('[count]', '${saved.length}'),
    );
  }

  Future<void> _export(BuildContext context) async {
    final NetLensExportResult result =
        await NetLensExportHelper.saveMocksToFile(_mocks.export());
    if (!mounted || result.success) {
      return;
    }
    _showMessage(
      context,
      context.i18n(NetLensTranslationKey.mocksExportFailed),
    );
  }

  Future<void> _confirmClear(BuildContext context) {
    return NetLensGeneralDialog.show(
      context: context,
      title: context.i18n(NetLensTranslationKey.mocksDeleteAll),
      description: context.i18n(NetLensTranslationKey.mocksDeleteAllConfirm),
      firstButtonTitle: context.i18n(NetLensTranslationKey.callsListNo),
      secondButtonTitle: context.i18n(NetLensTranslationKey.callsListYes),
      secondButtonAction: _mocks.clear,
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }
}

/// Card which explains mocks and switches between the modes.
class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.mode, required this.onChanged});

  final NetLensMockMode mode;
  final ValueChanged<NetLensMockMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return NetLensOutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.dns_outlined,
                color: theme.colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.i18n(NetLensTranslationKey.mocksDescription),
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<NetLensMockMode>(
              showSelectedIcon: false,
              segments: [
                for (final NetLensMockMode option in NetLensMockMode.values)
                  ButtonSegment<NetLensMockMode>(
                    value: option,
                    icon: Icon(_getIcon(option)),
                    label: Text(context.i18n(_getTitle(option))),
                  ),
              ],
              selected: {mode},
              onSelectionChanged: (Set<NetLensMockMode> selected) =>
                  onChanged(selected.first),
            ),
          ),
          const SizedBox(height: 8),
          Text(context.i18n(_getHint(mode)), style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  static IconData _getIcon(NetLensMockMode mode) => switch (mode) {
    NetLensMockMode.off => Icons.cloud_outlined,
    NetLensMockMode.record => Icons.fiber_manual_record_outlined,
    NetLensMockMode.replay => Icons.play_arrow_outlined,
  };

  static NetLensTranslationKey _getTitle(NetLensMockMode mode) =>
      switch (mode) {
        NetLensMockMode.off => NetLensTranslationKey.mocksModeOff,
        NetLensMockMode.record => NetLensTranslationKey.mocksModeRecord,
        NetLensMockMode.replay => NetLensTranslationKey.mocksModeReplay,
      };

  static NetLensTranslationKey _getHint(NetLensMockMode mode) => switch (mode) {
    NetLensMockMode.off => NetLensTranslationKey.mocksModeOffHint,
    NetLensMockMode.record => NetLensTranslationKey.mocksModeRecordHint,
    NetLensMockMode.replay => NetLensTranslationKey.mocksModeReplayHint,
  };
}

/// Row of one mock: its endpoint, recorded status and switches.
class _MockTile extends StatelessWidget {
  const _MockTile({
    super.key,
    required this.mock,
    required this.onEnabledChanged,
    required this.onDelete,
  });

  final NetLensMock mock;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color statusColor = NetLensTheme.getStatusColor(
      context,
      mock.response.status,
    );
    final String path = mock.url.path.isEmpty ? '/' : mock.url.path;
    return Opacity(
      opacity: mock.enabled ? 1 : 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            NetLensMethodBadge(method: mock.method),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mock.url.hasQuery ? '$path?${mock.url.query}' : path,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (mock.url.host.isNotEmpty)
                    Text(
                      mock.url.host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${mock.response.status}',
              style: TextStyle(fontWeight: FontWeight.w700, color: statusColor),
            ),
            Tooltip(
              message: context.i18n(NetLensTranslationKey.mocksEnabled),
              child: Switch(
                value: mock.enabled,
                onChanged: onEnabledChanged,
                thumbIcon: WidgetStateProperty.resolveWith(
                  (Set<WidgetState> states) =>
                      states.contains(WidgetState.selected)
                      ? const Icon(Icons.check)
                      : null,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: context.i18n(NetLensTranslationKey.mocksDelete),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
