import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _historyStorageKey = 'historyItems';
const _historyFields = ['Company', 'Animal', 'People', 'Environment'];

Map<String, dynamic> _emptyHistoryItems() {
  final items = <String, dynamic>{};
  for (var slot = 1; slot <= 5; slot++) {
    for (final field in _historyFields) {
      items['$field$slot'] = null;
    }
  }
  return items;
}

final _historyNotifier = ValueNotifier<Map<String, dynamic>>(
  Map<String, dynamic>.unmodifiable(_emptyHistoryItems()),
);

final ValueListenable<Map<String, dynamic>> historyItemsListenable =
    _historyNotifier;

Map<String, dynamic> get historyItems => _historyNotifier.value;

Future<void> _pendingHistoryOperation = Future<void>.value();

Future<void> _queueHistoryOperation(Future<void> Function() operation) {
  final next = _pendingHistoryOperation.then<void>((_) => operation());
  _pendingHistoryOperation = next.then<void>(
    (_) {},
    onError: (Object error, StackTrace stackTrace) {},
  );
  return next;
}

int? _storedScore(dynamic value, String key) {
  if (value == null) return null;
  if (value is! num ||
      !value.isFinite ||
      value < 0 ||
      value > 10 ||
      value != value.round()) {
    throw FormatException(
      'Saved scan history field "$key" must be null or an integer from 0 to 10. '
      'The saved history has not been changed.',
    );
  }
  return value.toInt();
}

Map<String, dynamic> _readHistoryItems(SharedPreferences preferences) {
  final items = _emptyHistoryItems();
  final stored = preferences.get(_historyStorageKey);
  if (stored == null) return items;
  if (stored is! String) {
    throw const FormatException(
      'Saved scan history must contain JSON text. '
      'The saved history has not been changed.',
    );
  }

  final dynamic decoded;
  try {
    decoded = jsonDecode(stored);
  } on FormatException {
    throw const FormatException(
      'Saved scan history contains invalid JSON. '
      'The saved history has not been changed.',
    );
  }
  if (decoded is! Map) {
    throw const FormatException(
      'Saved scan history must be a JSON object with numbered history fields. '
      'The saved history has not been changed.',
    );
  }

  for (var slot = 1; slot <= 5; slot++) {
    final companyKey = 'Company$slot';
    final company = decoded[companyKey];
    if (company != null && company is! String) {
      throw FormatException(
        'Saved scan history field "$companyKey" must be a company name or null. '
        'The saved history has not been changed.',
      );
    }
    items[companyKey] = company;
    for (final field in const ['Animal', 'People', 'Environment']) {
      final key = '$field$slot';
      items[key] = _storedScore(decoded[key], key);
    }
  }
  return items;
}

Future<void> loadScanHistory() => _queueHistoryOperation(() async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      final items = _readHistoryItems(preferences);
      _historyNotifier.value = Map<String, dynamic>.unmodifiable(items);
    });

Future<void> saveScanToHistory({
  required String companyName,
  required int? animalScore,
  required int? peopleScore,
  required int? environmentScore,
}) {
  final newest = <String, dynamic>{
    'Company': companyName.trim(),
    'Animal': animalScore,
    'People': peopleScore,
    'Environment': environmentScore,
  };

  return _queueHistoryOperation(() async {
    if ((newest['Company'] as String).isEmpty) {
      throw ArgumentError('A completed history entry needs a company name.');
    }
    for (final field in const ['Animal', 'People', 'Environment']) {
      final score = newest[field] as int?;
      if (score != null && (score < 0 || score > 10)) {
        throw ArgumentError.value(score, field, 'must be null or from 0 to 10');
      }
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    final previous = _readHistoryItems(preferences);
    final updated = _emptyHistoryItems();

    for (var slot = 2; slot <= 5; slot++) {
      for (final field in _historyFields) {
        updated['$field$slot'] = previous['$field${slot - 1}'];
      }
    }
    for (final field in _historyFields) {
      updated['${field}1'] = newest[field];
    }

    final saved = await preferences.setString(
      _historyStorageKey,
      jsonEncode(updated),
    );
    if (!saved) {
      throw StateError('Could not save scan history on this device.');
    }

    _historyNotifier.value = Map<String, dynamic>.unmodifiable(updated);
  });
}
