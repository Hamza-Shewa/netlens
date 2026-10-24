import 'package:netlens/core/netlens_core.dart';
import 'package:netlens/mock/application/netlens_mock_merger.dart';
import 'package:netlens/mock/domain/netlens_mock.dart';
import 'package:netlens/mock/domain/netlens_mock_response.dart';
import 'package:netlens/model/netlens_translation.dart';
import 'package:netlens/ui/common/netlens_app_bar.dart';
import 'package:netlens/ui/common/netlens_call_badges.dart';
import 'package:netlens/ui/common/netlens_context_ext.dart';
import 'package:netlens/ui/common/netlens_detail_widgets.dart';
import 'package:netlens/ui/common/netlens_page.dart';
import 'package:netlens/ui/common/netlens_scroll_behavior.dart';
import 'package:netlens/ui/common/netlens_theme.dart';
import 'package:flutter/material.dart';

/// Page where conflicts of merged mock collections are settled. Each conflict
/// lists the versions of the sources and the user keeps one. Pops with the
/// number of saved mocks once they were merged.
class NetLensMockMergePage extends StatefulWidget {
  const NetLensMockMergePage({
    super.key,
    required this.core,
    required this.plan,
  });

  final NetLensCore core;
  final NetLensMockMergePlan plan;

  @override
  State<NetLensMockMergePage> createState() => _NetLensMockMergePageState();
}

class _NetLensMockMergePageState extends State<NetLensMockMergePage> {
  final Map<NetLensMockConflict, int> _choices = {};
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final List<NetLensMockConflict> conflicts = widget.plan.getConflicts(
      _choices,
    );
    return NetLensPage(
      core: widget.core,
      child: Scaffold(
        appBar: NetLensAppBar(
          title: Text(context.i18n(NetLensTranslationKey.mocksMergeTitle)),
        ),
        body: ScrollConfiguration(
          behavior: NetLensScrollBehavior(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text(
                context
                    .i18n(NetLensTranslationKey.mocksMergeDescription)
                    .replaceAll('[count]', '${conflicts.length}'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              for (final NetLensMockConflict conflict in conflicts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ConflictCard(
                    conflict: conflict,
                    selected: _choices[conflict] ?? 0,
                    onSelected: (int index) =>
                        setState(() => _choices[conflict] = index),
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FilledButton.icon(
              key: const Key('netlens_mock_merge_apply'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _saving ? null : _apply,
              icon: const Icon(Icons.merge),
              label: Text(context.i18n(NetLensTranslationKey.mocksMergeApply)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _apply() async {
    setState(() => _saving = true);
    final List<NetLensMock> saved = await widget.core.mocks.replaceAll(
      widget.plan.resolve(_choices),
    );
    if (mounted) {
      Navigator.of(context).pop(saved.length);
    }
  }
}

/// Card of one conflict with a choice per option.
class _ConflictCard extends StatelessWidget {
  const _ConflictCard({
    required this.conflict,
    required this.selected,
    required this.onSelected,
  });

  final NetLensMockConflict conflict;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String path = conflict.url.path.isEmpty ? '/' : conflict.url.path;
    final bool isInput = conflict.type == NetLensMockConflictType.input;
    return NetLensOutlinedCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NetLensMethodBadge(method: conflict.method),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  conflict.url.hasQuery ? '$path?${conflict.url.query}' : path,
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (conflict.url.host.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                conflict.url.host,
                textDirection: TextDirection.ltr,
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isInput ? Icons.rule : Icons.compare_arrows,
                size: 16,
                color: NetLensTheme.getStatusColor(context, 300),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.i18n(
                    isInput
                        ? NetLensTranslationKey.mocksMergeInputConflict
                        : NetLensTranslationKey.mocksMergeResponseConflict,
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          RadioGroup<int>(
            groupValue: selected,
            onChanged: (int? index) => onSelected(index ?? selected),
            // The card paints a background, so tiles need their own Material
            // to show ink.
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  for (int index = 0; index < conflict.options.length; index++)
                    RadioListTile<int>(
                      key: Key('netlens_mock_merge_option_$index'),
                      value: index,
                      contentPadding: EdgeInsets.zero,
                      title: Text(conflict.options[index].sources.join(', ')),
                      subtitle: isInput
                          ? _InputDetails(option: conflict.options[index])
                          : _ResponseDetails(
                              mock: conflict.options[index].mocks.first,
                            ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Types of the conflicting fields and an example body of an input option.
class _InputDetails extends StatelessWidget {
  const _InputDetails({required this.option});

  final NetLensMockConflictOption option;

  @override
  Widget build(BuildContext context) {
    final String? example = option.mocks.first.requestBody;
    final int count = option.mocks.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final MapEntry<String, String> type in option.inputTypes.entries)
          _Code('${_getFieldName(context, type.key)}: ${type.value}'),
        if (example != null) _Code(_shorten(example), muted: true),
        if (count > 1)
          Text(
            context
                .i18n(NetLensTranslationKey.mocksMergeRequests)
                .replaceAll('[count]', '$count'),
          ),
      ],
    );
  }

  /// Returns [path] without the `$.` of the body, for example `user.id`.
  static String _getFieldName(BuildContext context, String path) {
    if (path == r'$') {
      return context.i18n(NetLensTranslationKey.mocksMergeBody);
    }
    return path.startsWith(r'$.') ? path.substring(2) : path.substring(1);
  }
}

/// Status and body of a response option.
class _ResponseDetails extends StatelessWidget {
  const _ResponseDetails({required this.mock});

  final NetLensMock mock;

  @override
  Widget build(BuildContext context) {
    final NetLensMockResponse response = mock.response;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${response.status}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: NetLensTheme.getStatusColor(context, response.status),
          ),
        ),
        if (response.bodyEncoding == NetLensMockBodyEncoding.text &&
            response.body.isNotEmpty)
          _Code(_shorten(response.body), muted: true),
      ],
    );
  }
}

/// Monospace text of a technical value.
class _Code extends StatelessWidget {
  const _Code(this.text, {this.muted = false});

  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        text,
        maxLines: muted ? 3 : null,
        overflow: muted ? TextOverflow.ellipsis : null,
        textDirection: TextDirection.ltr,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          fontFamilyFallback: const ['Courier', 'Menlo'],
          color: muted ? theme.colorScheme.onSurfaceVariant : null,
        ),
      ),
    );
  }
}

String _shorten(String text) =>
    text.length > 300 ? '${text.substring(0, 300)}…' : text;
