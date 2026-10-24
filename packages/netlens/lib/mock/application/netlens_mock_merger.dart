import 'dart:convert' show jsonDecode;

import 'package:netlens/mock/domain/netlens_mock.dart';

/// Mocks read from one place, for example a collection shared by a teammate.
class NetLensMockSource {
  const NetLensMockSource({required this.name, required this.mocks});

  /// Name shown to the user, for example the file name.
  final String name;

  final List<NetLensMock> mocks;
}

/// Why mocks of several sources can't all be kept.
enum NetLensMockConflictType {
  /// Sources send a field of the same endpoint as different types, for
  /// example as a number in one and as text in another.
  input,

  /// Sources answer the same request with different responses.
  response,
}

/// One way to settle a conflict: the mocks of the sources which agree.
class NetLensMockConflictOption {
  NetLensMockConflictOption._(this._candidates, this.inputTypes);

  final List<_Candidate> _candidates;

  /// Types of the conflicting fields in this option, by field path, for
  /// example `{'user.id': 'number'}`. Empty for response conflicts.
  final Map<String, String> inputTypes;

  /// Names of the sources which have this option, in source order.
  List<String> get sources => {
    for (final _Candidate candidate in _candidates) ...candidate.sources,
  }.toList();

  /// Mocks kept when this option is chosen.
  List<NetLensMock> get mocks => [
    for (final _Candidate candidate in _candidates) candidate.mock,
  ];
}

/// Mocks of several sources which can't all be kept. The user chooses one of
/// [options].
class NetLensMockConflict {
  NetLensMockConflict._({
    required this.type,
    required this.method,
    required this.url,
    required this.options,
  });

  final NetLensMockConflictType type;

  /// Method of the endpoint.
  final String method;

  /// URL of the endpoint. For input conflicts it has no query, because the
  /// conflict is about every request of the endpoint.
  final Uri url;

  /// Options in source order. The first one is chosen by default.
  final List<NetLensMockConflictOption> options;
}

/// Result of [NetLensMockMerger.plan]: the merged mocks and the conflicts
/// which the user settles before the mocks are saved.
class NetLensMockMergePlan {
  NetLensMockMergePlan._(
    this._candidates,
    this.inputConflicts,
    this.responseConflicts,
  );

  final List<_Candidate> _candidates;

  /// Endpoints whose sources send fields as different types.
  final List<NetLensMockConflict> inputConflicts;

  /// Requests which sources answer differently.
  final List<NetLensMockConflict> responseConflicts;

  /// Returns true when nothing has to be chosen.
  bool get hasConflicts =>
      inputConflicts.isNotEmpty || responseConflicts.isNotEmpty;

  /// Number of different mocks in all sources, before conflicts are settled.
  int get mockCount => _candidates.length;

  /// Returns the conflicts left to settle with [choices]. A response conflict
  /// disappears when its mocks were dropped by an input choice.
  List<NetLensMockConflict> getConflicts([
    Map<NetLensMockConflict, int> choices = const {},
  ]) {
    final Set<_Candidate> dropped = _getDroppedByInput(choices);
    return [
      ...inputConflicts,
      for (final NetLensMockConflict conflict in responseConflicts)
        if (!_isDropped(conflict, dropped)) conflict,
    ];
  }

  /// Returns the merged mocks. [choices] maps a conflict to the index of the
  /// chosen option; the first option is used for a conflict without a choice.
  List<NetLensMock> resolve([
    Map<NetLensMockConflict, int> choices = const {},
  ]) {
    final Set<_Candidate> dropped = _getDroppedByInput(choices);
    for (final NetLensMockConflict conflict in responseConflicts) {
      if (_isDropped(conflict, dropped)) {
        continue;
      }
      _dropOthers(conflict, choices, dropped);
    }
    return [
      for (final _Candidate candidate in _candidates)
        if (!dropped.contains(candidate)) candidate.mock,
    ];
  }

  Set<_Candidate> _getDroppedByInput(Map<NetLensMockConflict, int> choices) {
    final Set<_Candidate> dropped = {};
    for (final NetLensMockConflict conflict in inputConflicts) {
      _dropOthers(conflict, choices, dropped);
    }
    return dropped;
  }

  void _dropOthers(
    NetLensMockConflict conflict,
    Map<NetLensMockConflict, int> choices,
    Set<_Candidate> dropped,
  ) {
    final int chosen = (choices[conflict] ?? 0).clamp(
      0,
      conflict.options.length - 1,
    );
    for (int index = 0; index < conflict.options.length; index++) {
      if (index != chosen) {
        dropped.addAll(conflict.options[index]._candidates);
      }
    }
  }

  static bool _isDropped(
    NetLensMockConflict conflict,
    Set<_Candidate> dropped,
  ) => conflict.options.every(
    (NetLensMockConflictOption option) =>
        option._candidates.every(dropped.contains),
  );
}

/// Merges mocks of several sources, for example collections recorded by
/// teammates who each tested another feature.
///
/// Equal mocks are kept once. Two kinds of differences can't be merged and
/// become conflicts:
///
/// * [NetLensMockConflictType.input]: requests of one endpoint (method and
///   URL without query) send a JSON field as different types. Fields which
///   are missing or null in a request never conflict, and neither do values
///   of the same type, so requests with other values are all kept.
/// * [NetLensMockConflictType.response]: the same request has different
///   responses. Only the status and the body are compared, because headers
///   like `date` differ on every call.
class NetLensMockMerger {
  const NetLensMockMerger();

  /// Returns the merge of [sources]. Sources earlier in the list win when the
  /// user keeps the default choices.
  NetLensMockMergePlan plan(List<NetLensMockSource> sources) {
    final List<_Candidate> candidates = [];
    final Map<String, _Candidate> byIdentity = {};
    for (final NetLensMockSource source in sources) {
      for (final NetLensMock mock in source.mocks) {
        final String identity = _getIdentity(mock);
        final _Candidate? existing = byIdentity[identity];
        if (existing != null) {
          existing.sources.add(source.name);
          continue;
        }
        final _Candidate candidate = _Candidate(mock, {source.name});
        byIdentity[identity] = candidate;
        candidates.add(candidate);
      }
    }
    return NetLensMockMergePlan._(
      candidates,
      _findInputConflicts(candidates),
      _findResponseConflicts(candidates),
    );
  }

  /// Returns types of every field of the JSON body of [mock], by field path.
  /// The body itself has the path `$`, items of a list add `[]`. Null values
  /// are left out. A body which isn't JSON has the type `text`.
  static Map<String, Set<String>> getInputTypes(NetLensMock mock) {
    final String? body = mock.requestBody;
    final Map<String, Set<String>> types = {};
    if (body == null || body.trim().isEmpty) {
      return types;
    }
    final Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException {
      return {
        r'$': {'text'},
      };
    }
    _collectTypes(json, r'$', types);
    return types;
  }

  static void _collectTypes(
    Object? value,
    String path,
    Map<String, Set<String>> types,
  ) {
    final String? type = switch (value) {
      null => null,
      Map() => 'object',
      List() => 'array',
      String() => 'string',
      num() => 'number',
      bool() => 'boolean',
      _ => 'text',
    };
    if (type == null) {
      return;
    }
    types.putIfAbsent(path, () => {}).add(type);
    if (value is Map) {
      for (final MapEntry<dynamic, dynamic> entry in value.entries) {
        _collectTypes(entry.value, '$path.${entry.key}', types);
      }
    } else if (value is List) {
      for (final Object? item in value) {
        _collectTypes(item, '$path[]', types);
      }
    }
  }

  static String _getIdentity(NetLensMock mock) =>
      '${mock.requestKey}\n${mock.response.status}\n'
      '${mock.response.bodyEncoding.name}\n${mock.response.body}';

  static String _getEndpoint(NetLensMock mock) =>
      '${mock.method} ${_withoutQuery(mock.url)}';

  static Uri _withoutQuery(Uri url) =>
      Uri.parse(url.removeFragment().toString().split('?').first);

  List<NetLensMockConflict> _findInputConflicts(List<_Candidate> candidates) {
    final Map<String, List<_Candidate>> byEndpoint = {};
    for (final _Candidate candidate in candidates) {
      byEndpoint
          .putIfAbsent(_getEndpoint(candidate.mock), () => [])
          .add(candidate);
    }
    final List<NetLensMockConflict> conflicts = [];
    for (final List<_Candidate> endpoint in byEndpoint.values) {
      final Map<_Candidate, Map<String, Set<String>>> types = {
        for (final _Candidate candidate in endpoint)
          candidate: getInputTypes(candidate.mock),
      };
      final List<String> paths = _getConflictingPaths(types.values);
      if (paths.isEmpty) {
        continue;
      }
      // Candidates which have none of the paths fit every option.
      final Map<String, List<_Candidate>> byTypes = {};
      final Map<String, Map<String, String>> optionTypes = {};
      for (final MapEntry<_Candidate, Map<String, Set<String>>> entry
          in types.entries) {
        final Map<String, String> conflicting = {
          for (final String path in paths)
            if (entry.value[path] != null)
              path: (entry.value[path]!.toList()..sort()).join(' | '),
        };
        if (conflicting.isEmpty) {
          continue;
        }
        final String key = conflicting.entries
            .map((MapEntry<String, String> type) => '${type.key}=${type.value}')
            .join('\n');
        byTypes.putIfAbsent(key, () => []).add(entry.key);
        optionTypes[key] = conflicting;
      }
      if (byTypes.length < 2) {
        continue;
      }
      final NetLensMock first = endpoint.first.mock;
      conflicts.add(
        NetLensMockConflict._(
          type: NetLensMockConflictType.input,
          method: first.method,
          url: _withoutQuery(first.url),
          options: [
            for (final MapEntry<String, List<_Candidate>> option
                in byTypes.entries)
              NetLensMockConflictOption._(
                option.value,
                optionTypes[option.key]!,
              ),
          ],
        ),
      );
    }
    return conflicts;
  }

  /// Returns sorted paths which have different types in [types].
  static List<String> _getConflictingPaths(
    Iterable<Map<String, Set<String>>> types,
  ) {
    final Map<String, String> seen = {};
    final Set<String> conflicting = {};
    for (final Map<String, Set<String>> candidateTypes in types) {
      for (final MapEntry<String, Set<String>> entry
          in candidateTypes.entries) {
        final String type = (entry.value.toList()..sort()).join(' | ');
        final String previous = seen.putIfAbsent(entry.key, () => type);
        if (previous != type) {
          conflicting.add(entry.key);
        }
      }
    }
    // A field of an object which itself conflicts adds nothing to show.
    return conflicting
        .where(
          (String path) => !conflicting.any(
            (String parent) =>
                parent != path &&
                (path.startsWith('$parent.') || path.startsWith('$parent[]')),
          ),
        )
        .toList()
      ..sort();
  }

  List<NetLensMockConflict> _findResponseConflicts(
    List<_Candidate> candidates,
  ) {
    final Map<String, List<_Candidate>> byRequest = {};
    for (final _Candidate candidate in candidates) {
      byRequest.putIfAbsent(candidate.mock.requestKey, () => []).add(candidate);
    }
    return [
      for (final List<_Candidate> request in byRequest.values)
        if (request.length > 1)
          NetLensMockConflict._(
            type: NetLensMockConflictType.response,
            method: request.first.mock.method,
            url: request.first.mock.url,
            options: [
              for (final _Candidate candidate in request)
                NetLensMockConflictOption._([candidate], const {}),
            ],
          ),
    ];
  }
}

/// Mock with the names of the sources which have it.
class _Candidate {
  _Candidate(this.mock, this.sources);

  final NetLensMock mock;
  final Set<String> sources;
}
